import AppKit
import CoreImage
import CoreGraphics
import Vision
import VisionKit
import ImageIO

struct BarcodePayload: Equatable, Sendable {
    let payload: String
    let symbology: String

    var displayName: String {
        let lowercased = symbology.lowercased()
        if lowercased.contains("qr") {
            return "QR kodu"
        }
        if lowercased.contains("aztec") {
            return "Aztec kodu"
        }
        if lowercased.contains("pdf417") {
            return "PDF417 barkodu"
        }
        return "Barkod"
    }
}

protocol OCRProviding: Sendable {
    func recognizeText(
        in image: CGImage,
        sourceRect: CGRect,
        preferredRegions: [CGRect],
        captureMode: CaptureMode,
        languageSelection: OCRLanguageSelection?
    ) async throws -> OCRResult
    func detectBarcode(in image: CGImage) async throws -> BarcodePayload?
}

extension OCRProviding {
    func recognizeText(
        in image: CGImage,
        sourceRect: CGRect,
        preferredRegions: [CGRect]
    ) async throws -> OCRResult {
        try await recognizeText(
            in: image,
            sourceRect: sourceRect,
            preferredRegions: preferredRegions,
            captureMode: .standard,
            languageSelection: nil
        )
    }

    func recognizeText(in image: CGImage, sourceRect: CGRect) async throws -> OCRResult {
        try await recognizeText(
            in: image,
            sourceRect: sourceRect,
            preferredRegions: [],
            captureMode: .standard,
            languageSelection: nil
        )
    }
}

final class OCRService: OCRProviding, @unchecked Sendable {
    private static let ciContext = CIContext(options: [
        .useSoftwareRenderer: false
    ])
    private static let supportedRecognitionLanguageIdentifiers = loadSupportedRecognitionLanguageIdentifiers()
    static let availableLanguagePreferences: [OCRLanguagePreference] = {
        let filtered = OCRLanguagePreference.allCases.filter {
            supportedRecognitionLanguageIdentifiers.contains($0.rawValue)
        }
        return filtered.isEmpty ? OCRLanguageSelection.fallbackLanguages : filtered
    }()

    func recognizeText(
        in image: CGImage,
        sourceRect: CGRect,
        preferredRegions: [CGRect],
        captureMode: CaptureMode,
        languageSelection: OCRLanguageSelection? = nil
    ) async throws -> OCRResult {
        let tableGuides = captureMode.isTableFocused
            ? Self.detectTableGuideSeparators(in: image)
            : []
        let variants = Self.buildVariants(for: image, captureMode: captureMode)
        let passes = Self.buildPasses(
            for: variants,
            preferredRegions: preferredRegions,
            captureMode: captureMode,
            languageSelection: languageSelection
        )
        var bestResult: (label: String, result: OCRResult, score: Float)?
        var lastError: Error?
        var successfulPassCount = 0

        for pass in passes {
            do {
                let blocks = try await performRequest(
                    image: pass.variant.image,
                    recognitionLevel: pass.recognitionLevel,
                    recognitionLanguages: pass.recognitionLanguages,
                    usesLanguageCorrection: pass.usesLanguageCorrection,
                    minimumTextHeight: pass.minimumTextHeight,
                    regionOfInterest: pass.regionOfInterest
                )

                successfulPassCount += 1
                let result = OCRResult(
                    blocks: blocks,
                    captureDate: Date(),
                    sourceRect: sourceRect,
                    tableGuides: tableGuides
                )
                let text = result.fullText(for: captureMode).trimmingCharacters(in: .whitespacesAndNewlines)
                let score = Self.score(
                    result: result,
                    text: text,
                    pass: pass,
                    captureMode: captureMode
                )

                STGLog.ocr.info(
                    "OCR pass=\(pass.label, privacy: .public) blocks=\(blocks.count) chars=\(text.count) conf=\(result.averageConfidence) score=\(score)"
                )

                if !text.isEmpty {
                    if let current = bestResult {
                        if score > current.score {
                            bestResult = (pass.label, result, score)
                        }
                    } else {
                        bestResult = (pass.label, result, score)
                    }

                    if result.averageConfidence >= 0.82 && text.count >= 3 {
                        STGLog.ocr.info("OCR early success on pass=\(pass.label, privacy: .public)")
                        // Return the best result found so far, not just the current pass.
                        // An earlier pass may have produced higher-quality text even if this
                        // pass has sufficient confidence to trigger early exit.
                        return bestResult?.result ?? result
                    }
                }
            } catch {
                lastError = error
                STGLog.ocr.error("OCR pass failed: \(pass.label, privacy: .public) - \(error.localizedDescription, privacy: .public)")
            }
        }

        if let bestResult {
            STGLog.ocr.info("OCR selected pass=\(bestResult.label, privacy: .public) score=\(bestResult.score)")
            return bestResult.result
        }

        if let imageAnalyzerResult = try await analyzeWithImageAnalyzer(
            variants: variants,
            sourceRect: sourceRect,
            captureMode: captureMode,
            tableGuides: tableGuides
        ) {
            STGLog.ocr.info(
                "OCR selected VisionKit pass=\(imageAnalyzerResult.label, privacy: .public) score=\(imageAnalyzerResult.score)"
            )
            return imageAnalyzerResult.result
        }

        if successfulPassCount == 0, let lastError {
            throw lastError
        }

        return OCRResult(
            blocks: [],
            captureDate: Date(),
            sourceRect: sourceRect,
            tableGuides: tableGuides
        )
    }

    func detectBarcode(in image: CGImage) async throws -> BarcodePayload? {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNBarcodeObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                let bestMatch = observations
                    .compactMap { observation -> (payload: BarcodePayload, score: Float)? in
                        guard let payload = observation.payloadStringValue?
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                              !payload.isEmpty else {
                            return nil
                        }

                        let symbology = observation.symbology.rawValue
                        let area = Float(observation.boundingBox.width * observation.boundingBox.height)
                        let bonus: Float = symbology.lowercased().contains("qr") ? 32 : 16
                        let score = observation.confidence * 260 + area * 140 + bonus
                        return (BarcodePayload(payload: payload, symbology: symbology), score)
                    }
                    .max { $0.score < $1.score }

                continuation.resume(returning: bestMatch?.payload)
            }

            do {
                try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func performRequest(
        image: CGImage,
        recognitionLevel: VNRequestTextRecognitionLevel,
        recognitionLanguages: [String],
        usesLanguageCorrection: Bool,
        minimumTextHeight: Float,
        regionOfInterest: CGRect?
    ) async throws -> [OCRTextBlock] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    STGLog.ocr.error("OCR request failed: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let blocks = observations.compactMap { observation -> OCRTextBlock? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return OCRTextBlock(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }

                continuation.resume(returning: blocks)
            }

            request.recognitionLevel = recognitionLevel
            request.usesLanguageCorrection = usesLanguageCorrection
            request.minimumTextHeight = minimumTextHeight
            if !recognitionLanguages.isEmpty {
                request.recognitionLanguages = recognitionLanguages
            } else if #available(macOS 13.0, *) {
                request.automaticallyDetectsLanguage = true
            }
            if let regionOfInterest {
                request.regionOfInterest = regionOfInterest
            }

            do {
                try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func preprocessForOCR(image: CGImage) -> CGImage {
        let base = CIImage(cgImage: image)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputContrastKey: 1.9,
                kCIInputBrightnessKey: 0.02
            ])
            .applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.8,
                kCIInputIntensityKey: 1.2
            ])

        let maxDimension = max(base.extent.width, base.extent.height)
        let scale = maxDimension > 0 ? min(4.0, 5200.0 / maxDimension) : 1.0

        let scaled = base.applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: max(scale, 1.0),
            kCIInputAspectRatioKey: 1.0
        ])

        let extent = scaled.extent.integral
        guard !extent.isEmpty,
              let output = ciContext.createCGImage(scaled, from: extent) else {
            return image
        }

        return output
    }

    private static func buildVariants(for image: CGImage, captureMode: CaptureMode) -> [OCRVariant] {
        let enhanced = preprocessForOCR(image: image)
        var variants: [OCRVariant] = [
            OCRVariant(name: "original", image: image),
            OCRVariant(name: "enhanced", image: enhanced)
        ]

        if let binary = binarize(image: enhanced, inverted: false) {
            variants.append(OCRVariant(name: "binary", image: binary))
        }

        if let invertedBinary = binarize(image: enhanced, inverted: true) {
            variants.append(OCRVariant(name: "binary-inverted", image: invertedBinary))
        }

        if !captureMode.isCodeFocused && !captureMode.isTableFocused {
            variants.append(contentsOf: buildSubtitleBandVariants(for: image, captureMode: captureMode))
        }

        return variants
    }

    private static func buildPasses(
        for variants: [OCRVariant],
        preferredRegions: [CGRect],
        captureMode: CaptureMode,
        languageSelection: OCRLanguageSelection?
    ) -> [OCRPass] {
        let preferredLanguages = currentRecognitionLanguages(languageSelection)
        var focusRegions = preferredRegions
        if captureMode.isSubtitleFocused {
            focusRegions.append(contentsOf: subtitleFocusRegions())
        }
        if captureMode.isCodeFocused {
            focusRegions.append(contentsOf: codeFocusRegions())
        }
        if captureMode.isTableFocused {
            focusRegions.append(contentsOf: tableFocusRegions())
        }

        let orderedVariants = orderedVariants(for: variants, captureMode: captureMode)
        var passes: [OCRPass] = buildFocusPasses(
            for: orderedVariants,
            preferredRegions: focusRegions,
            preferredLanguages: preferredLanguages,
            captureMode: captureMode
        )

        for variant in orderedVariants {
            let isSubtitleBand = variant.name.contains("subtitle-band")
            let isBottomFocused = variant.name.contains("subtitle-band")

            if captureMode.isSubtitleFocused {
                passes.append(OCRPass(
                    label: "\(variant.name)-subtitle-bottom-accurate",
                    variant: variant,
                    recognitionLevel: .accurate,
                    recognitionLanguages: preferredLanguages,
                    usesLanguageCorrection: true,
                    minimumTextHeight: isSubtitleBand ? 0.0008 : 0.0014,
                    regionOfInterest: isBottomFocused ? nil : CGRect(x: 0.0, y: 0.0, width: 1.0, height: 0.44),
                    priorityBonus: isSubtitleBand ? 52 : 36
                ))

                passes.append(OCRPass(
                    label: "\(variant.name)-subtitle-bottom-fast",
                    variant: variant,
                    recognitionLevel: .fast,
                    recognitionLanguages: preferredLanguages,
                    usesLanguageCorrection: false,
                    minimumTextHeight: isSubtitleBand ? 0.0005 : 0.0010,
                    regionOfInterest: isBottomFocused ? nil : CGRect(x: 0.05, y: 0.0, width: 0.90, height: 0.30),
                    priorityBonus: isSubtitleBand ? 44 : 30
                ))
            }

            if captureMode.isCodeFocused {
                passes.append(OCRPass(
                    label: "\(variant.name)-code-accurate",
                    variant: variant,
                    recognitionLevel: .accurate,
                    recognitionLanguages: preferredLanguages,
                    usesLanguageCorrection: false,
                    minimumTextHeight: 0.0010,
                    regionOfInterest: nil,
                    priorityBonus: variant.name.contains("binary") ? 34 : 22
                ))

                passes.append(OCRPass(
                    label: "\(variant.name)-code-fast",
                    variant: variant,
                    recognitionLevel: .fast,
                    recognitionLanguages: preferredLanguages,
                    usesLanguageCorrection: false,
                    minimumTextHeight: 0.0007,
                    regionOfInterest: nil,
                    priorityBonus: variant.name.contains("binary") ? 24 : 16
                ))
            }

            if captureMode.isTableFocused {
                passes.append(OCRPass(
                    label: "\(variant.name)-table-accurate",
                    variant: variant,
                    recognitionLevel: .accurate,
                    recognitionLanguages: preferredLanguages,
                    usesLanguageCorrection: true,
                    minimumTextHeight: variant.name.contains("binary") ? 0.0012 : 0.0015,
                    regionOfInterest: nil,
                    priorityBonus: variant.name.contains("binary") ? 22 : 30
                ))

                passes.append(OCRPass(
                    label: "\(variant.name)-table-fast",
                    variant: variant,
                    recognitionLevel: .fast,
                    recognitionLanguages: preferredLanguages,
                    usesLanguageCorrection: false,
                    minimumTextHeight: variant.name.contains("binary") ? 0.0008 : 0.0010,
                    regionOfInterest: nil,
                    priorityBonus: variant.name.contains("binary") ? 14 : 20
                ))
            }

            passes.append(OCRPass(
                label: "\(variant.name)-full-accurate",
                variant: variant,
                recognitionLevel: .accurate,
                recognitionLanguages: preferredLanguages,
                usesLanguageCorrection: !captureMode.isCodeFocused,
                minimumTextHeight: isSubtitleBand ? 0.0012 : (captureMode.isTableFocused ? 0.0022 : 0.0035),
                regionOfInterest: nil,
                priorityBonus: isSubtitleBand ? 18 : (captureMode.isSubtitleFocused ? 4 : (captureMode.isCodeFocused ? 10 : (captureMode.isTableFocused ? 12 : 0)))
            ))

            passes.append(OCRPass(
                label: "\(variant.name)-full-fast",
                variant: variant,
                recognitionLevel: .fast,
                recognitionLanguages: preferredLanguages,
                usesLanguageCorrection: false,
                minimumTextHeight: isSubtitleBand ? 0.0008 : (captureMode.isTableFocused ? 0.0016 : 0.0025),
                regionOfInterest: nil,
                priorityBonus: isSubtitleBand ? 10 : (captureMode.isSubtitleFocused ? 2 : (captureMode.isCodeFocused ? 6 : (captureMode.isTableFocused ? 8 : 0)))
            ))

            if !captureMode.isTableFocused && !isSubtitleBand && variant.image.width > Int(CGFloat(variant.image.height) * 1.2) {
                passes.append(OCRPass(
                    label: "\(variant.name)-bottom45-accurate",
                    variant: variant,
                    recognitionLevel: .accurate,
                    recognitionLanguages: preferredLanguages,
                    usesLanguageCorrection: !captureMode.isCodeFocused,
                    minimumTextHeight: 0.002,
                    regionOfInterest: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 0.45),
                    priorityBonus: captureMode.isSubtitleFocused ? 26 : 14
                ))

                passes.append(OCRPass(
                    label: "\(variant.name)-bottom30-fast",
                    variant: variant,
                    recognitionLevel: .fast,
                    recognitionLanguages: preferredLanguages,
                    usesLanguageCorrection: false,
                    minimumTextHeight: 0.0015,
                    regionOfInterest: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 0.30),
                    priorityBonus: captureMode.isSubtitleFocused ? 20 : 10
                ))
            }
        }

        return passes
    }

    private static func buildFocusPasses(
        for variants: [OCRVariant],
        preferredRegions: [CGRect],
        preferredLanguages: [String],
        captureMode: CaptureMode
    ) -> [OCRPass] {
        let clampedRegions = preferredRegions
            .map { $0.intersection(CGRect(x: 0, y: 0, width: 1, height: 1)).standardized }
            .filter { $0.width > 0.02 && $0.height > 0.02 }

        guard !clampedRegions.isEmpty else {
            return []
        }

        let focusVariants = variants.filter {
            $0.name == "original" ||
            $0.name == "enhanced" ||
            $0.name == "binary" ||
            $0.name == "binary-inverted" ||
            $0.name.contains("subtitle-band")
        }

        var passes: [OCRPass] = []
        for (index, region) in clampedRegions.prefix(2).enumerated() {
            for variant in focusVariants.prefix(4) {
                passes.append(OCRPass(
                    label: "focus\(index + 1)-\(variant.name)-accurate",
                    variant: variant,
                    recognitionLevel: .accurate,
                    recognitionLanguages: preferredLanguages,
                    usesLanguageCorrection: !captureMode.isCodeFocused,
                    minimumTextHeight: captureMode.isCodeFocused ? 0.00030 : (captureMode.isTableFocused ? 0.00024 : 0.00045),
                    regionOfInterest: region,
                    priorityBonus: captureMode.isCodeFocused ? 50 : (captureMode.isTableFocused ? 48 : 42)
                ))

                passes.append(OCRPass(
                    label: "focus\(index + 1)-\(variant.name)-fast",
                    variant: variant,
                    recognitionLevel: .fast,
                    recognitionLanguages: preferredLanguages,
                    usesLanguageCorrection: false,
                    minimumTextHeight: captureMode.isCodeFocused ? 0.00018 : (captureMode.isTableFocused ? 0.00014 : 0.00025),
                    regionOfInterest: region,
                    priorityBonus: captureMode.isCodeFocused ? 36 : (captureMode.isTableFocused ? 34 : 30)
                ))
            }
        }

        return passes
    }

    private static func score(
        result: OCRResult,
        text: String,
        pass: OCRPass,
        captureMode: CaptureMode
    ) -> Float {
        var score = result.averageConfidence * 300
        score += min(Float(text.count), 140) * 0.8
        score += Float(result.blocks.count) * 6
        score += pass.priorityBonus

        if pass.regionOfInterest != nil {
            score += 10
        }

        if pass.variant.name.contains("binary") {
            score += 6
        }

        if pass.variant.name.contains("subtitle-band") {
            score += 18
        }

        if captureMode.isSubtitleFocused {
            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized.count >= 6 {
                score += 12
            }

            if result.blocks.count <= 3 {
                score += 8
            }

            if let region = pass.regionOfInterest, region.maxY <= 0.48 {
                score += 12
            }
        }

        if captureMode.isCodeFocused {
            score += codeSignalScore(text)
            if pass.variant.name.contains("binary") {
                score += 10
            }
            if !pass.usesLanguageCorrection {
                score += 8
            }
        }

        if captureMode.isTableFocused {
            score += tableSignalScore(text)
            if pass.variant.name == "enhanced" {
                score += 6
            }
            if pass.regionOfInterest != nil {
                score += 6
            }
        }

        return score
    }

    @available(macOS 13.0, *)
    private func analyzeWithImageAnalyzer(
        variants: [OCRVariant],
        sourceRect: CGRect,
        captureMode: CaptureMode,
        tableGuides: [CGFloat]
    ) async throws -> (label: String, result: OCRResult, score: Float)? {
        guard ImageAnalyzer.isSupported else {
            return nil
        }

        let analyzer = ImageAnalyzer()
        var configuration = ImageAnalyzer.Configuration(.text)
        configuration.locales = Self.currentRecognitionLanguages()

        var best: (label: String, result: OCRResult, score: Float)?

        for variant in Self.orderedVariants(for: variants, captureMode: captureMode).prefix(captureMode.isSubtitleFocused ? 6 : 4) {
            let analysis = try await analyzer.analyze(
                variant.image,
                orientation: .up,
                configuration: configuration
            )
            let transcript = analysis.transcript.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            guard !transcript.isEmpty else {
                continue
            }

            let result = OCRResult(
                blocks: [OCRTextBlock(
                    text: transcript,
                    confidence: 0.78,
                    boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1)
                )],
                captureDate: Date(),
                sourceRect: sourceRect,
                tableGuides: tableGuides
            )
            let text = result.fullText(for: captureMode)
            let score = Float(text.count) * 1.4
                + 170
                + (captureMode.isCodeFocused ? 24 : 0)
                + (captureMode.isTableFocused ? Self.tableSignalScore(text) : 0)

            STGLog.ocr.info(
                "VisionKit pass=\(variant.name, privacy: .public) chars=\(transcript.count) score=\(score)"
            )

            if let current = best {
                if score > current.score {
                    best = ("visionkit-\(variant.name)", result, score)
                }
            } else {
                best = ("visionkit-\(variant.name)", result, score)
            }
        }

        return best
    }

    private static func buildSubtitleBandVariants(for image: CGImage, captureMode: CaptureMode) -> [OCRVariant] {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let minimumWidth: CGFloat = captureMode.isSubtitleFocused ? 260 : 420
        let minimumHeight: CGFloat = captureMode.isSubtitleFocused ? 90 : 160
        let minimumAspectRatio: CGFloat = captureMode.isSubtitleFocused ? 1.15 : 1.45

        guard width >= minimumWidth,
              height >= minimumHeight,
              width / max(height, 1) >= minimumAspectRatio else {
            return []
        }

        let bandFractions: [(String, CGFloat)] = captureMode.isSubtitleFocused
            ? [("subtitle-band50", 0.50), ("subtitle-band36", 0.36), ("subtitle-band24", 0.24)]
            : [("subtitle-band42", 0.42), ("subtitle-band28", 0.28)]
        var variants: [OCRVariant] = []

        for (name, fraction) in bandFractions {
            guard let bandImage = cropBottomBand(image: image, heightFraction: fraction) else {
                continue
            }

            let enhancedBand = preprocessForOCR(image: bandImage)
            variants.append(OCRVariant(name: "\(name)-enhanced", image: enhancedBand))

            if let binaryBand = binarize(image: enhancedBand, inverted: false) {
                variants.append(OCRVariant(name: "\(name)-binary", image: binaryBand))
            }
        }

        return variants
    }

    private static func currentRecognitionLanguages(_ explicitSelection: OCRLanguageSelection? = nil) -> [String] {
        let selection = explicitSelection ?? OCRLanguageSelectionStore.load()
        if selection.automaticDetection {
            return []
        }

        let filtered = selection.recognitionLanguages.filter {
            supportedRecognitionLanguageIdentifiers.contains($0)
        }
        return filtered.isEmpty ? OCRLanguageSelection.fallbackLanguages.map(\.rawValue) : filtered
    }

    private static func subtitleFocusRegions() -> [CGRect] {
        [
            CGRect(x: 0.0, y: 0.0, width: 1.0, height: 0.42),
            CGRect(x: 0.05, y: 0.0, width: 0.90, height: 0.28)
        ]
    }

    private static func codeFocusRegions() -> [CGRect] {
        [
            CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0),
            CGRect(x: 0.02, y: 0.02, width: 0.96, height: 0.96)
        ]
    }

    private static func tableFocusRegions() -> [CGRect] {
        [
            CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0),
            CGRect(x: 0.015, y: 0.04, width: 0.97, height: 0.92)
        ]
    }

    private static func orderedVariants(for variants: [OCRVariant], captureMode: CaptureMode) -> [OCRVariant] {
        if captureMode.isSubtitleFocused {
            return variants.sorted { lhs, rhs in
                subtitleVariantRank(lhs.name) < subtitleVariantRank(rhs.name)
            }
        }

        if captureMode.isCodeFocused {
            return variants.sorted { lhs, rhs in
                codeVariantRank(lhs.name) < codeVariantRank(rhs.name)
            }
        }

        if captureMode.isTableFocused {
            return variants.sorted { lhs, rhs in
                tableVariantRank(lhs.name) < tableVariantRank(rhs.name)
            }
        }

        return variants
    }

    private static func subtitleVariantRank(_ name: String) -> Int {
        if name.contains("subtitle-band") && name.contains("binary") {
            return 0
        }
        if name.contains("subtitle-band") {
            return 1
        }
        if name.contains("binary") {
            return 2
        }
        if name == "enhanced" {
            return 3
        }
        if name == "original" {
            return 4
        }
        return 5
    }

    private static func codeVariantRank(_ name: String) -> Int {
        if name == "binary" {
            return 0
        }
        if name == "enhanced" {
            return 1
        }
        if name == "binary-inverted" {
            return 2
        }
        if name == "original" {
            return 3
        }
        return 4
    }

    private static func tableVariantRank(_ name: String) -> Int {
        if name == "enhanced" {
            return 0
        }
        if name == "original" {
            return 1
        }
        if name == "binary" {
            return 2
        }
        if name == "binary-inverted" {
            return 3
        }
        return 4
    }

    private static func codeSignalScore(_ text: String) -> Float {
        var score: Float = 0
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count >= 2 {
            score += 12
        }

        if text.contains("{") || text.contains("}") || text.contains("(") || text.contains(")") {
            score += 14
        }

        if text.contains("=") || text.contains("->") || text.contains("::") {
            score += 10
        }

        let codeKeywords = ["func ", "let ", "var ", "if ", "else", "return", "class ", "struct ", "import ", "for ", "while "]
        if codeKeywords.contains(where: { text.contains($0) }) {
            score += 18
        }

        return score
    }

    private static func tableSignalScore(_ text: String) -> Float {
        var score: Float = 0
        let rows = text.split(separator: "\n", omittingEmptySubsequences: false)
        let tabbedRows = rows.filter { $0.contains("\t") }

        if rows.count >= 2 {
            score += 10
        }

        if tabbedRows.count >= 2 {
            score += 18
        }

        if let maxTabs = tabbedRows.map({ $0.filter { $0 == "\t" }.count }).max() {
            score += Float(maxTabs) * 8
        }

        if text.contains("\t") {
            score += 12
        }

        return score
    }

    private static func loadSupportedRecognitionLanguageIdentifiers() -> Set<String> {
        var supported: Set<String> = []

        let accurateRequest = VNRecognizeTextRequest()
        accurateRequest.recognitionLevel = .accurate
        if let languages = try? accurateRequest.supportedRecognitionLanguages() {
            supported.formUnion(languages)
        }

        let fastRequest = VNRecognizeTextRequest()
        fastRequest.recognitionLevel = .fast
        if let languages = try? fastRequest.supportedRecognitionLanguages() {
            supported.formUnion(languages)
        }

        if supported.isEmpty {
            supported.formUnion(OCRLanguageSelection.fallbackLanguages.map(\.rawValue))
        }

        return supported
    }

    private static func cropBottomBand(image: CGImage, heightFraction: CGFloat) -> CGImage? {
        let cropHeight = max(CGFloat(image.height) * heightFraction, 64)
        let cropRect = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(image.width),
            height: min(cropHeight, CGFloat(image.height))
        ).integral

        guard cropRect.width > 1, cropRect.height > 1 else {
            return nil
        }

        return image.cropping(to: cropRect)
    }

    private static func binarize(image: CGImage, inverted: Bool) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var histogram = [Int](repeating: 0, count: 256)
        for idx in stride(from: 0, to: pixels.count, by: 4) {
            let r = Float(pixels[idx])
            let g = Float(pixels[idx + 1])
            let b = Float(pixels[idx + 2])
            let luminance = Int((0.2126 * r + 0.7152 * g + 0.0722 * b).rounded())
            histogram[max(0, min(255, luminance))] += 1
        }

        let threshold = otsuThreshold(histogram: histogram, totalPixels: width * height)

        for idx in stride(from: 0, to: pixels.count, by: 4) {
            let r = Float(pixels[idx])
            let g = Float(pixels[idx + 1])
            let b = Float(pixels[idx + 2])
            let luminance = Int((0.2126 * r + 0.7152 * g + 0.0722 * b).rounded())
            let isWhite = luminance >= threshold
            let value: UInt8 = {
                if inverted {
                    return isWhite ? 0 : 255
                }
                return isWhite ? 255 : 0
            }()

            pixels[idx] = value
            pixels[idx + 1] = value
            pixels[idx + 2] = value
            pixels[idx + 3] = 255
        }

        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData) else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    static func detectTableGuideSeparators(in image: CGImage) -> [CGFloat] {
        let enhanced = preprocessForOCR(image: image)
        guard let binary = binarize(image: enhanced, inverted: false) else {
            return []
        }

        let width = binary.width
        let height = binary.height
        guard width >= 48, height >= 48 else {
            return []
        }

        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 255, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }

        context.draw(binary, in: CGRect(x: 0, y: 0, width: width, height: height))

        struct ColumnMetric {
            let index: Int
            let density: CGFloat
            let longestRun: CGFloat
        }

        let metrics = (0..<width).map { columnIndex -> ColumnMetric in
            var darkPixels = 0
            var longestRun = 0
            var currentRun = 0

            for rowIndex in 0..<height {
                let offset = (rowIndex * bytesPerRow) + (columnIndex * 4)
                let isDark = pixels[offset] < 96
                if isDark {
                    darkPixels += 1
                    currentRun += 1
                    longestRun = max(longestRun, currentRun)
                } else {
                    currentRun = 0
                }
            }

            return ColumnMetric(
                index: columnIndex,
                density: CGFloat(darkPixels) / CGFloat(height),
                longestRun: CGFloat(longestRun) / CGFloat(height)
            )
        }

        let candidateColumns = metrics.filter {
            $0.longestRun >= 0.58 && $0.density >= 0.34
        }

        guard !candidateColumns.isEmpty else {
            return []
        }

        var clusters: [ClosedRange<Int>] = []
        for metric in candidateColumns {
            if let last = clusters.last, metric.index <= last.upperBound + 1 {
                clusters[clusters.count - 1] = last.lowerBound...metric.index
            } else {
                clusters.append(metric.index...metric.index)
            }
        }

        let maximumClusterWidth = max(3, Int(round(CGFloat(width) * 0.03)))
        return clusters.compactMap { cluster -> CGFloat? in
            let clusterWidth = cluster.upperBound - cluster.lowerBound + 1
            guard clusterWidth <= maximumClusterWidth else {
                return nil
            }

            let center = CGFloat(cluster.lowerBound + cluster.upperBound + 1) / (2 * CGFloat(width))
            guard (0.05...0.95).contains(center) else {
                return nil
            }

            return center
        }
    }

    private static func otsuThreshold(histogram: [Int], totalPixels: Int) -> Int {
        guard totalPixels > 0 else {
            return 128
        }

        var sum = 0.0
        for index in histogram.indices {
            sum += Double(index * histogram[index])
        }

        var sumBackground = 0.0
        var backgroundWeight = 0.0
        var maxVariance = 0.0
        var threshold = 128

        for index in histogram.indices {
            backgroundWeight += Double(histogram[index])
            if backgroundWeight == 0 {
                continue
            }

            let foregroundWeight = Double(totalPixels) - backgroundWeight
            if foregroundWeight == 0 {
                break
            }

            sumBackground += Double(index * histogram[index])
            let meanBackground = sumBackground / backgroundWeight
            let meanForeground = (sum - sumBackground) / foregroundWeight
            let variance = backgroundWeight * foregroundWeight * pow(meanBackground - meanForeground, 2)

            if variance > maxVariance {
                maxVariance = variance
                threshold = index
            }
        }

        return threshold
    }
}

private struct OCRVariant {
    let name: String
    let image: CGImage
}

private struct OCRPass {
    let label: String
    let variant: OCRVariant
    let recognitionLevel: VNRequestTextRecognitionLevel
    let recognitionLanguages: [String]
    let usesLanguageCorrection: Bool
    let minimumTextHeight: Float
    let regionOfInterest: CGRect?
    let priorityBonus: Float
}
