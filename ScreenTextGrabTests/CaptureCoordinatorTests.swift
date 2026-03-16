import ImageIO
import PDFKit
import UniformTypeIdentifiers
import XCTest
@testable import ScreenTextGrab

final class CaptureCoordinatorTests: XCTestCase {
    @MainActor
    func testDeniedPermissionDoesNotOpenOverlay() async {
        let appState = AppState()
        let permission = MockPermissionService()
        permission.refreshState = .denied
        permission.requestState = .denied

        let overlay = MockOverlay()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: permission,
            screenCaptureService: MockScreenCaptureService(),
            ocrService: MockOCRService(),
            clipboardService: MockClipboardService(),
            overlayFactory: { _, _ in overlay }
        )

        coordinator.startCapture(trigger: .menu)
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(overlay.showCount, 0)
        XCTAssertEqual(appState.permissionState, .denied)
        XCTAssertEqual(appState.captureState, .failed)
    }

    @MainActor
    func testGrantedPermissionShowsOverlay() async {
        let appState = AppState()
        let permission = MockPermissionService()
        permission.refreshState = .granted

        let overlay = MockOverlay()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: permission,
            screenCaptureService: MockScreenCaptureService(),
            ocrService: MockOCRService(),
            clipboardService: MockClipboardService(),
            overlayFactory: { _, _ in overlay }
        )

        coordinator.startCapture(trigger: .menu)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(overlay.showCount, 1)
        XCTAssertEqual(appState.captureState, .selecting)
        XCTAssertEqual(appState.permissionState, .granted)
    }

    @MainActor
    func testSCStreamNonPermissionErrorMapsToCaptureFailed() async {
        let appState = AppState()
        let capture = MockScreenCaptureService()
        capture.result = .failure(NSError(
            domain: "com.apple.ScreenCaptureKit.SCStreamErrorDomain",
            code: 9,
            userInfo: [NSLocalizedDescriptionKey: "Stream interrupted"]
        ))

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: MockOCRService(),
            clipboardService: MockClipboardService()
        )

        await coordinator.performCapturePipeline(
            screenRect: CGRect(x: 10, y: 10, width: 100, height: 40),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        guard case .captureFailed(let domain, let code, _) = appState.lastError else {
            XCTFail("Expected captureFailed error")
            return
        }

        XCTAssertEqual(domain, "com.apple.ScreenCaptureKit.SCStreamErrorDomain")
        XCTAssertEqual(code, 9)
    }

    @MainActor
    func testClipboardReadbackFailureDoesNotShowSuccessState() async {
        let appState = AppState()

        let capture = MockScreenCaptureService()
        capture.result = .success(Self.makeImage())

        let ocr = MockOCRService()
        ocr.result = .success(OCRResult(
            blocks: [OCRTextBlock(text: "Merhaba", confidence: 1, boundingBox: .zero)],
            captureDate: Date(),
            sourceRect: .zero
        ))

        let clipboard = MockClipboardService()
        clipboard.result = .failedReadback

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: ocr,
            clipboardService: clipboard
        )

        await coordinator.performCapturePipeline(
            screenRect: CGRect(x: 10, y: 10, width: 100, height: 40),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        XCTAssertEqual(appState.lastCopiedText, "", "lastCopiedText should remain empty when clipboard fails")
        XCTAssertEqual(appState.captureState, .failed)
        XCTAssertEqual(appState.lastError, .clipboardFailed(result: .failedReadback))
    }

    @MainActor
    func testBusyStatePreventsDuplicateStart() async {
        let appState = AppState()
        let permission = MockPermissionService()
        permission.refreshState = .granted

        let overlay = MockOverlay()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: permission,
            screenCaptureService: MockScreenCaptureService(),
            ocrService: MockOCRService(),
            clipboardService: MockClipboardService(),
            overlayFactory: { _, _ in overlay }
        )

        coordinator.startCapture(trigger: .menu)
        coordinator.startCapture(trigger: .hotkey)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(overlay.showCount, 1)
    }

    @MainActor
    func testSavedRegionCaptureUsesStoredSelectionAndOverrides() async {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedCaptureRegions = [
            SavedCaptureRegion(
                name: "Safari • Tablo",
                screenRect: CGRect(x: 40, y: 50, width: 260, height: 140),
                preferredDisplayID: nil,
                source: .init(appName: "Safari", bundleIdentifier: "com.apple.Safari"),
                sessionConfiguration: CaptureSessionConfiguration(
                    captureMode: .table,
                    outputPreset: .office,
                    ocrLanguageSelection: .defaultValue,
                    profileName: "Safari"
                )
            )
        ]

        let capture = MockScreenCaptureService()
        capture.result = .success(Self.makeImage())

        let ocr = MockOCRService()
        ocr.result = .success(OCRResult(
            blocks: [OCRTextBlock(text: "Merhaba", confidence: 0.95, boundingBox: .zero)],
            captureDate: Date(),
            sourceRect: .zero
        ))

        let clipboard = MockClipboardService()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: ocr,
            clipboardService: clipboard
        )

        coordinator.captureSavedRegion(
            named: "Safari • Tablo",
            sessionOverrides: AutomationCaptureOverrides(
                captureMode: .code,
                outputPreset: .plainText
            )
        )

        try? await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(capture.requestedRects.first, CGRect(x: 40, y: 50, width: 260, height: 140))
        XCTAssertEqual(ocr.receivedModes.first, .code)
        XCTAssertEqual(appState.lastCopiedText, "Merhaba")
        XCTAssertEqual(appState.lastCaptureSelection?.screenRect, CGRect(x: 40, y: 50, width: 260, height: 140))
    }

    @MainActor
    func testCopySavedSnippetUsesSavedFormattingMetadata() {
        let appState = AppState(persistsUserPreferences: false)
        appState.setCaptureMode(.table)
        appState.setCaptureOutputPreset(.json)
        appState.savedSnippets = [
            SavedSnippet(
                name: "Kod parcasi",
                text: "```text\nif (value) {\n    print(value)\n}\n```",
                rawText: "if (value) {\n    print(value)\n}",
                captureMode: .code,
                outputPreset: .markdown,
                contentKind: .text,
                ocrConfidence: 0.88,
                source: .init(appName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode")
            )
        ]

        let clipboard = MockClipboardService()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: MockScreenCaptureService(),
            ocrService: MockOCRService(),
            clipboardService: clipboard
        )

        let result = coordinator.copySavedSnippet(named: "Kod parcasi")

        XCTAssertEqual(result, .success)
        XCTAssertEqual(
            clipboard.copiedTexts.last,
            "```text\nif (value) {\n    print(value)\n}\n```"
        )
        XCTAssertEqual(appState.lastCopiedText, "```text\nif (value) {\n    print(value)\n}\n```")
        XCTAssertEqual(appState.copyHistory.first?.captureMode, .code)
        XCTAssertEqual(appState.copyHistory.first?.outputPreset, .markdown)
        XCTAssertNotNil(appState.savedSnippets.first?.lastUsedAt)
    }

    @MainActor
    func testCopySavedSnippetUsesActiveAppProfileOutputPresetOverride() {
        let appState = AppState(persistsUserPreferences: false)
        appState.appProfiles = [
            AppCaptureProfile(
                bundleIdentifier: "com.microsoft.Word",
                appName: "Microsoft Word",
                captureMode: .standard,
                outputPreset: .office,
                ocrLanguageSelection: .defaultValue
            )
        ]
        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Word", bundleIdentifier: "com.microsoft.Word")
        )
        appState.savedSnippets = [
            SavedSnippet(
                name: "Kod parcasi",
                text: "```text\nif (value) {\n    print(value)\n}\n```",
                rawText: "if (value) {\n    print(value)\n}",
                captureMode: .code,
                outputPreset: .markdown,
                contentKind: .text,
                ocrConfidence: 0.88,
                source: .init(appName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode")
            )
        ]

        let clipboard = MockClipboardService()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: MockScreenCaptureService(),
            ocrService: MockOCRService(),
            clipboardService: clipboard
        )

        let result = coordinator.copySavedSnippet(named: "Kod parcasi")

        XCTAssertEqual(result, .success)
        XCTAssertEqual(clipboard.copiedTexts.last, "if (value) {\n    print(value)\n}")
        XCTAssertEqual(clipboard.copiedPayloads.last?.targetProfile, .wordProcessor)
        XCTAssertTrue(clipboard.copiedPayloads.last?.html?.contains("<pre") == true)
        XCTAssertEqual(appState.copyHistory.first?.outputPreset, .office)
        XCTAssertEqual(appState.copyHistory.first?.source?.bundleIdentifier, "com.apple.dt.Xcode")
        XCTAssertEqual(appState.statusMessage, "✅ Microsoft Word için Office çıktısı kopyalandı")
    }

    // MARK: - New Tests

    @MainActor
    func testNoTextFoundSetsCompletedEmpty() async {
        let appState = AppState()

        let capture = MockScreenCaptureService()
        capture.result = .success(Self.makeImage())

        let ocr = MockOCRService()
        ocr.result = .success(OCRResult(
            blocks: [],
            captureDate: Date(),
            sourceRect: .zero
        ))

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: ocr,
            clipboardService: MockClipboardService()
        )

        await coordinator.performCapturePipeline(
            screenRect: CGRect(x: 10, y: 10, width: 100, height: 40),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        XCTAssertEqual(appState.captureState, .completedEmpty, "State should be .completedEmpty when no text is found")
        XCTAssertTrue(appState.lastCopiedText.isEmpty, "No text should be copied when OCR finds nothing")
    }

    @MainActor
    func testClipboardFailureDoesNotSetLastCopiedText() async {
        let appState = AppState()

        let capture = MockScreenCaptureService()
        capture.result = .success(Self.makeImage())

        let ocr = MockOCRService()
        ocr.result = .success(OCRResult(
            blocks: [OCRTextBlock(text: "Test metin", confidence: 0.95, boundingBox: .zero)],
            captureDate: Date(),
            sourceRect: .zero
        ))

        let clipboard = MockClipboardService()
        clipboard.result = .failedWrite

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: ocr,
            clipboardService: clipboard
        )

        await coordinator.performCapturePipeline(
            screenRect: CGRect(x: 10, y: 10, width: 100, height: 40),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        XCTAssertEqual(appState.lastCopiedText, "", "lastCopiedText must remain empty when clipboard write fails")
        XCTAssertEqual(appState.captureState, .failed)
    }

    @MainActor
    func testVideoRetryRecoversTextAfterInitialMiss() async {
        let appState = AppState()

        let capture = MockScreenCaptureService()
        capture.candidateBatches = [
            [CaptureCandidate(strategy: .screenshotKitGlobalRect, image: Self.makeImage(), debugInfo: "initial")],
            [CaptureCandidate(strategy: .screenshotKitGlobalRect, image: Self.makeImage(), debugInfo: "retry-1")]
        ]

        let ocr = MockOCRService()
        ocr.resultQueue = [
            .success(OCRResult(blocks: [], captureDate: Date(), sourceRect: .zero)),
            .success(OCRResult(
                blocks: [OCRTextBlock(text: "altyazi bulundu", confidence: 0.93, boundingBox: .zero)],
                captureDate: Date(),
                sourceRect: .zero
            ))
        ]

        let clipboard = MockClipboardService()

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: ocr,
            clipboardService: clipboard
        )

        await coordinator.performCapturePipeline(
            screenRect: CGRect(x: 10, y: 10, width: 900, height: 90),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        XCTAssertEqual(capture.captureCallCount, 2, "Video-like selections should retry when first OCR pass is empty")
        XCTAssertEqual(capture.requestedRects.first, CGRect(x: 10, y: 10, width: 900, height: 90))
        XCTAssertTrue((capture.requestedRects.last?.height ?? 0) > 90, "Retry should be allowed to expand beyond the exact subtitle strip")
        XCTAssertEqual(appState.captureState, .completed)
        XCTAssertEqual(appState.lastCopiedText, "altyazi bulundu")
        XCTAssertEqual(appState.lastCopiedEntry?.confidenceIndicator, .high)
    }

    @MainActor
    func testSubtitleModeRetriesCompactSelectionsAndPassesModeToOCR() async {
        let appState = AppState()
        appState.setCaptureMode(.subtitle)

        let capture = MockScreenCaptureService()
        capture.candidateBatches = [
            [CaptureCandidate(strategy: .screenshotKitGlobalRect, image: Self.makeImage(), debugInfo: "initial")],
            [CaptureCandidate(strategy: .screenshotKitGlobalRect, image: Self.makeImage(), debugInfo: "retry-1")]
        ]

        let ocr = MockOCRService()
        ocr.resultQueue = [
            .success(OCRResult(blocks: [], captureDate: Date(), sourceRect: .zero)),
            .success(OCRResult(
                blocks: [OCRTextBlock(text: "altyazi ikinci denemede", confidence: 0.94, boundingBox: .zero)],
                captureDate: Date(),
                sourceRect: .zero
            ))
        ]

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: ocr,
            clipboardService: MockClipboardService()
        )

        await coordinator.performCapturePipeline(
            screenRect: CGRect(x: 10, y: 10, width: 260, height: 120),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        XCTAssertEqual(capture.captureCallCount, 2, "Subtitle mode should retry compact subtitle selections")
        XCTAssertTrue((capture.requestedRects.last?.height ?? 0) > 120, "Subtitle retry should expand the selected band")
        XCTAssertEqual(ocr.receivedModes, [.subtitle, .subtitle])
        XCTAssertEqual(appState.captureState, .completed)
    }

    @MainActor
    func testCodeModeCopiesFormattedCodeText() async {
        let appState = AppState()
        appState.setCaptureMode(.code)

        let capture = MockScreenCaptureService()
        capture.result = .success(Self.makeImage())

        let ocr = MockOCRService()
        ocr.result = .success(OCRResult(
            blocks: [
                OCRTextBlock(text: "if", confidence: 0.96, boundingBox: CGRect(x: 0.10, y: 0.82, width: 0.05, height: 0.04)),
                OCRTextBlock(text: "(", confidence: 0.96, boundingBox: CGRect(x: 0.17, y: 0.82, width: 0.01, height: 0.04)),
                OCRTextBlock(text: "value", confidence: 0.96, boundingBox: CGRect(x: 0.19, y: 0.82, width: 0.12, height: 0.04)),
                OCRTextBlock(text: ")", confidence: 0.96, boundingBox: CGRect(x: 0.32, y: 0.82, width: 0.01, height: 0.04)),
                OCRTextBlock(text: "{", confidence: 0.96, boundingBox: CGRect(x: 0.35, y: 0.82, width: 0.01, height: 0.04)),
                OCRTextBlock(text: "print", confidence: 0.95, boundingBox: CGRect(x: 0.20, y: 0.72, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "(", confidence: 0.95, boundingBox: CGRect(x: 0.31, y: 0.72, width: 0.01, height: 0.04)),
                OCRTextBlock(text: "value", confidence: 0.95, boundingBox: CGRect(x: 0.33, y: 0.72, width: 0.12, height: 0.04)),
                OCRTextBlock(text: ")", confidence: 0.95, boundingBox: CGRect(x: 0.46, y: 0.72, width: 0.01, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        ))

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: ocr,
            clipboardService: MockClipboardService()
        )

        await coordinator.performCapturePipeline(
            screenRect: CGRect(x: 10, y: 10, width: 380, height: 220),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        XCTAssertEqual(ocr.receivedModes, [.code])
        XCTAssertEqual(appState.lastCopiedText, "if (value) {\n    print(value)")
        XCTAssertEqual(appState.captureState, .completed)
    }

    @MainActor
    func testMarkdownOutputPresetFormatsCopiedCodeAndStoresRawText() async {
        let appState = AppState()
        appState.setCaptureMode(.code)
        appState.setCaptureOutputPreset(.markdown)

        let capture = MockScreenCaptureService()
        capture.result = .success(Self.makeImage())

        let ocr = MockOCRService()
        ocr.result = .success(OCRResult(
            blocks: [
                OCRTextBlock(text: "if", confidence: 0.96, boundingBox: CGRect(x: 0.10, y: 0.82, width: 0.05, height: 0.04)),
                OCRTextBlock(text: "(", confidence: 0.96, boundingBox: CGRect(x: 0.17, y: 0.82, width: 0.01, height: 0.04)),
                OCRTextBlock(text: "value", confidence: 0.96, boundingBox: CGRect(x: 0.19, y: 0.82, width: 0.12, height: 0.04)),
                OCRTextBlock(text: ")", confidence: 0.96, boundingBox: CGRect(x: 0.32, y: 0.82, width: 0.01, height: 0.04)),
                OCRTextBlock(text: "{", confidence: 0.96, boundingBox: CGRect(x: 0.35, y: 0.82, width: 0.01, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        ))

        let clipboard = MockClipboardService()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: ocr,
            clipboardService: clipboard
        )

        await coordinator.performCapturePipeline(
            screenRect: CGRect(x: 10, y: 10, width: 220, height: 120),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        XCTAssertEqual(appState.lastCopiedText, "```text\nif (value) {\n```")
        XCTAssertEqual(clipboard.copiedTexts.last, "```text\nif (value) {\n```")
        XCTAssertEqual(appState.copyHistory.first?.rawText, "if (value) {")
        XCTAssertEqual(appState.copyHistory.first?.outputPreset, .markdown)
    }

    @MainActor
    func testOfficeOutputPresetWritesRichTablePayload() async {
        let appState = AppState()
        appState.setCaptureMode(.table)
        appState.setCaptureOutputPreset(.office)

        let capture = MockScreenCaptureService()
        capture.result = .success(Self.makeImage())

        let ocr = MockOCRService()
        ocr.result = .success(OCRResult(
            blocks: [
                OCRTextBlock(text: "Urun", confidence: 0.97, boundingBox: CGRect(x: 0.12, y: 0.84, width: 0.12, height: 0.05)),
                OCRTextBlock(text: "Fiyat", confidence: 0.97, boundingBox: CGRect(x: 0.55, y: 0.84, width: 0.12, height: 0.05)),
                OCRTextBlock(text: "Elma", confidence: 0.97, boundingBox: CGRect(x: 0.12, y: 0.72, width: 0.12, height: 0.05)),
                OCRTextBlock(text: "12.99", confidence: 0.97, boundingBox: CGRect(x: 0.55, y: 0.72, width: 0.12, height: 0.05))
            ],
            captureDate: Date(),
            sourceRect: .zero
        ))

        let clipboard = MockClipboardService()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: ocr,
            clipboardService: clipboard
        )

        await coordinator.performCapturePipeline(
            screenRect: CGRect(x: 10, y: 10, width: 260, height: 140),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        XCTAssertEqual(appState.lastCopiedText, "Urun\tFiyat\nElma\t12.99")
        XCTAssertEqual(clipboard.copiedTexts.last, "Urun\tFiyat\nElma\t12.99")
        XCTAssertEqual(clipboard.copiedPayloads.last?.tabularText, "Urun\tFiyat\nElma\t12.99")
        XCTAssertTrue(clipboard.copiedPayloads.last?.html?.contains("<table") == true)
        XCTAssertEqual(appState.copyHistory.first?.outputPreset, .office)
    }

    @MainActor
    func testSessionConfigurationOverridesLanguageSelectionAndOutputPreset() async {
        let appState = AppState()

        let capture = MockScreenCaptureService()
        capture.result = .success(Self.makeImage())

        let ocr = MockOCRService()
        ocr.result = .success(OCRResult(
            blocks: [OCRTextBlock(text: "kod satiri", confidence: 0.95, boundingBox: .zero)],
            captureDate: Date(),
            sourceRect: .zero
        ))

        let clipboard = MockClipboardService()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: ocr,
            clipboardService: clipboard
        )

        let selection = OCRLanguageSelection(automaticDetection: false, languages: [.english])
        await coordinator.performCapturePipeline(
            screenRect: CGRect(x: 10, y: 10, width: 180, height: 80),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment,
            source: .init(appName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
            sessionConfiguration: CaptureSessionConfiguration(
                captureMode: .code,
                outputPreset: .markdown,
                ocrLanguageSelection: selection,
                profileName: "Xcode"
            )
        )

        XCTAssertEqual(ocr.receivedModes, [.code])
        XCTAssertEqual(ocr.receivedLanguageSelections.first!, selection)
        XCTAssertEqual(appState.lastCopiedText, "```text\nkod satiri\n```")
    }

    @MainActor
    func testTableModeCopiesTabSeparatedText() async {
        let appState = AppState()
        appState.setCaptureMode(.table)

        let capture = MockScreenCaptureService()
        capture.result = .success(Self.makeImage())

        let ocr = MockOCRService()
        ocr.result = .success(OCRResult(
            blocks: [
                OCRTextBlock(text: "Urun", confidence: 0.95, boundingBox: CGRect(x: 0.10, y: 0.82, width: 0.16, height: 0.04)),
                OCRTextBlock(text: "Fiyat", confidence: 0.95, boundingBox: CGRect(x: 0.56, y: 0.82, width: 0.12, height: 0.04)),
                OCRTextBlock(text: "Elma", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.72, width: 0.14, height: 0.04)),
                OCRTextBlock(text: "12.99", confidence: 0.95, boundingBox: CGRect(x: 0.57, y: 0.72, width: 0.12, height: 0.04)),
                OCRTextBlock(text: "Armut", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.62, width: 0.16, height: 0.04)),
                OCRTextBlock(text: "9.50", confidence: 0.95, boundingBox: CGRect(x: 0.58, y: 0.62, width: 0.10, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        ))

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: ocr,
            clipboardService: MockClipboardService()
        )

        await coordinator.performCapturePipeline(
            screenRect: CGRect(x: 10, y: 10, width: 460, height: 260),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        XCTAssertEqual(ocr.receivedModes, [.table])
        XCTAssertEqual(capture.captureCallCount, 1)
        XCTAssertEqual(appState.lastCopiedText, "Urun\tFiyat\nElma\t12.99\nArmut\t9.50")
        XCTAssertEqual(appState.captureState, .completed)
        XCTAssertEqual(appState.lastCopiedEntry?.confidenceIndicator, .high)
    }

    @MainActor
    func testBarcodeFallbackCopiesPayloadWhenOCRTextMissing() async {
        let appState = AppState()
        appState.setCaptureMode(.standard)

        let capture = MockScreenCaptureService()
        capture.result = .success(Self.makeImage())

        let ocr = MockOCRService()
        ocr.result = .success(OCRResult(
            blocks: [],
            captureDate: Date(),
            sourceRect: .zero
        ))
        ocr.barcodeResult = .success(BarcodePayload(payload: "https://example.com/menu", symbology: "qr"))

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: ocr,
            clipboardService: MockClipboardService()
        )

        await coordinator.performCapturePipeline(
            screenRect: CGRect(x: 10, y: 10, width: 180, height: 180),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        XCTAssertEqual(appState.lastCopiedText, "https://example.com/menu")
        XCTAssertEqual(appState.captureState, .completed)
        XCTAssertTrue(appState.statusMessage.contains("QR"))
        XCTAssertEqual(ocr.detectBarcodeCallCount, 1)
    }

    @MainActor
    func testWatchSessionCopiesOnlyChangedText() async {
        let appState = AppState()
        appState.setCaptureMode(.subtitle)

        let capture = MockScreenCaptureService()
        capture.candidates = [
            CaptureCandidate(strategy: .screenshotKitGlobalRect, image: Self.makeImage(), debugInfo: "watch")
        ]

        let ocr = MockOCRService()
        ocr.resultQueue = [
            .success(OCRResult(
                blocks: [OCRTextBlock(text: "ilk satir", confidence: 0.94, boundingBox: .zero)],
                captureDate: Date(),
                sourceRect: .zero
            )),
            .success(OCRResult(
                blocks: [OCRTextBlock(text: "ilk satir", confidence: 0.94, boundingBox: .zero)],
                captureDate: Date(),
                sourceRect: .zero
            )),
            .success(OCRResult(
                blocks: [OCRTextBlock(text: "ikinci satir", confidence: 0.94, boundingBox: .zero)],
                captureDate: Date(),
                sourceRect: .zero
            ))
        ]
        ocr.result = .success(OCRResult(
            blocks: [OCRTextBlock(text: "ikinci satir", confidence: 0.94, boundingBox: .zero)],
            captureDate: Date(),
            sourceRect: .zero
        ))

        let clipboard = MockClipboardService()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: ocr,
            clipboardService: clipboard,
            watchIntervalNanoseconds: 1_000_000
        )

        await coordinator.startWatchSession(
            screenRect: CGRect(x: 10, y: 10, width: 500, height: 120),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        try? await Task.sleep(nanoseconds: 25_000_000)
        coordinator.stopWatching()

        XCTAssertEqual(appState.copyHistory.map(\.text).prefix(2), ["ikinci satir", "ilk satir"])
        XCTAssertEqual(clipboard.copiedTexts.prefix(2).map { $0 }, ["ilk satir", "ikinci satir"])
        XCTAssertEqual(appState.watchState, .inactive)
    }

    @MainActor
    func testWatchNewLinesOnlyCopiesOnlyDelta() async {
        let appState = AppState()
        appState.setWatchCopyBehavior(.newLinesOnly)

        let capture = MockScreenCaptureService()
        capture.candidates = [
            CaptureCandidate(strategy: .screenshotKitGlobalRect, image: Self.makeImage(), debugInfo: "watch")
        ]

        let ocr = MockOCRService()
        ocr.resultQueue = [
            .success(OCRResult(
                blocks: [OCRTextBlock(text: "satir 1", confidence: 0.94, boundingBox: .zero)],
                captureDate: Date(),
                sourceRect: .zero
            )),
            .success(OCRResult(
                blocks: [OCRTextBlock(text: "satir 1\nsatir 2", confidence: 0.94, boundingBox: .zero)],
                captureDate: Date(),
                sourceRect: .zero
            ))
        ]
        ocr.result = .success(OCRResult(
            blocks: [OCRTextBlock(text: "satir 1\nsatir 2", confidence: 0.94, boundingBox: .zero)],
            captureDate: Date(),
            sourceRect: .zero
        ))

        let clipboard = MockClipboardService()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: ocr,
            clipboardService: clipboard,
            watchIntervalNanoseconds: 1_000_000
        )

        await coordinator.startWatchSession(
            screenRect: CGRect(x: 10, y: 10, width: 500, height: 120),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        try? await Task.sleep(nanoseconds: 8_000_000)
        coordinator.stopWatching()

        XCTAssertEqual(Array(clipboard.copiedTexts.prefix(2)), ["satir 1", "satir 2"])
    }

    @MainActor
    func testWatchPermissionErrorRevalidatesBeforeStoppingWatch() async {
        let appState = AppState()
        let permission = MockPermissionService()
        permission.refreshState = .granted

        let capture = MockScreenCaptureService()
        capture.result = .failure(NSError(
            domain: "com.apple.ScreenCaptureKit.SCStreamErrorDomain",
            code: -3801,
            userInfo: [NSLocalizedDescriptionKey: "Not authorized"]
        ))

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: permission,
            screenCaptureService: capture,
            ocrService: MockOCRService(),
            clipboardService: MockClipboardService(),
            watchIntervalNanoseconds: 1_000_000
        )

        await coordinator.startWatchSession(
            screenRect: CGRect(x: 10, y: 10, width: 320, height: 120),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        await waitForWatchStateUpdate {
            permission.resolveCallCount > 0 || appState.watchState != .active
        }

        XCTAssertGreaterThan(permission.resolveCallCount, 0, "Watch permission errors should revalidate state before stopping")
        XCTAssertEqual(appState.permissionState, .granted)
        XCTAssertEqual(appState.watchState, .active, "Watch mode should continue when permission state is revalidated as granted")

        coordinator.stopWatching()
    }

    @MainActor
    func testWatchPermissionErrorStopsWhenRevalidationStillDenied() async {
        let appState = AppState()
        let permission = MockPermissionService()
        permission.refreshState = .denied

        let capture = MockScreenCaptureService()
        capture.result = .failure(NSError(
            domain: "com.apple.ScreenCaptureKit.SCStreamErrorDomain",
            code: -3801,
            userInfo: [NSLocalizedDescriptionKey: "Not authorized"]
        ))

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: permission,
            screenCaptureService: capture,
            ocrService: MockOCRService(),
            clipboardService: MockClipboardService(),
            watchIntervalNanoseconds: 1_000_000
        )

        await coordinator.startWatchSession(
            screenRect: CGRect(x: 10, y: 10, width: 320, height: 120),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        await waitForWatchStateUpdate {
            permission.resolveCallCount > 0 || appState.watchState == .inactive
        }

        XCTAssertGreaterThan(permission.resolveCallCount, 0)
        XCTAssertEqual(appState.permissionState, .denied)
        XCTAssertEqual(appState.watchState, .inactive)
    }

    @MainActor
    func testStopWatchingPreventsLateClipboardWrite() async {
        let appState = AppState()

        let capture = MockScreenCaptureService()
        capture.candidates = [
            CaptureCandidate(strategy: .screenshotKitGlobalRect, image: Self.makeImage(), debugInfo: "watch")
        ]

        let ocr = MockOCRService()
        ocr.recognitionDelayNanoseconds = 300_000_000
        ocr.result = .success(OCRResult(
            blocks: [OCRTextBlock(text: "gecikmeli", confidence: 0.94, boundingBox: .zero)],
            captureDate: Date(),
            sourceRect: .zero
        ))

        let clipboard = MockClipboardService()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: ocr,
            clipboardService: clipboard,
            watchIntervalNanoseconds: 50_000_000
        )

        await coordinator.startWatchSession(
            screenRect: CGRect(x: 10, y: 10, width: 500, height: 120),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        coordinator.stopWatching()
        try? await Task.sleep(nanoseconds: 450_000_000)

        XCTAssertEqual(appState.watchState, .inactive)
        XCTAssertTrue(clipboard.copiedTexts.isEmpty, "Stopped watch mode should not write a late OCR result to the clipboard")
    }

    @MainActor
    func testStartCaptureBlockedWhileWatchIsActive() async {
        let appState = AppState()
        appState.permissionState = .granted
        appState.updateWatchState(.active)

        let overlay = MockOverlay()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: MockScreenCaptureService(),
            ocrService: MockOCRService(),
            clipboardService: MockClipboardService(),
            overlayFactory: { _, _ in overlay }
        )

        coordinator.startCapture(trigger: .menu)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(overlay.showCount, 0)
        XCTAssertTrue(appState.statusMessage.contains("İzleme aktif"))
    }

    @MainActor
    func testStuckPipelineResetsAfter30Seconds() async {
        let appState = AppState()
        let permission = MockPermissionService()
        permission.refreshState = .granted
        var currentTime = Date(timeIntervalSince1970: 1_000)

        let overlay = MockOverlay()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: permission,
            screenCaptureService: MockScreenCaptureService(),
            ocrService: MockOCRService(),
            clipboardService: MockClipboardService(),
            overlayFactory: { _, _ in overlay },
            timeProvider: { currentTime }
        )

        coordinator.startCapture(trigger: .menu)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(overlay.showCount, 1)

        currentTime = currentTime.addingTimeInterval(31)
        appState.captureState = .capturing
        coordinator.startCapture(trigger: .hotkey)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(overlay.showCount, 2, "A stuck pipeline should be force-reset and allow a new overlay to open")
        XCTAssertEqual(appState.captureState, .selecting)
    }

    @MainActor
    func testHotkeyAndMenuTriggerIdenticalState() async {
        let appState1 = AppState()
        let permission1 = MockPermissionService()
        permission1.refreshState = .granted

        let overlay1 = MockOverlay()
        let coordinator1 = CaptureCoordinator(
            appState: appState1,
            permissionService: permission1,
            screenCaptureService: MockScreenCaptureService(),
            ocrService: MockOCRService(),
            clipboardService: MockClipboardService(),
            overlayFactory: { _, _ in overlay1 }
        )

        let appState2 = AppState()
        let permission2 = MockPermissionService()
        permission2.refreshState = .granted

        let overlay2 = MockOverlay()
        let coordinator2 = CaptureCoordinator(
            appState: appState2,
            permissionService: permission2,
            screenCaptureService: MockScreenCaptureService(),
            ocrService: MockOCRService(),
            clipboardService: MockClipboardService(),
            overlayFactory: { _, _ in overlay2 }
        )

        coordinator1.startCapture(trigger: .menu)
        coordinator2.startCapture(trigger: .hotkey)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(appState1.captureState, appState2.captureState, "Menu and hotkey triggers should produce identical state")
        XCTAssertEqual(appState1.permissionState, appState2.permissionState)
        XCTAssertEqual(overlay1.showCount, overlay2.showCount)
    }

    @MainActor
    func testPermissionResolveStateUsedInHandleFailure() async {
        let appState = AppState()
        let permission = MockPermissionService()
        permission.refreshState = .denied

        let capture = MockScreenCaptureService()
        capture.result = .failure(NSError(
            domain: "com.apple.ScreenCaptureKit.SCStreamErrorDomain",
            code: -3801,
            userInfo: [NSLocalizedDescriptionKey: "Not authorized"]
        ))

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: permission,
            screenCaptureService: capture,
            ocrService: MockOCRService(),
            clipboardService: MockClipboardService()
        )

        let resolveCountBefore = permission.resolveCallCount
        await coordinator.performCapturePipeline(
            screenRect: CGRect(x: 10, y: 10, width: 100, height: 40),
            preferredDisplay: nil,
            environment: Self.emptyEnvironment
        )

        // Allow the async Task in handleFailure to run
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertGreaterThan(permission.resolveCallCount, resolveCountBefore, "handleFailure should call resolveState() for permission errors")
        XCTAssertEqual(appState.captureState, .failed)
    }

    @MainActor
    func testSuccessfulCopyRecordsHistoryAndNotificationTarget() async {
        let appState = AppState()

        let capture = MockScreenCaptureService()
        capture.result = .success(Self.makeImage())

        let ocr = MockOCRService()
        ocr.result = .success(OCRResult(
            blocks: [OCRTextBlock(text: "Ilk metin", confidence: 0.98, boundingBox: .zero)],
            captureDate: Date(),
            sourceRect: .zero
        ))

        let clipboard = MockClipboardService()
        let display = ScreenDescriptor(displayID: 99, frame: CGRect(x: 100, y: 100, width: 1440, height: 900), backingScaleFactor: 2)
        let environment = ScreenEnvironmentSnapshot(displays: [display])

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: capture,
            ocrService: ocr,
            clipboardService: clipboard
        )

        await coordinator.performCapturePipeline(
            screenRect: CGRect(x: 10, y: 10, width: 100, height: 40),
            preferredDisplay: display,
            environment: environment
        )

        XCTAssertEqual(appState.copyHistory.map(\.text), ["Ilk metin"])
        XCTAssertEqual(clipboard.notificationDisplayFrame, display.frame)
    }

    @MainActor
    func testCopyTextMovesExistingHistoryEntryToFront() {
        let appState = AppState()
        appState.recordCopiedText("eski")
        appState.recordCopiedText("yeni")

        let clipboard = MockClipboardService()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: MockScreenCaptureService(),
            ocrService: MockOCRService(),
            clipboardService: clipboard
        )

        XCTAssertEqual(coordinator.copyText("eski"), .success)
        XCTAssertEqual(appState.copyHistory.map(\.text), ["eski", "yeni"])
    }

    @MainActor
    func testClipboardImageCaptureRecognizesTextWithoutScreenPermission() async {
        let appState = AppState()
        let permission = MockPermissionService()
        permission.refreshState = .denied

        let ocr = MockOCRService()
        ocr.result = .success(
            OCRResult(
                blocks: [OCRTextBlock(text: "Panodan OCR", confidence: 0.96, boundingBox: .zero)],
                captureDate: Date(),
                sourceRect: .zero
            )
        )

        let clipboard = MockClipboardService()
        clipboard.clipboardImage = Self.makeImage()

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: permission,
            screenCaptureService: MockScreenCaptureService(),
            ocrService: ocr,
            clipboardService: clipboard
        )

        coordinator.captureClipboardImage(sessionOverrides: nil)
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(permission.resolveCallCount, 0)
        XCTAssertEqual(appState.captureState, .completed)
        XCTAssertEqual(appState.lastCopiedText, "Panodan OCR")
        XCTAssertEqual(clipboard.copiedTexts.last, "Panodan OCR")
    }

    @MainActor
    func testClipboardImageCaptureFailsWhenClipboardHasNoImage() {
        let appState = AppState()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: MockScreenCaptureService(),
            ocrService: MockOCRService(),
            clipboardService: MockClipboardService()
        )

        coordinator.captureClipboardImage(sessionOverrides: nil)

        XCTAssertEqual(appState.captureState, .failed)
        XCTAssertTrue(appState.statusMessage.contains("Panoda okunabilir bir görsel yok"))
    }

    @MainActor
    func testImageFileCaptureRecognizesTextFromSelectedFile() async {
        let appState = AppState()

        let ocr = MockOCRService()
        ocr.result = .success(
            OCRResult(
                blocks: [OCRTextBlock(text: "Dosyadan OCR", confidence: 0.94, boundingBox: .zero)],
                captureDate: Date(),
                sourceRect: .zero
            )
        )

        let clipboard = MockClipboardService()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: MockScreenCaptureService(),
            ocrService: ocr,
            clipboardService: clipboard
        )

        let url = Self.makeTempPNGFile()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.captureImageFile(at: url, sessionOverrides: nil)
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(appState.captureState, .completed)
        XCTAssertEqual(appState.lastCopiedText, "Dosyadan OCR")
        XCTAssertEqual(clipboard.copiedTexts.last, "Dosyadan OCR")
    }

    @MainActor
    func testPDFFileCaptureRecognizesTextFromSelectedPDF() async {
        let appState = AppState()

        let ocr = MockOCRService()
        ocr.result = .success(
            OCRResult(
                blocks: [OCRTextBlock(text: "PDF OCR sonucu", confidence: 0.93, boundingBox: CGRect(x: 0.12, y: 0.44, width: 0.36, height: 0.05))],
                captureDate: Date(),
                sourceRect: CGRect(x: 0, y: 0, width: 612, height: 792)
            )
        )

        let clipboard = MockClipboardService()
        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: MockScreenCaptureService(),
            ocrService: ocr,
            clipboardService: clipboard
        )

        let url = Self.makeTempPDFFile()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.capturePDFFile(at: url, sessionOverrides: nil)
        try? await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(appState.captureState, .completed)
        XCTAssertEqual(appState.lastCopiedText, "PDF OCR sonucu")
        XCTAssertEqual(clipboard.copiedTexts.last, "PDF OCR sonucu")
    }

    @MainActor
    func testSearchablePDFExportEmbedsRecognizedText() async throws {
        let appState = AppState()

        let ocr = MockOCRService()
        ocr.result = .success(
            OCRResult(
                blocks: [OCRTextBlock(text: "Aranabilir PDF", confidence: 0.96, boundingBox: CGRect(x: 0.15, y: 0.42, width: 0.28, height: 0.05))],
                captureDate: Date(),
                sourceRect: CGRect(x: 0, y: 0, width: 612, height: 792)
            )
        )

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: MockPermissionService(),
            screenCaptureService: MockScreenCaptureService(),
            ocrService: ocr,
            clipboardService: MockClipboardService()
        )

        let sourceURL = Self.makeTempPDFFile()
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: destinationURL)
        }

        coordinator.exportSearchablePDF(at: sourceURL, destinationURL: destinationURL, sessionOverrides: nil)
        try? await Task.sleep(nanoseconds: 180_000_000)

        XCTAssertEqual(appState.captureState, .completed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertTrue(PDFDocument(url: destinationURL)?.string?.contains("Aranabilir PDF") == true)
    }

    private static func makeImage() -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let width = 2
        let height = 2
        let bitsPerComponent = 8
        let bytesPerRow = width * bytesPerPixel
        let data = [UInt8](repeating: 255, count: width * height * bytesPerPixel)

        let provider = CGDataProvider(data: Data(data) as CFData)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerComponent * bytesPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }

    private static func makeTempPNGFile() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            XCTFail("Could not create image destination")
            return url
        }

        CGImageDestinationAddImage(destination, makeImage(), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    private static func makeTempPDFFile() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            XCTFail("Could not create PDF context")
            return url
        }

        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(mediaBox)

        let text = NSAttributedString(
            string: "Sample PDF",
            attributes: [
                .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
                .foregroundColor: NSColor.black
            ]
        )
        let line = CTLineCreateWithAttributedString(text as CFAttributedString)
        context.textPosition = CGPoint(x: 72, y: 640)
        CTLineDraw(line, context)
        context.endPDFPage()
        context.closePDF()

        return url
    }

    private static let emptyEnvironment = ScreenEnvironmentSnapshot(displays: [])

    @MainActor
    private func waitForWatchStateUpdate(
        timeoutNanoseconds: UInt64 = 250_000_000,
        pollIntervalNanoseconds: UInt64 = 5_000_000,
        until condition: @escaping () -> Bool
    ) async {
        var elapsedNanoseconds: UInt64 = 0
        while !condition() {
            if elapsedNanoseconds >= timeoutNanoseconds {
                break
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            elapsedNanoseconds += pollIntervalNanoseconds
        }
    }
}

@MainActor
private final class MockPermissionService: ScreenPermissionProviding {
    var needsRestartAfterGrant: Bool = false
    var refreshState: ScreenPermissionState = .granted
    var requestState: ScreenPermissionState = .granted
    private(set) var resolveCallCount: Int = 0

    func refreshPreflight() -> ScreenPermissionState {
        refreshState
    }

    func resolveState() async -> ScreenPermissionState {
        resolveCallCount += 1
        return refreshState
    }

    func requestIfNeeded() async -> ScreenPermissionState {
        requestState
    }

    func diagnosticSnapshot() async -> PermissionDiagnosticSnapshot {
        PermissionDiagnosticSnapshot(
            timestamp: Date(timeIntervalSince1970: 1_000),
            currentState: refreshState,
            preflightGranted: refreshState == .granted,
            probeState: refreshState,
            needsRestartAfterGrant: needsRestartAfterGrant,
            lastConfirmedGrantAt: nil,
            lastProbeAt: nil,
            bundleIdentifier: "test.bundle",
            appPath: "/Applications/ScreenTextGrab.app",
            marketingVersion: "1.0",
            buildVersion: "1"
        )
    }

    func openSystemSettings() {}
}

private final class MockScreenCaptureService: ScreenCaptureProviding, @unchecked Sendable {
    var result: Result<CGImage, Error> = .failure(CapturePipelineError.captureFailed(domain: "test", code: -1, description: "not configured"))
    var candidates: [CaptureCandidate]?
    var candidateBatches: [[CaptureCandidate]] = []
    private(set) var captureCallCount: Int = 0
    private(set) var requestedRects: [CGRect] = []

    func captureCandidates(request: CaptureRequest) async throws -> [CaptureCandidate] {
        captureCallCount += 1
        requestedRects.append(request.selectionRect)

        if !candidateBatches.isEmpty {
            return candidateBatches.removeFirst()
        }

        if let candidates {
            return candidates
        }
        let image = try result.get()
        return [
            CaptureCandidate(
                strategy: .displayCropTopLeft,
                image: image,
                debugInfo: "mock"
            )
        ]
    }
}

private final class MockOCRService: OCRProviding, @unchecked Sendable {
    var result: Result<OCRResult, Error> = .failure(CapturePipelineError.ocrFailed(description: "not configured"))
    var resultQueue: [Result<OCRResult, Error>] = []
    var barcodeResult: Result<BarcodePayload?, Error> = .success(nil)
    var recognitionDelayNanoseconds: UInt64 = 0
    private(set) var receivedModes: [CaptureMode] = []
    private(set) var receivedLanguageSelections: [OCRLanguageSelection?] = []
    private(set) var detectBarcodeCallCount: Int = 0

    func recognizeText(
        in image: CGImage,
        sourceRect: CGRect,
        preferredRegions: [CGRect],
        captureMode: CaptureMode,
        languageSelection: OCRLanguageSelection?
    ) async throws -> OCRResult {
        receivedModes.append(captureMode)
        receivedLanguageSelections.append(languageSelection)
        if recognitionDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: recognitionDelayNanoseconds)
        }
        if !resultQueue.isEmpty {
            return try resultQueue.removeFirst().get()
        }
        return try result.get()
    }

    func detectBarcode(in image: CGImage) async throws -> BarcodePayload? {
        detectBarcodeCallCount += 1
        return try barcodeResult.get()
    }
}

private final class MockClipboardService: ClipboardProviding {
    var result: ClipboardWriteResult = .success
    var clipboardImage: CGImage?
    private(set) var notificationDisplayFrame: CGRect?
    private(set) var copiedTexts: [String] = []
    private(set) var copiedPayloads: [ClipboardPayload] = []

    func copyToClipboard(_ payload: ClipboardPayload) -> ClipboardWriteResult {
        copiedPayloads.append(payload)
        copiedTexts.append(payload.string)
        return result
    }

    func readFromClipboard() -> String? {
        nil
    }

    func readImageFromClipboard() -> CGImage? {
        clipboardImage
    }

    func showCopyNotification(text: String, on displayFrame: CGRect?) {
        notificationDisplayFrame = displayFrame
    }
}

private final class MockOverlay: SelectionOverlayPresenting {
    private(set) var showCount: Int = 0

    func showOverlay() {
        showCount += 1
    }

    func closeOverlay() {}
}
