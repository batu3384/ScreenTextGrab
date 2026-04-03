import AppKit
import Foundation

struct CaptureOCRSelection: Sendable {
    enum ContentKind: Sendable {
        case text
        case barcode(BarcodePayload)
    }

    let candidate: CaptureCandidate
    let ocrResult: OCRResult
    let text: String
    let score: Float
    let attemptLabel: String
    let kind: ContentKind
}

struct CaptureOCRAttemptEvaluation: Sendable {
    let best: CaptureOCRSelection?
    let hadSuccessfulOCRPass: Bool
    let lastOCRError: CapturePipelineError?
    let summary: String
}

struct CaptureRetryAttempt: Sendable {
    let label: String
    let captureRect: CGRect
    let delayNanoseconds: UInt64
}

struct CaptureWatchSession: Sendable {
    let selectionRect: CGRect
    let preferredDisplayID: CGDirectDisplayID?
    let captureMode: CaptureMode
    let outputPreset: CaptureOutputPreset
    let ocrLanguageSelection: OCRLanguageSelection
    let source: ClipboardHistoryEntry.SourceContext?
    var lastRecognizedSignature: String?
    var lastRawText: String?
}

enum CaptureRecognitionHeuristics {
    static func scoreOCRResult(
        _ result: OCRResult,
        text: String,
        captureMode: CaptureMode
    ) -> Float {
        let confidenceScore = result.averageConfidence * 300
        let charScore = min(Float(text.count), 100) * 0.5
        let blockScore = Float(result.blocks.count) * 6
        var score = confidenceScore + charScore + blockScore

        if captureMode.isSubtitleFocused {
            if text.count >= 5 {
                score += 14
            }
            if result.blocks.count <= 3 {
                score += 8
            }
        }

        if captureMode.isTableFocused {
            let rows = text.split(separator: "\n", omittingEmptySubsequences: false)
            let tabbedRows = rows.filter { $0.contains("\t") }
            if tabbedRows.count >= 2 {
                score += 18
            }
            if let maxTabs = tabbedRows.map({ $0.filter { $0 == "\t" }.count }).max() {
                score += Float(maxTabs) * 8
            }
        }

        return score
    }

    static func shouldAttemptBarcodeDetection(
        for captureMode: CaptureMode,
        recognizedText: String,
        blockCount: Int
    ) -> Bool {
        guard !captureMode.isCodeFocused && !captureMode.isTableFocused else {
            return false
        }

        if recognizedText.isEmpty {
            return true
        }

        return blockCount <= 1 && recognizedText.count <= 24
    }

    static func selectionForBarcode(
        _ barcode: BarcodePayload,
        candidate: CaptureCandidate,
        sourceRect: CGRect,
        attemptLabel: String
    ) -> CaptureOCRSelection {
        let payload = barcode.payload.trimmingCharacters(in: .whitespacesAndNewlines)
        let barcodeResult = OCRResult(
            blocks: [OCRTextBlock(text: payload, confidence: 0.99, boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1))],
            captureDate: Date(),
            sourceRect: sourceRect
        )
        let score = barcodeScore(barcode, payload: payload)

        return CaptureOCRSelection(
            candidate: candidate,
            ocrResult: barcodeResult,
            text: payload,
            score: score,
            attemptLabel: attemptLabel,
            kind: .barcode(barcode)
        )
    }

    static func barcodeScore(_ barcode: BarcodePayload, payload: String) -> Float {
        var score: Float = 320 + min(Float(payload.count), 120) * 1.1
        if barcode.symbology.lowercased().contains("qr") {
            score += 24
        }
        if SmartActionBuilder.actions(for: payload).isEmpty == false {
            score += 16
        }
        return score
    }

    static func successStatusMessage(for selection: CaptureOCRSelection) -> String {
        switch selection.kind {
        case .text:
            return "✅ Kopyalandı (\(selection.text.count) karakter)"
        case .barcode(let barcode):
            return "✅ \(barcode.displayName) kopyalandı"
        }
    }

    static func preferredCaptureRect(
        for selectionRect: CGRect,
        captureMode: CaptureMode,
        preferredDisplay: ScreenDescriptor?,
        environment: ScreenEnvironmentSnapshot
    ) -> CGRect {
        guard shouldExpandCaptureRect(for: selectionRect, captureMode: captureMode) else {
            return selectionRect.standardized
        }

        let horizontalPadding: CGFloat
        let topPadding: CGFloat
        let bottomPadding: CGFloat

        if captureMode.isSubtitleFocused {
            horizontalPadding = min(max(selectionRect.width * 0.05, 18), 72)
            topPadding = min(max(selectionRect.height * 1.35, 36), 180)
            bottomPadding = min(max(selectionRect.height * 0.55, 18), 76)
        } else if captureMode.isTableFocused {
            horizontalPadding = min(max(selectionRect.width * 0.012, 6), 20)
            topPadding = min(max(selectionRect.height * 0.08, 4), 18)
            bottomPadding = min(max(selectionRect.height * 0.08, 4), 18)
        } else {
            horizontalPadding = min(max(selectionRect.width * 0.035, 18), 56)
            topPadding = min(max(selectionRect.height * 1.0, 26), 110)
            bottomPadding = min(max(selectionRect.height * 0.45, 14), 52)
        }

        var expanded = CGRect(
            x: selectionRect.minX - horizontalPadding,
            y: selectionRect.minY - bottomPadding,
            width: selectionRect.width + (horizontalPadding * 2),
            height: selectionRect.height + topPadding + bottomPadding
        ).standardized

        let bounds = captureBounds(for: preferredDisplay, environment: environment)
        if !bounds.isNull {
            expanded = expanded.intersection(bounds).standardized
        }

        guard expanded.width > 1, expanded.height > 1 else {
            return selectionRect.standardized
        }

        return expanded
    }

    static func preferredOCRRegions(
        sourceRect: CGRect,
        within captureRect: CGRect,
        captureMode: CaptureMode
    ) -> [CGRect] {
        let intersection = sourceRect.standardized.intersection(captureRect.standardized).standardized
        guard intersection.width > 1,
              intersection.height > 1,
              captureRect.width > 1,
              captureRect.height > 1 else {
            return []
        }

        let exact = CGRect(
            x: (intersection.minX - captureRect.minX) / captureRect.width,
            y: (intersection.minY - captureRect.minY) / captureRect.height,
            width: intersection.width / captureRect.width,
            height: intersection.height / captureRect.height
        )

        let padded = exact.insetBy(
            dx: -min(0.04, exact.width * 0.14),
            dy: -min(0.08, exact.height * 0.30)
        )

        var regions = [exact, padded]

        if captureMode.isSubtitleFocused {
            let bottomBand = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 0.40)
            let bottomTight = CGRect(x: 0.05, y: 0.0, width: 0.90, height: 0.26)
            regions.insert(bottomTight, at: 0)
            regions.insert(bottomBand, at: 0)
        }

        return regions
            .map { $0.intersection(CGRect(x: 0, y: 0, width: 1, height: 1)).standardized }
            .filter { $0.width > 0.02 && $0.height > 0.02 }
    }

    static func shouldExpandCaptureRect(for rect: CGRect, captureMode: CaptureMode) -> Bool {
        if captureMode.isTableFocused {
            return rect.width >= 300 && rect.height >= 120
        }

        let aspectRatio = rect.width / max(rect.height, 1)
        if captureMode.isSubtitleFocused {
            return rect.width >= 220 && (aspectRatio >= 1.6 || rect.height <= 220)
        }
        return aspectRatio >= 4.0 && rect.height <= 180
    }

    static func shouldRetryTextRecognition(
        for rect: CGRect,
        currentBest: CaptureOCRSelection?,
        captureMode: CaptureMode
    ) -> Bool {
        if let currentBest {
            let minimumScore: Float = captureMode.isSubtitleFocused ? 205 : (captureMode.isTableFocused ? 210 : 170)
            let minimumLength = captureMode.isSubtitleFocused ? 6 : (captureMode.isTableFocused ? 8 : 4)
            if currentBest.score >= minimumScore, currentBest.text.count >= minimumLength {
                return false
            }
        }

        if captureMode.isTableFocused {
            return false
        }

        let aspectRatio = rect.width / max(rect.height, 1)
        if captureMode.isSubtitleFocused {
            return rect.width >= 220 && (aspectRatio >= 1.6 || rect.height <= 220)
        }

        guard rect.width >= 320 else {
            return false
        }

        return aspectRatio >= 2.5 || rect.height <= 300
    }

    static func buildRetryAttempts(
        selectionRect: CGRect,
        primaryCaptureRect: CGRect,
        captureMode: CaptureMode,
        preferredDisplay: ScreenDescriptor?,
        environment: ScreenEnvironmentSnapshot
    ) -> [CaptureRetryAttempt] {
        let expandedRect = preferredCaptureRect(
            for: selectionRect,
            captureMode: captureMode,
            preferredDisplay: preferredDisplay,
            environment: environment
        )
        let baseDelays = subtitleRetryDelays()
        let rects: [CGRect] = primaryCaptureRect.equalTo(expandedRect)
            ? Array(repeating: primaryCaptureRect, count: baseDelays.count)
            : [expandedRect, primaryCaptureRect, expandedRect]

        return zip(baseDelays.indices, baseDelays).map { index, delay in
            CaptureRetryAttempt(
                label: "video-retry-\(index + 1)",
                captureRect: rects[min(index, rects.count - 1)],
                delayNanoseconds: delay
            )
        }
    }

    static func subtitleRetryDelays() -> [UInt64] {
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil {
            return [1_000_000, 1_000_000, 1_000_000]
        }

        return [350_000_000, 550_000_000, 850_000_000]
    }

    static func captureBounds(
        for preferredDisplay: ScreenDescriptor?,
        environment: ScreenEnvironmentSnapshot
    ) -> CGRect {
        if let preferredDisplay {
            return preferredDisplay.frame
        }

        return environment.desktopBounds
    }

    static func normalizedRecognizedText(_ text: String) -> String {
        text
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func applyConsensusBoost(
        to selection: CaptureOCRSelection,
        frequencies: inout [String: Int]
    ) -> CaptureOCRSelection {
        let normalized = normalizedRecognizedText(selection.text)
        let seenCount = (frequencies[normalized] ?? 0) + 1
        frequencies[normalized] = seenCount

        return CaptureOCRSelection(
            candidate: selection.candidate,
            ocrResult: selection.ocrResult,
            text: selection.text,
            score: selection.score + Float(seenCount - 1) * 45,
            attemptLabel: selection.attemptLabel,
            kind: selection.kind
        )
    }

    static func hasStrongVideoResult(_ selection: CaptureOCRSelection, frequencies: [String: Int]) -> Bool {
        let normalized = normalizedRecognizedText(selection.text)
        let seenCount = frequencies[normalized] ?? 0
        return seenCount >= 2 || selection.score >= 240
    }
}
