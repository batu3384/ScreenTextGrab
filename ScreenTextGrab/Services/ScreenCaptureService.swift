import Foundation
import CoreGraphics
import ScreenCaptureKit
import ImageIO
import UniformTypeIdentifiers

protocol ScreenCaptureProviding: Sendable {
    func captureCandidates(request: CaptureRequest) async throws -> [CaptureCandidate]
}

extension ScreenCaptureProviding {
    func captureImage(request: CaptureRequest) async throws -> CGImage {
        let candidates = try await captureCandidates(request: request)
        guard let image = candidates.first?.image else {
            throw CapturePipelineError.captureFailed(
                domain: "ScreenCaptureService",
                code: -1,
                description: "No capture candidate was produced"
            )
        }
        return image
    }
}

final class ScreenCaptureService: ScreenCaptureProviding, @unchecked Sendable {
    func captureCandidates(request: CaptureRequest) async throws -> [CaptureCandidate] {
        let selectionRect = request.selectionRect.standardized

        guard selectionRect.width > 1, selectionRect.height > 1 else {
            throw CapturePipelineError.invalidSourceRect
        }

        let quartzSelectionRect = Self.appKitToQuartzRect(
            selectionRect,
            desktopBounds: request.environment.desktopBounds
        )
        var acceptedCandidates: [CaptureCandidate] = []
        var rejectedCandidates: [CaptureCandidate] = []

        if let systemCandidate = await Self.captureViaSystemScreencapture(quartzRect: quartzSelectionRect) {
            Self.classifyCandidate(systemCandidate, accepted: &acceptedCandidates, rejected: &rejectedCandidates)
        }

        if #available(macOS 15.2, *),
           let globalCandidate = await Self.captureViaGlobalScreenshotKit(quartzRect: quartzSelectionRect) {
            Self.classifyCandidate(globalCandidate, accepted: &acceptedCandidates, rejected: &rejectedCandidates)
        }

        let targetDisplay = request.environment.bestDisplay(
            for: selectionRect,
            preferredDisplayID: request.preferredDisplay?.displayID
        )
        guard let targetDisplay else {
            if !acceptedCandidates.isEmpty {
                return Self.finalizeCandidates(acceptedCandidates, selectionRect: selectionRect)
            }
            if !rejectedCandidates.isEmpty {
                return Self.finalizeCandidates(rejectedCandidates, selectionRect: selectionRect)
            }
            throw CapturePipelineError.displayNotFound
        }

        let displayBounds = CGDisplayBounds(targetDisplay.displayID)
        let boundedQuartzRect = quartzSelectionRect.intersection(displayBounds).standardized
        guard boundedQuartzRect.width > 1, boundedQuartzRect.height > 1 else {
            if !acceptedCandidates.isEmpty {
                return Self.finalizeCandidates(acceptedCandidates, selectionRect: selectionRect)
            }
            if !rejectedCandidates.isEmpty {
                return Self.finalizeCandidates(rejectedCandidates, selectionRect: selectionRect)
            }
            throw CapturePipelineError.invalidSourceRect
        }

        if let sckCandidate = await Self.captureViaDisplayFilter(
            quartzSelectionRect: boundedQuartzRect,
            display: targetDisplay
        ) {
            Self.classifyCandidate(sckCandidate, accepted: &acceptedCandidates, rejected: &rejectedCandidates)
        }

        if let fullImage = CGDisplayCreateImage(targetDisplay.displayID) {
            let scaleX = CGFloat(fullImage.width) / displayBounds.width
            let scaleY = CGFloat(fullImage.height) / displayBounds.height
            let localX = boundedQuartzRect.minX - displayBounds.minX
            let localY = boundedQuartzRect.minY - displayBounds.minY
            let pixelRect = CGRect(
                x: localX * scaleX,
                y: localY * scaleY,
                width: boundedQuartzRect.width * scaleX,
                height: boundedQuartzRect.height * scaleY
            ).integral

            if let candidate = Self.crop(
                fullImage: fullImage,
                pixelRect: pixelRect,
                strategy: .displayCropTopLeft,
                debugPrefix: "display=\(targetDisplay.displayID)"
            ) {
                Self.classifyCandidate(candidate, accepted: &acceptedCandidates, rejected: &rejectedCandidates)
            }
        }

        if !acceptedCandidates.isEmpty {
            return Self.finalizeCandidates(acceptedCandidates, selectionRect: selectionRect)
        }

        if !rejectedCandidates.isEmpty {
            STGLog.capture.warning("All capture candidates looked suspicious; returning rejected candidates for OCR fallback")
            return Self.finalizeCandidates(rejectedCandidates, selectionRect: selectionRect)
        }

        if !CGPreflightScreenCaptureAccess() {
            throw CapturePipelineError.permissionDenied(detail: "Screen capture access is not granted")
        }

        throw CapturePipelineError.captureFailed(
            domain: "ScreenCaptureService",
            code: -2,
            description: "All capture strategies failed"
        )
    }

    private static func classifyCandidate(
        _ candidate: CaptureCandidate,
        accepted: inout [CaptureCandidate],
        rejected: inout [CaptureCandidate]
    ) {
        let metrics = imageMetrics(for: candidate.image)
        var annotated = candidate
        annotated.debugInfo += String(
            format: " lumaStd=%.2f dominant=%.3f minL=%.1f maxL=%.1f",
            metrics.luminanceStdDev,
            metrics.dominantRatio,
            metrics.minLuminance,
            metrics.maxLuminance
        )

        if metrics.isLikelyBlank {
            STGLog.capture.warning(
                "Rejecting suspicious capture strategy=\(candidate.strategy.rawValue, privacy: .public) std=\(metrics.luminanceStdDev) dominant=\(metrics.dominantRatio)"
            )
            rejected.append(annotated)
        } else {
            accepted.append(annotated)
        }
    }

    private static func finalizeCandidates(
        _ candidates: [CaptureCandidate],
        selectionRect: CGRect
    ) -> [CaptureCandidate] {
        let finalCandidates: [CaptureCandidate]
        if Self.shouldPersistDiagnostics {
            finalCandidates = Self.persistDebugArtifacts(candidates: candidates, selectionRect: selectionRect)
        } else {
            finalCandidates = candidates
        }

        let strategyList = finalCandidates.map(\.strategy.rawValue).joined(separator: ",")
        STGLog.capture.info(
            "Capture candidates=\(finalCandidates.count) strategies=\(strategyList, privacy: .public) rect=(\(selectionRect.origin.x),\(selectionRect.origin.y),\(selectionRect.width),\(selectionRect.height))"
        )
        return finalCandidates
    }

    @available(macOS 15.2, *)
    private static func captureViaGlobalScreenshotKit(quartzRect: CGRect) async -> CaptureCandidate? {
        do {
            let cgImage: CGImage = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CGImage, Error>) in
                SCScreenshotManager.captureImage(in: quartzRect) { image, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let image else {
                        continuation.resume(throwing: CapturePipelineError.captureFailed(
                            domain: "SCScreenshotManager.captureImage(in:)",
                            code: -1,
                            description: "No image was returned"
                        ))
                        return
                    }

                    continuation.resume(returning: image)
                }
            }

            let debug = "globalQuartzRect=(\(Int(quartzRect.origin.x)),\(Int(quartzRect.origin.y)),\(Int(quartzRect.width)),\(Int(quartzRect.height)))"
            return CaptureCandidate(strategy: .screenshotKitGlobalRect, image: cgImage, debugInfo: debug)
        } catch {
            STGLog.capture.warning("SCK global capture failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func captureViaSystemScreencapture(quartzRect: CGRect) async -> CaptureCandidate? {
        let roundedRect = quartzRect.integral
        guard roundedRect.width > 1, roundedRect.height > 1 else {
            return nil
        }

        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ScreenTextGrab-screencapture-\(UUID().uuidString).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = [
            "-x",
            "-R\(Int(roundedRect.minX)),\(Int(roundedRect.minY)),\(Int(roundedRect.width)),\(Int(roundedRect.height))",
            outputURL.path
        ]

        do {
            let status: Int32 = try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { terminatedProcess in
                    continuation.resume(returning: terminatedProcess.terminationStatus)
                }
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            guard status == 0,
                  let imageSource = CGImageSourceCreateWithURL(outputURL as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                STGLog.capture.warning("screencapture exited with status \(process.terminationStatus)")
                try? FileManager.default.removeItem(at: outputURL)
                return nil
            }

            let debug = "systemRect=(\(Int(roundedRect.origin.x)),\(Int(roundedRect.origin.y)),\(Int(roundedRect.width)),\(Int(roundedRect.height)))"
            try? FileManager.default.removeItem(at: outputURL)
            return CaptureCandidate(strategy: .systemScreencaptureCLI, image: cgImage, debugInfo: debug)
        } catch {
            STGLog.capture.warning("screencapture failed: \(error.localizedDescription, privacy: .public)")
            try? FileManager.default.removeItem(at: outputURL)
            return nil
        }
    }

    private static func captureViaDisplayFilter(
        quartzSelectionRect: CGRect,
        display: ScreenDescriptor
    ) async -> CaptureCandidate? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let scDisplay = content.displays.first(where: { $0.displayID == display.displayID }) else {
                STGLog.capture.warning("SCK: display \(display.displayID) not found in shareable content")
                return nil
            }

            let filter = SCContentFilter(display: scDisplay, excludingApplications: [], exceptingWindows: [])
            if #available(macOS 14.2, *) {
                filter.includeMenuBar = true
            }

            let displayBounds = scDisplay.frame
            let sourceRect = CGRect(
                x: quartzSelectionRect.minX - displayBounds.minX,
                y: quartzSelectionRect.minY - displayBounds.minY,
                width: quartzSelectionRect.width,
                height: quartzSelectionRect.height
            ).standardized

            let scale = max(CGFloat(filter.pointPixelScale), display.backingScaleFactor, 1)
            let config = SCStreamConfiguration()
            config.sourceRect = sourceRect
            config.width = max(1, Int(round(sourceRect.width * scale)))
            config.height = max(1, Int(round(sourceRect.height * scale)))
            if #available(macOS 15.0, *) {
                config.captureDynamicRange = .SDR
            }
            config.capturesAudio = false
            config.showsCursor = false
            config.scalesToFit = false
            config.preservesAspectRatio = true

            let cgImage: CGImage = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CGImage, Error>) in
                SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let image else {
                        continuation.resume(throwing: CapturePipelineError.captureFailed(
                            domain: "SCScreenshotManager.captureImage(contentFilter:configuration:)",
                            code: -1,
                            description: "No image was returned"
                        ))
                        return
                    }

                    continuation.resume(returning: image)
                }
            }

            let debug = "display=\(display.displayID) displayBounds=(\(Int(displayBounds.origin.x)),\(Int(displayBounds.origin.y)),\(Int(displayBounds.width)),\(Int(displayBounds.height))) sourceRect=(\(Int(sourceRect.origin.x)),\(Int(sourceRect.origin.y)),\(Int(sourceRect.width)),\(Int(sourceRect.height))) scale=\(scale)"
            return CaptureCandidate(strategy: .screenshotKitDisplayFilter, image: cgImage, debugInfo: debug)
        } catch {
            STGLog.capture.warning("SCK capture failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private struct ImageMetrics {
        let dominantRatio: Double
        let luminanceStdDev: Double
        let minLuminance: Double
        let maxLuminance: Double

        var isLikelyBlank: Bool {
            (dominantRatio > 0.965 && luminanceStdDev < 8.0) ||
            (maxLuminance - minLuminance < 18.0 && luminanceStdDev < 4.0)
        }
    }

    private static func imageMetrics(for image: CGImage) -> ImageMetrics {
        let maxSampleDimension: CGFloat = 160
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else {
            return ImageMetrics(dominantRatio: 0, luminanceStdDev: 999, minLuminance: 0, maxLuminance: 255)
        }

        let scale = min(1, maxSampleDimension / max(CGFloat(width), CGFloat(height), 1))
        let sampleWidth = max(1, Int((CGFloat(width) * scale).rounded()))
        let sampleHeight = max(1, Int((CGFloat(height) * scale).rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = sampleWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: sampleHeight * bytesPerRow)

        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )

        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return ImageMetrics(dominantRatio: 0, luminanceStdDev: 999, minLuminance: 0, maxLuminance: 255)
        }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        var histogram = [Int](repeating: 0, count: 256)
        var sum = 0.0
        var sumSquares = 0.0
        var count = 0.0
        var minLuminance = 255.0
        var maxLuminance = 0.0

        for row in 0..<sampleHeight {
            let rowBase = row * bytesPerRow
            for column in 0..<sampleWidth {
                let pixelIndex = rowBase + (column * bytesPerPixel)
                let r = Double(pixels[pixelIndex])
                let g = Double(pixels[pixelIndex + 1])
                let b = Double(pixels[pixelIndex + 2])
                let luminance = (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
                minLuminance = min(minLuminance, luminance)
                maxLuminance = max(maxLuminance, luminance)
                sum += luminance
                sumSquares += luminance * luminance
                histogram[Int(max(0, min(255, Int(luminance.rounded()))))] += 1
                count += 1
            }
        }

        guard count > 0 else {
            return ImageMetrics(dominantRatio: 0, luminanceStdDev: 999, minLuminance: 0, maxLuminance: 255)
        }

        let mean = sum / count
        let variance = max((sumSquares / count) - (mean * mean), 0)
        let stdDev = sqrt(variance)
        let dominantRatio = Double(histogram.max() ?? 0) / count
        return ImageMetrics(
            dominantRatio: dominantRatio,
            luminanceStdDev: stdDev,
            minLuminance: minLuminance,
            maxLuminance: maxLuminance
        )
    }

    private static func crop(
        fullImage: CGImage,
        pixelRect: CGRect,
        strategy: CaptureStrategy,
        debugPrefix: String
    ) -> CaptureCandidate? {
        let imageBounds = CGRect(x: 0, y: 0, width: fullImage.width, height: fullImage.height)
        let clamped = pixelRect.intersection(imageBounds).standardized
        guard clamped.width > 1, clamped.height > 1,
              let cropped = fullImage.cropping(to: clamped) else {
            return nil
        }

        let debug = "\(debugPrefix) pixelCrop=(\(Int(clamped.origin.x)),\(Int(clamped.origin.y)),\(Int(clamped.width)),\(Int(clamped.height)))"
        return CaptureCandidate(strategy: strategy, image: cropped, debugInfo: debug)
    }

    private static func appKitToQuartzRect(_ rect: CGRect, desktopBounds: CGRect) -> CGRect {
        guard !desktopBounds.isNull else {
            return rect
        }

        let quartzY = desktopBounds.maxY - rect.maxY
        return CGRect(x: rect.minX, y: quartzY, width: rect.width, height: rect.height).standardized
    }

    private static var shouldPersistDiagnostics: Bool {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] == nil
        #else
        return false
        #endif
    }

    private static func persistDebugArtifacts(
        candidates: [CaptureCandidate],
        selectionRect: CGRect
    ) -> [CaptureCandidate] {
        var annotatedCandidates = candidates
        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ScreenTextGrab-Diagnostics", isDirectory: true)

        do {
            try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        } catch {
            STGLog.capture.error("Failed creating diagnostics root: \(error.localizedDescription, privacy: .public)")
            return annotatedCandidates
        }

        let batchURL = rootURL.appendingPathComponent("capture-\(artifactTimestamp())", isDirectory: true)
        do {
            try fm.createDirectory(at: batchURL, withIntermediateDirectories: true)
        } catch {
            STGLog.capture.error("Failed creating diagnostics batch: \(error.localizedDescription, privacy: .public)")
            return annotatedCandidates
        }

        var metadata: [String] = [
            "selectionRect=(\(selectionRect.origin.x),\(selectionRect.origin.y),\(selectionRect.width),\(selectionRect.height))",
            "candidateCount=\(annotatedCandidates.count)"
        ]

        for index in annotatedCandidates.indices {
            let strategy = annotatedCandidates[index].strategy.rawValue
            let fileURL = batchURL.appendingPathComponent("\(index + 1)-\(strategy).png")
            let wrote = writePNG(annotatedCandidates[index].image, to: fileURL)
            if wrote {
                annotatedCandidates[index].debugInfo += " file=\(fileURL.path)"
            }
            metadata.append("[\(index + 1)] strategy=\(strategy) wrote=\(wrote) info=\(annotatedCandidates[index].debugInfo)")
        }

        let metadataURL = batchURL.appendingPathComponent("metadata.txt")
        try? metadata.joined(separator: "\n").write(to: metadataURL, atomically: true, encoding: .utf8)

        STGLog.capture.info("Capture artifacts saved: \(batchURL.path, privacy: .public)")
        cleanupOldArtifacts(rootURL: rootURL, keep: 20)

        return annotatedCandidates
    }

    private static func writePNG(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return false
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            STGLog.capture.error("Failed writing debug PNG: could not finalize destination")
            return false
        }

        return true
    }

    private static func cleanupOldArtifacts(rootURL: URL, keep: Int) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let captureDirs = entries.filter { $0.lastPathComponent.hasPrefix("capture-") }
        let sorted = captureDirs.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }

        guard sorted.count > keep else { return }

        for url in sorted.dropFirst(keep) {
            try? fm.removeItem(at: url)
        }
    }

    private static func artifactTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter.string(from: Date())
    }
}
