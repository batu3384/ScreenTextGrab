import AppKit
import ImageIO
import PDFKit
import Vision

private enum CaptureEpoch {
    @TaskLocal static var value: Int?
}

enum CaptureTrigger: String, Sendable {
    case hotkey
    case menu
    case retry
    case automation
    case clipboard
}

@MainActor
protocol CaptureCoordinating: AnyObject {
    func startCapture(trigger: CaptureTrigger)
    func startCapture(trigger: CaptureTrigger, sessionOverrides: AutomationCaptureOverrides?)
    func repeatLastCapture(sessionOverrides: AutomationCaptureOverrides?)
    func captureSavedRegion(_ region: SavedCaptureRegion, sessionOverrides: AutomationCaptureOverrides?)
    func captureSavedRegion(named name: String, sessionOverrides: AutomationCaptureOverrides?)
    func copySavedSnippet(_ snippet: SavedSnippet) -> ClipboardWriteResult
    func copySavedSnippet(named name: String) -> ClipboardWriteResult
    func captureClipboardImage(sessionOverrides: AutomationCaptureOverrides?)
    func captureImageFile(at url: URL, sessionOverrides: AutomationCaptureOverrides?)
    func capturePDFFile(at url: URL, sessionOverrides: AutomationCaptureOverrides?)
    func exportSearchablePDF(at url: URL, destinationURL: URL?, sessionOverrides: AutomationCaptureOverrides?)
    func startWatching()
    func stopWatching()
    func cancelCapture()
    func requestPermission()
    func refreshPermission()
    func openSystemSettings()
    func retryAfterPermission()
    func copyText(_ text: String) -> ClipboardWriteResult
    func copyCapturedText(
        rawText: String,
        captureMode: CaptureMode,
        contentKind: ClipboardHistoryEntry.ContentKind,
        source: ClipboardHistoryEntry.SourceContext?,
        outputPreset: CaptureOutputPreset,
        targetBundleIdentifier: String?
    ) -> ClipboardWriteResult
}

extension CaptureCoordinating {
    func copyCapturedText(
        rawText: String,
        captureMode: CaptureMode,
        contentKind: ClipboardHistoryEntry.ContentKind,
        source: ClipboardHistoryEntry.SourceContext?,
        outputPreset: CaptureOutputPreset
    ) -> ClipboardWriteResult {
        copyCapturedText(
            rawText: rawText,
            captureMode: captureMode,
            contentKind: contentKind,
            source: source,
            outputPreset: outputPreset,
            targetBundleIdentifier: nil
        )
    }
}

@MainActor
final class CaptureCoordinator: CaptureCoordinating {
    typealias OverlayFactory = (
        _ onSelectionComplete: @escaping (CGRect, NSScreen) -> Void,
        _ onCancel: @escaping () -> Void
    ) -> SelectionOverlayPresenting

    private let appState: AppState
    private let permissionService: ScreenPermissionProviding
    private let screenCaptureService: any ScreenCaptureProviding
    private let ocrService: any OCRProviding
    private let clipboardService: ClipboardProviding
    private let overlayFactory: OverlayFactory
    private let timeProvider: () -> Date
    private let watchIntervalNanoseconds: UInt64
    private let outputWriter: CaptureOutputWriter

    private var activeOverlay: SelectionOverlayPresenting?
    private var lastCaptureStart: Date?
    private var captureTask: Task<Void, Never>?
    private var captureEpoch = 0
    private var watchTask: Task<Void, Never>?
    private var watchPermissionTask: Task<Void, Never>?
    private var watchPermissionGeneration = 0
    private var currentWatchSession: CaptureWatchSession?

    init(
        appState: AppState,
        permissionService: ScreenPermissionProviding,
        screenCaptureService: any ScreenCaptureProviding,
        ocrService: any OCRProviding,
        clipboardService: ClipboardProviding,
        overlayFactory: @escaping OverlayFactory = { onSelection, onCancel in
            SelectionOverlayWindow(onSelectionComplete: onSelection, onCancel: onCancel)
        },
        timeProvider: @escaping () -> Date = { Date() },
        watchIntervalNanoseconds: UInt64 = 900_000_000
    ) {
        self.appState = appState
        self.permissionService = permissionService
        self.screenCaptureService = screenCaptureService
        self.ocrService = ocrService
        self.clipboardService = clipboardService
        self.overlayFactory = overlayFactory
        self.timeProvider = timeProvider
        self.watchIntervalNanoseconds = watchIntervalNanoseconds
        self.outputWriter = CaptureOutputWriter(appState: appState, clipboardService: clipboardService)
    }

    /// Returns false when a capture is still inside the stuck window and the caller should bail.
    private func reclaimStuckCaptureIfNeeded() -> Bool {
        guard appState.captureState.isBusy else { return true }
        guard let start = lastCaptureStart,
              timeProvider().timeIntervalSince(start) > 30 else {
            return false
        }

        STGLog.pipeline.error("Pipeline stuck for 30+ seconds — force resetting state")
        abandonInFlightCapture()
        appState.captureState = .idle
        return true
    }

    private func abandonInFlightCapture() {
        captureEpoch += 1
        captureTask?.cancel()
        captureTask = nil
        activeOverlay?.closeOverlay()
        activeOverlay = nil
        lastCaptureStart = nil
    }

    private func runCapture(_ work: @escaping @MainActor () async -> Void) {
        captureEpoch += 1
        let epoch = captureEpoch
        captureTask?.cancel()
        captureTask = Task { @MainActor in
            await CaptureEpoch.$value.withValue(epoch) {
                await work()
            }
        }
    }

    private func captureWorkIsCurrent() -> Bool {
        guard let epoch = CaptureEpoch.value else { return !Task.isCancelled }
        return epoch == captureEpoch && !Task.isCancelled
    }

    private func clearCaptureClockIfCurrent() {
        guard captureWorkIsCurrent() else { return }
        lastCaptureStart = nil
    }

    private func applyResolvedPermission(
        _ permissionState: ScreenPermissionState,
        onGranted: () async -> Void
    ) async {
        guard captureWorkIsCurrent() else { return }
        appState.permissionState = permissionState

        switch permissionState {
        case .granted:
            await onGranted()
        case .requiresRestart:
            clearCaptureClockIfCurrent()
            appState.captureState = .failed
            appState.statusMessage = L10n.permissionRestartCapture
        case .denied:
            clearCaptureClockIfCurrent()
            appState.captureState = .failed
            appState.statusMessage = L10n.permissionDeniedRefresh
        case .unknown:
            clearCaptureClockIfCurrent()
            appState.captureState = .failed
            appState.statusMessage = L10n.permissionUnknown
        case .requestInProgress:
            clearCaptureClockIfCurrent()
            appState.captureState = .idle
            appState.statusMessage = L10n.permissionRequestInProgress
        }
    }

    func startCapture(trigger: CaptureTrigger) {
        startCapture(trigger: trigger, sessionOverrides: nil)
    }

    func startCapture(trigger: CaptureTrigger, sessionOverrides: AutomationCaptureOverrides?) {
        let sourceContext = Self.captureHistorySourceContext()
        let sessionConfiguration = resolvedSessionConfiguration(for: sourceContext, overrides: sessionOverrides)
        guard appState.watchState != .active && appState.watchState != .selecting else {
            appState.statusMessage = L10n.captureBlockedByWatch
            return
        }

        guard reclaimStuckCaptureIfNeeded() else { return }

        lastCaptureStart = timeProvider()
        appState.lastError = nil
        appState.captureState = .preparing
        appState.statusMessage = L10n.capturePreparing
        STGLog.pipeline.info("Pipeline started; trigger=\(trigger.rawValue, privacy: .public)")

        runCapture {
            let permissionState = await self.permissionService.resolveState()
            await self.applyResolvedPermission(permissionState) {
                self.presentOverlay(trigger: trigger, source: sourceContext, sessionConfiguration: sessionConfiguration)
            }
        }
    }

    func repeatLastCapture(sessionOverrides: AutomationCaptureOverrides? = nil) {
        guard appState.watchState != .active && appState.watchState != .selecting else {
            appState.statusMessage = L10n.repeatBlockedByWatch
            return
        }

        guard let lastSelection = appState.lastCaptureSelection else {
            appState.statusMessage = L10n.repeatNeedsSelection
            return
        }

        performSelectionCapture(
            lastSelection,
            sessionOverrides: sessionOverrides,
            preparingMessage: "Son alan yeniden hazırlanıyor...",
            logMessage: "Repeat capture requested"
        )
    }

    func captureSavedRegion(_ region: SavedCaptureRegion, sessionOverrides: AutomationCaptureOverrides? = nil) {
        guard appState.watchState != .active && appState.watchState != .selecting else {
            appState.statusMessage = L10n.savedRegionBlockedByWatch
            return
        }

        performSelectionCapture(
            region.recentSelection,
            sessionOverrides: sessionOverrides,
            preparingMessage: "\(region.name) hazırlanıyor...",
            logMessage: "Saved region capture requested name=\(region.name)"
        )
    }

    func captureSavedRegion(named name: String, sessionOverrides: AutomationCaptureOverrides? = nil) {
        guard let region = appState.savedCaptureRegion(named: name) else {
            appState.statusMessage = L10n.savedRegionMissing(name)
            return
        }

        captureSavedRegion(region, sessionOverrides: sessionOverrides)
    }

    func copySavedSnippet(_ snippet: SavedSnippet) -> ClipboardWriteResult {
        let targetBundleIdentifier = appState.activeTargetBundleIdentifier
        let targetProfile = appState.appProfile(for: targetBundleIdentifier)
        let effectiveOutputPreset = appState.preferredRepasteOutputPreset(defaultingTo: snippet.outputPreset)
        let result = copyCapturedText(
            rawText: snippet.effectiveRawText,
            captureMode: snippet.captureMode,
            contentKind: snippet.contentKind,
            source: snippet.source,
            outputPreset: effectiveOutputPreset,
            targetBundleIdentifier: targetBundleIdentifier
        )

        if result == .success {
            _ = appState.noteSavedSnippetUsed(snippet)
            if let targetProfile,
               effectiveOutputPreset != snippet.outputPreset {
                appState.statusMessage = L10n.profileOutputCopied(appName: targetProfile.appName, preset: effectiveOutputPreset.title)
            }
        }

        return result
    }

    func copySavedSnippet(named name: String) -> ClipboardWriteResult {
        guard let snippet = appState.savedSnippet(named: name) else {
            appState.statusMessage = L10n.savedSnippetMissing(name)
            return .failedWrite
        }

        return copySavedSnippet(snippet)
    }

    func captureClipboardImage(sessionOverrides: AutomationCaptureOverrides? = nil) {
        guard appState.watchState != .active && appState.watchState != .selecting else {
            appState.statusMessage = L10n.clipboardImageBlockedByWatch
            return
        }

        guard reclaimStuckCaptureIfNeeded() else { return }

        guard let image = clipboardService.readImageFromClipboard() else {
            let error = CapturePipelineError.captureFailed(
                domain: "Clipboard",
                code: -2,
                description: L10n.clipboardImageMissing
            )
            appState.lastError = error
            appState.captureState = .failed
            appState.statusMessage = error.errorDescription ?? L10n.clipboardImageMissingStatus
            return
        }

        let sourceContext = Self.captureHistorySourceContext() ?? appState.activeSourceApp
        let sessionConfiguration = resolvedSessionConfiguration(for: sourceContext, overrides: sessionOverrides)
        lastCaptureStart = timeProvider()
        appState.lastError = nil
        appState.captureState = .preparing
        appState.statusMessage = L10n.clipboardImagePreparing
        STGLog.pipeline.info("Clipboard OCR started")

        runCapture {
            await self.performClipboardImagePipeline(
                image: image,
                source: sourceContext,
                sessionConfiguration: sessionConfiguration
            )
        }
    }

    private func performSelectionCapture(
        _ selection: RecentCaptureSelection,
        sessionOverrides: AutomationCaptureOverrides?,
        preparingMessage: String,
        logMessage: String
    ) {
        guard reclaimStuckCaptureIfNeeded() else { return }

        let sessionConfiguration = (sessionOverrides ?? AutomationCaptureOverrides()).applying(to: selection.sessionConfiguration)

        lastCaptureStart = timeProvider()
        appState.lastError = nil
        appState.captureState = .preparing
        appState.statusMessage = preparingMessage
        STGLog.pipeline.info("\(logMessage)")

        runCapture {
            let permissionState = await self.permissionService.resolveState()
            await self.applyResolvedPermission(permissionState) {
                let environment = ScreenEnvironmentSnapshot.capture()
                let preferredDisplay = environment.bestDisplay(
                    for: selection.screenRect,
                    preferredDisplayID: selection.preferredDisplayID
                )
                await self.performCapturePipeline(
                    screenRect: selection.screenRect,
                    preferredDisplay: preferredDisplay,
                    environment: environment,
                    source: selection.source,
                    sessionConfiguration: sessionConfiguration
                )
            }
        }
    }

    func captureImageFile(at url: URL, sessionOverrides: AutomationCaptureOverrides? = nil) {
        guard appState.watchState != .active && appState.watchState != .selecting else {
            appState.statusMessage = L10n.imageFileBlockedByWatch
            return
        }

        guard reclaimStuckCaptureIfNeeded() else { return }

        let standardizedURL = url.standardizedFileURL
        guard standardizedURL.isFileURL else {
            let error = CapturePipelineError.captureFailed(
                domain: "FileImport",
                code: -10,
                description: L10n.localImageOnly
            )
            appState.lastError = error
            appState.captureState = .failed
            appState.statusMessage = error.errorDescription ?? L10n.unsupportedPath
            return
        }

        let sessionConfiguration = (sessionOverrides ?? AutomationCaptureOverrides()).applying(
            to: CaptureSessionConfiguration(
                captureMode: appState.captureMode,
                outputPreset: appState.captureOutputPreset,
                ocrLanguageSelection: appState.ocrLanguageSelection,
                profileName: nil
            )
        )

        lastCaptureStart = timeProvider()
        appState.lastError = nil
        appState.captureState = .preparing
        appState.statusMessage = L10n.imageFilePreparing
        STGLog.pipeline.info("Image file OCR started")

        runCapture {
            do {
                let image = try Self.loadImageFile(at: standardizedURL)
                await self.performImageFilePipeline(
                    image: image,
                    fileURL: standardizedURL,
                    sessionConfiguration: sessionConfiguration
                )
            } catch {
                self.clearCaptureClockIfCurrent()
                self.handleFailure(Self.mapToPipelineError(error))
            }
        }
    }

    func capturePDFFile(at url: URL, sessionOverrides: AutomationCaptureOverrides? = nil) {
        guard appState.watchState != .active && appState.watchState != .selecting else {
            appState.statusMessage = L10n.pdfBlockedByWatch
            return
        }

        guard reclaimStuckCaptureIfNeeded() else { return }

        let standardizedURL = url.standardizedFileURL
        guard standardizedURL.isFileURL else {
            let error = CapturePipelineError.captureFailed(
                domain: "PDFImport",
                code: -20,
                description: L10n.localPDFOnly
            )
            appState.lastError = error
            appState.captureState = .failed
            appState.statusMessage = error.errorDescription ?? L10n.unsupportedPath
            return
        }

        let sessionConfiguration = (sessionOverrides ?? AutomationCaptureOverrides()).applying(
            to: CaptureSessionConfiguration(
                captureMode: appState.captureMode,
                outputPreset: appState.captureOutputPreset,
                ocrLanguageSelection: appState.ocrLanguageSelection,
                profileName: nil
            )
        )

        lastCaptureStart = timeProvider()
        appState.lastError = nil
        appState.captureState = .preparing
        appState.statusMessage = L10n.pdfPreparing
        STGLog.pipeline.info("PDF OCR started")

        runCapture {
            do {
                let pages = try PDFProcessingService.renderPages(from: standardizedURL)
                await self.performPDFFilePipeline(
                    pages: pages,
                    fileURL: standardizedURL,
                    sessionConfiguration: sessionConfiguration
                )
            } catch {
                self.clearCaptureClockIfCurrent()
                self.handleFailure(Self.mapToPipelineError(error))
            }
        }
    }

    func exportSearchablePDF(
        at url: URL,
        destinationURL: URL?,
        sessionOverrides: AutomationCaptureOverrides? = nil
    ) {
        guard appState.watchState != .active && appState.watchState != .selecting else {
            appState.statusMessage = L10n.searchablePDFBlockedByWatch
            return
        }

        guard reclaimStuckCaptureIfNeeded() else { return }

        let standardizedURL = url.standardizedFileURL
        guard standardizedURL.isFileURL else {
            let error = CapturePipelineError.captureFailed(
                domain: "PDFExport",
                code: -21,
                description: L10n.localPDFOnly
            )
            appState.lastError = error
            appState.captureState = .failed
            appState.statusMessage = error.errorDescription ?? L10n.unsupportedPath
            return
        }

        let resolvedDestination = (destinationURL ?? PDFProcessingService.suggestedSearchableOutputURL(for: standardizedURL))
            .standardizedFileURL
        let sessionConfiguration = (sessionOverrides ?? AutomationCaptureOverrides()).applying(
            to: CaptureSessionConfiguration(
                captureMode: appState.captureMode,
                outputPreset: appState.captureOutputPreset,
                ocrLanguageSelection: appState.ocrLanguageSelection,
                profileName: nil
            )
        )

        lastCaptureStart = timeProvider()
        appState.lastError = nil
        appState.captureState = .preparing
        appState.statusMessage = L10n.searchablePDFPreparing
        STGLog.pipeline.info("Searchable PDF export started")

        runCapture {
            do {
                let pages = try PDFProcessingService.renderPages(from: standardizedURL)
                await self.performSearchablePDFExportPipeline(
                    pages: pages,
                    fileURL: standardizedURL,
                    destinationURL: resolvedDestination,
                    sessionConfiguration: sessionConfiguration
                )
            } catch {
                self.clearCaptureClockIfCurrent()
                self.handleFailure(Self.mapToPipelineError(error))
            }
        }
    }

    func startWatching() {
        let sourceContext = Self.captureHistorySourceContext()
        let sessionConfiguration = resolvedSessionConfiguration(for: sourceContext)
        guard appState.captureState.isBusy == false else { return }

        if appState.watchState == .active || appState.watchState == .selecting {
            stopWatching()
            return
        }

        appState.statusMessage = L10n.watchPreparing
        appState.updateWatchState(.selecting)
        watchPermissionGeneration += 1
        let generation = watchPermissionGeneration
        watchPermissionTask?.cancel()
        watchPermissionTask = Task { @MainActor in
            let permissionState = await permissionService.resolveState()
            guard generation == self.watchPermissionGeneration else { return }
            guard self.appState.watchState == .selecting else { return }
            self.appState.permissionState = permissionState

            switch permissionState {
            case .granted:
                self.presentWatchOverlay(source: sourceContext, sessionConfiguration: sessionConfiguration)
            case .requiresRestart:
                self.appState.updateWatchState(.inactive)
                self.appState.statusMessage = L10n.watchPermissionRestart
            case .denied:
                self.appState.updateWatchState(.inactive)
                self.appState.statusMessage = L10n.watchPermissionDenied
            case .unknown:
                self.appState.updateWatchState(.inactive)
                self.appState.statusMessage = L10n.watchPermissionUnknown
            case .requestInProgress:
                self.appState.updateWatchState(.inactive)
                self.appState.statusMessage = L10n.watchPermissionInProgress
            }
        }
    }

    func stopWatching() {
        watchPermissionGeneration += 1
        watchPermissionTask?.cancel()
        watchPermissionTask = nil
        activeOverlay?.closeOverlay()
        activeOverlay = nil
        watchTask?.cancel()
        watchTask = nil
        currentWatchSession = nil

        if appState.watchState != .inactive {
            appState.updateWatchState(.inactive)
            if appState.permissionState == .granted, !appState.captureState.isBusy {
                appState.statusMessage = appState.readyStatusMessage
            } else if !appState.captureState.isBusy {
                appState.statusMessage = L10n.watchStopped
            }
        }
    }

    func cancelCapture() {
        abandonInFlightCapture()
        appState.captureState = .cancelled
        appState.statusMessage = L10n.captureCancelled
    }

    func requestPermission() {
        Task { @MainActor in
            appState.permissionState = .requestInProgress
            appState.statusMessage = L10n.permissionRequesting
            let state = await permissionService.requestIfNeeded()
            applyPermissionState(state)
            if state == .granted {
                retryAfterPermission()
            }
        }
    }

    func refreshPermission() {
        Task { @MainActor in
            let state = await permissionService.resolveState()
            applyPermissionState(state)
        }
    }

    func syncPermissionState(_ state: ScreenPermissionState) {
        applyPermissionState(state)
    }

    func openSystemSettings() {
        permissionService.openSystemSettings()
    }

    func retryAfterPermission() {
        startCapture(trigger: .retry)
    }

    func copyText(_ text: String) -> ClipboardWriteResult {
        outputWriter.copyText(text, captureMode: appState.captureMode)
    }

    func copyCapturedText(
        rawText: String,
        captureMode: CaptureMode,
        contentKind: ClipboardHistoryEntry.ContentKind,
        source: ClipboardHistoryEntry.SourceContext?,
        outputPreset: CaptureOutputPreset,
        targetBundleIdentifier: String? = nil
    ) -> ClipboardWriteResult {
        outputWriter.copyCapturedText(
            rawText: rawText,
            captureMode: captureMode,
            contentKind: contentKind,
            source: source,
            outputPreset: outputPreset,
            targetBundleIdentifier: targetBundleIdentifier
        )
    }

    func performCapturePipeline(
        screenRect: CGRect,
        preferredDisplay: ScreenDescriptor?,
        environment: ScreenEnvironmentSnapshot,
        source: ClipboardHistoryEntry.SourceContext? = nil,
        sessionConfiguration: CaptureSessionConfiguration? = nil
    ) async {
        let primaryCaptureRect = screenRect.standardized
        let resolvedConfiguration = sessionConfiguration ?? resolvedSessionConfiguration(for: source)
        let captureMode = resolvedConfiguration.captureMode
        let outputPreset = resolvedConfiguration.outputPreset
        let ocrLanguageSelection = resolvedConfiguration.ocrLanguageSelection
        appState.rememberCaptureSelection(
            RecentCaptureSelection(
                screenRect: screenRect.standardized,
                preferredDisplayID: preferredDisplay?.displayID,
                source: source,
                sessionConfiguration: resolvedConfiguration
            )
        )
        let baseRequest = CaptureRequest(
            selectionRect: primaryCaptureRect,
            preferredDisplay: preferredDisplay,
            environment: environment
        )

        do {
            var evaluation = try await performAttempt(
                request: baseRequest,
                captureRect: primaryCaptureRect,
                sourceRect: screenRect,
                captureMode: captureMode,
                languageSelection: ocrLanguageSelection,
                attemptLabel: "initial",
                attemptIndex: 1,
                totalAttempts: 1
            )

            var bestSelection = evaluation.best
            var hadSuccessfulOCRPass = evaluation.hadSuccessfulOCRPass
            var lastOCRError = evaluation.lastOCRError
            var attemptSummaries = [evaluation.summary]
            var textFrequency: [String: Int] = [:]

            if let bestSelection {
                let normalized = CaptureRecognitionHeuristics.normalizedRecognizedText(bestSelection.text)
                textFrequency[normalized] = 1
            }

            if CaptureRecognitionHeuristics.shouldRetryTextRecognition(
                for: screenRect,
                currentBest: bestSelection,
                captureMode: captureMode
            ) {
                let retryAttempts = CaptureRecognitionHeuristics.buildRetryAttempts(
                    selectionRect: screenRect,
                    primaryCaptureRect: primaryCaptureRect,
                    captureMode: captureMode,
                    preferredDisplay: preferredDisplay,
                    environment: environment
                )

                if !retryAttempts.isEmpty {
                    STGLog.pipeline.info("Video text retry enabled attempts=\(retryAttempts.count + 1)")
                }

                for (retryIndex, retryAttempt) in retryAttempts.enumerated() {
                    guard captureWorkIsCurrent() else { return }
                    appState.statusMessage = L10n.retryProgress(captureMode.retryProgressTitle, index: retryIndex + 2, total: retryAttempts.count + 1)
                    do {
                        try await Task.sleep(nanoseconds: retryAttempt.delayNanoseconds)
                    } catch {
                        return
                    }
                    guard captureWorkIsCurrent() else { return }

                    evaluation = try await performAttempt(
                        request: baseRequest,
                        captureRect: retryAttempt.captureRect,
                        sourceRect: screenRect,
                        captureMode: captureMode,
                        languageSelection: ocrLanguageSelection,
                        attemptLabel: retryAttempt.label,
                        attemptIndex: retryIndex + 2,
                        totalAttempts: retryAttempts.count + 1
                    )

                    hadSuccessfulOCRPass = hadSuccessfulOCRPass || evaluation.hadSuccessfulOCRPass
                    if let error = evaluation.lastOCRError {
                        lastOCRError = error
                    }
                    attemptSummaries.append(evaluation.summary)

                    if let retryBest = evaluation.best {
                        let boosted = CaptureRecognitionHeuristics.applyConsensusBoost(to: retryBest, frequencies: &textFrequency)
                        if let currentBest = bestSelection {
                            if boosted.score > currentBest.score {
                                bestSelection = boosted
                            }
                        } else {
                            bestSelection = boosted
                        }

                        if CaptureRecognitionHeuristics.hasStrongVideoResult(boosted, frequencies: textFrequency) {
                            break
                        }
                    }
                }
            }

            if !hadSuccessfulOCRPass, let lastOCRError {
                throw lastOCRError
            }

            guard let best = bestSelection else {
                handleEmptyResult(
                    captureMode: captureMode,
                    attemptSummary: "No text found after \(attemptSummaries.count) capture attempt(s). \(String(attemptSummaries.joined(separator: " || ").prefix(450)))"
                )
                return
            }
            try finalizeSelection(
                best,
                captureMode: captureMode,
                outputPreset: outputPreset,
                source: source,
                notificationDisplayFrame: preferredDisplay?.frame
            )
        } catch {
            clearCaptureClockIfCurrent()
            handleFailure(Self.mapToPipelineError(error))
        }
    }

    func startWatchSession(
        screenRect: CGRect,
        preferredDisplay: ScreenDescriptor?,
        environment: ScreenEnvironmentSnapshot,
        source: ClipboardHistoryEntry.SourceContext? = nil,
        sessionConfiguration: CaptureSessionConfiguration? = nil
    ) async {
        let resolvedConfiguration = sessionConfiguration ?? resolvedSessionConfiguration(for: source)
        watchTask?.cancel()
        let session = CaptureWatchSession(
            selectionRect: screenRect.standardized,
            preferredDisplayID: preferredDisplay?.displayID,
            captureMode: resolvedConfiguration.captureMode,
            outputPreset: resolvedConfiguration.outputPreset,
            ocrLanguageSelection: resolvedConfiguration.ocrLanguageSelection,
            source: source,
            lastRecognizedSignature: nil,
            lastRawText: nil
        )
        currentWatchSession = session
        appState.updateWatchState(.active)
        appState.statusMessage = L10n.watchActive(mode: resolvedConfiguration.captureMode.title)

        watchTask = Task { [weak self] in
            guard let self else { return }
            await self.runWatchLoop(initialSession: session, environment: environment)
        }
    }

    private func performAttempt(
        request: CaptureRequest,
        captureRect: CGRect,
        sourceRect: CGRect,
        captureMode: CaptureMode,
        languageSelection: OCRLanguageSelection,
        attemptLabel: String,
        attemptIndex: Int,
        totalAttempts: Int
    ) async throws -> CaptureOCRAttemptEvaluation {
        guard captureWorkIsCurrent() else { throw CancellationError() }
        appState.captureState = .capturing
        appState.statusMessage = totalAttempts > 1
            ? "Görüntü yakalanıyor... (\(attemptIndex)/\(totalAttempts))"
            : "Görüntü yakalanıyor..."
        STGLog.pipeline.info(
            "State → capturing attempt=\(attemptLabel, privacy: .public) rect=(\(captureRect.origin.x),\(captureRect.origin.y),\(captureRect.width),\(captureRect.height))"
        )

        let attemptRequest = CaptureRequest(
            selectionRect: captureRect,
            preferredDisplay: request.preferredDisplay,
            environment: request.environment
        )
        let candidates = try await Self.captureCandidatesAsync(service: screenCaptureService, request: attemptRequest)
        guard captureWorkIsCurrent() else { throw CancellationError() }
        guard !candidates.isEmpty else {
            throw CapturePipelineError.captureFailed(
                domain: "CaptureCoordinator",
                code: -1,
                description: "No capture candidate was returned"
            )
        }

        appState.captureState = .recognizing
        appState.statusMessage = L10n.recognitionVariants(captureMode.recognitionProgressTitle, count: candidates.count)
        STGLog.pipeline.info(
            "State → recognizing attempt=\(attemptLabel, privacy: .public) candidates=\(candidates.count)"
        )

        let evaluation = await Self.evaluateCandidatesAsync(
            ocrService: ocrService,
            candidates: candidates,
            captureRect: captureRect,
            sourceRect: sourceRect,
            captureMode: captureMode,
            languageSelection: languageSelection,
            attemptLabel: attemptLabel
        )
        guard captureWorkIsCurrent() else { throw CancellationError() }
        return evaluation
    }

    nonisolated
    private static func captureCandidatesAsync(
        service: any ScreenCaptureProviding,
        request: CaptureRequest
    ) async throws -> [CaptureCandidate] {
        let task = Task(priority: .userInitiated) {
            try Task.checkCancellation()
            let candidates = try await service.captureCandidates(request: request)
            try Task.checkCancellation()
            return candidates
        }

        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func performClipboardImagePipeline(
        image: CGImage,
        source: ClipboardHistoryEntry.SourceContext?,
        sessionConfiguration: CaptureSessionConfiguration
    ) async {
        guard captureWorkIsCurrent() else { return }
        let sourceRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let candidate = CaptureCandidate(
            strategy: .clipboardImage,
            image: image,
            debugInfo: "clipboard-image"
        )

        do {
            appState.captureState = .recognizing
            appState.statusMessage = L10n.clipboardRecognition(sessionConfiguration.captureMode.recognitionProgressTitle)
            STGLog.pipeline.info("Clipboard OCR recognizing")

            let evaluation = await Self.evaluateCandidatesAsync(
                ocrService: ocrService,
                candidates: [candidate],
                captureRect: sourceRect,
                sourceRect: sourceRect,
                captureMode: sessionConfiguration.captureMode,
                languageSelection: sessionConfiguration.ocrLanguageSelection,
                attemptLabel: "clipboard"
            )

            if !evaluation.hadSuccessfulOCRPass, let lastOCRError = evaluation.lastOCRError {
                throw lastOCRError
            }

            guard let best = evaluation.best else {
                handleEmptyResult(
                    captureMode: sessionConfiguration.captureMode,
                    attemptSummary: "No text found in clipboard image. \(evaluation.summary)"
                )
                return
            }

            try finalizeSelection(
                best,
                captureMode: sessionConfiguration.captureMode,
                outputPreset: sessionConfiguration.outputPreset,
                source: source,
                notificationDisplayFrame: nil
            )
        } catch {
            clearCaptureClockIfCurrent()
            handleFailure(Self.mapToPipelineError(error))
        }
    }

    private func performImageFilePipeline(
        image: CGImage,
        fileURL: URL,
        sessionConfiguration: CaptureSessionConfiguration
    ) async {
        guard captureWorkIsCurrent() else { return }
        let sourceRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let candidate = CaptureCandidate(
            strategy: .importedImageFile,
            image: image,
            debugInfo: fileURL.lastPathComponent
        )

        do {
            appState.captureState = .recognizing
            appState.statusMessage = L10n.fileRecognition(sessionConfiguration.captureMode.recognitionProgressTitle)
            STGLog.pipeline.info("Image file OCR recognizing")

            let evaluation = await Self.evaluateCandidatesAsync(
                ocrService: ocrService,
                candidates: [candidate],
                captureRect: sourceRect,
                sourceRect: sourceRect,
                captureMode: sessionConfiguration.captureMode,
                languageSelection: sessionConfiguration.ocrLanguageSelection,
                attemptLabel: "file"
            )

            if !evaluation.hadSuccessfulOCRPass, let lastOCRError = evaluation.lastOCRError {
                throw lastOCRError
            }

            guard let best = evaluation.best else {
                handleEmptyResult(
                    captureMode: sessionConfiguration.captureMode,
                    attemptSummary: "No text found in image file \(fileURL.lastPathComponent). \(evaluation.summary)"
                )
                return
            }

            try finalizeSelection(
                best,
                captureMode: sessionConfiguration.captureMode,
                outputPreset: sessionConfiguration.outputPreset,
                source: nil,
                notificationDisplayFrame: nil
            )
        } catch {
            clearCaptureClockIfCurrent()
            handleFailure(Self.mapToPipelineError(error))
        }
    }

    private func performPDFFilePipeline(
        pages: [ImportedPDFPage],
        fileURL: URL,
        sessionConfiguration: CaptureSessionConfiguration
    ) async {
        let recognition = await recognizeImportedPDFPages(
            pages,
            fileURL: fileURL,
            sessionConfiguration: sessionConfiguration
        )

        guard !recognition.text.isEmpty else {
            handleEmptyResult(
                captureMode: sessionConfiguration.captureMode,
                attemptSummary: "No text found in PDF \(fileURL.lastPathComponent)."
            )
            return
        }

        guard captureWorkIsCurrent() else { return }

        let result = copyCapturedText(
            rawText: recognition.text,
            captureMode: sessionConfiguration.captureMode,
            contentKind: .text,
            source: nil,
            outputPreset: sessionConfiguration.outputPreset
        )

        switch result {
        case .success:
            clearCaptureClockIfCurrent()
            appState.captureState = .completed
            appState.statusMessage = L10n.pdfTextCopied
        case .failedWrite, .failedReadback:
            clearCaptureClockIfCurrent()
            appState.captureState = .failed
            let error = CapturePipelineError.clipboardFailed(result: result)
            appState.lastError = error
            appState.appendDiagnostic(
                category: "clipboard",
                message: error.errorDescription ?? "Pano doğrulaması başarısız.",
                domain: "Clipboard",
                code: nil
            )
        }
    }

    private func performSearchablePDFExportPipeline(
        pages: [ImportedPDFPage],
        fileURL: URL,
        destinationURL: URL,
        sessionConfiguration: CaptureSessionConfiguration
    ) async {
        do {
            let recognition = await recognizeImportedPDFPages(
                pages,
                fileURL: fileURL,
                sessionConfiguration: sessionConfiguration
            )

            guard !recognition.text.isEmpty else {
                handleEmptyResult(
                    captureMode: sessionConfiguration.captureMode,
                    attemptSummary: "No searchable text found in PDF \(fileURL.lastPathComponent)."
                )
                return
            }

            guard captureWorkIsCurrent() else { return }

            try PDFProcessingService.exportSearchablePDF(
                from: fileURL,
                recognizedPages: recognition.pages,
                to: destinationURL
            )

            clearCaptureClockIfCurrent()
            appState.captureState = .completed
            appState.statusMessage = L10n.searchablePDFCreated(destinationURL.lastPathComponent)
            appState.appendDiagnostic(
                category: "pdf",
                message: "Searchable PDF exported to \(destinationURL.path)",
                domain: "PDFExport",
                code: nil,
                severity: .info
            )
            NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
        } catch {
            clearCaptureClockIfCurrent()
            handleFailure(Self.mapToPipelineError(error))
        }
    }

    private func recognizeImportedPDFPages(
        _ pages: [ImportedPDFPage],
        fileURL: URL,
        sessionConfiguration: CaptureSessionConfiguration
    ) async -> (text: String, pages: [ImportedPDFRecognitionPage]) {
        var recognizedTexts: [String] = []
        var recognizedPages: [ImportedPDFRecognitionPage] = []

        for (pageOffset, page) in pages.enumerated() {
            guard captureWorkIsCurrent() else { break }
            let sourceRect = CGRect(origin: .zero, size: page.pageBounds.size)
            let candidate = CaptureCandidate(
                strategy: .importedPDFPage,
                image: page.image,
                debugInfo: "\(fileURL.lastPathComponent)#page-\(pageOffset + 1)"
            )

            appState.captureState = .recognizing
            appState.statusMessage = L10n.pdfPageRecognition(sessionConfiguration.captureMode.recognitionProgressTitle, page: pageOffset + 1, total: pages.count)

            let evaluation = await Self.evaluateCandidatesAsync(
                ocrService: ocrService,
                candidates: [candidate],
                captureRect: sourceRect,
                sourceRect: sourceRect,
                captureMode: sessionConfiguration.captureMode,
                languageSelection: sessionConfiguration.ocrLanguageSelection,
                attemptLabel: "pdf-page-\(pageOffset + 1)"
            )

            if let best = evaluation.best {
                let normalizedText = best.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !normalizedText.isEmpty {
                    recognizedTexts.append(normalizedText)
                }

                recognizedPages.append(
                    ImportedPDFRecognitionPage(
                        pageIndex: page.pageIndex,
                        pageBounds: page.pageBounds,
                        result: best.ocrResult
                    )
                )
            } else if let lastOCRError = evaluation.lastOCRError {
                appState.appendDiagnostic(
                    category: "ocr",
                    message: "PDF sayfa \(pageOffset + 1) OCR hatası: \(lastOCRError.localizedDescription)",
                    domain: "PDFImport",
                    code: nil,
                    severity: .warning
                )
            }
        }

        return (recognizedTexts.joined(separator: "\n\n"), recognizedPages)
    }

    private func handleEmptyResult(captureMode: CaptureMode, attemptSummary: String) {
        guard captureWorkIsCurrent() else { return }
        clearCaptureClockIfCurrent()
        appState.captureState = .completedEmpty
        appState.statusMessage = captureMode.emptyResultMessage
        appState.appendDiagnostic(
            category: "ocr",
            message: attemptSummary,
            domain: "CaptureCoordinator",
            code: nil
        )
    }

    private func finalizeSelection(
        _ best: CaptureOCRSelection,
        captureMode: CaptureMode,
        outputPreset: CaptureOutputPreset,
        source: ClipboardHistoryEntry.SourceContext?,
        notificationDisplayFrame: CGRect?
    ) throws {
        guard captureWorkIsCurrent() else { return }
        STGLog.capture.info(
            "Capture selected strategy=\(best.candidate.strategy.rawValue, privacy: .public) attempt=\(best.attemptLabel, privacy: .public) score=\(best.score) chars=\(best.text.count)"
        )
        appState.appendDiagnostic(
            category: "capture",
            message: "Selected \(best.candidate.strategy.rawValue) [\(best.attemptLabel)]: \(best.candidate.debugInfo)",
            domain: "CaptureCoordinator",
            code: nil
        )

        appState.captureState = .copying
        appState.statusMessage = L10n.copyingToClipboard
        STGLog.pipeline.info("State → copying")

        let clipboardResult = outputWriter.copyCapturedText(
            rawText: best.text,
            captureMode: captureMode,
            contentKind: historyContentKind(for: best),
            source: source,
            outputPreset: outputPreset,
            ocrConfidence: best.ocrResult.averageConfidence,
            notificationDisplayFrame: notificationDisplayFrame,
            successStatusMessage: CaptureRecognitionHeuristics.successStatusMessage(for: best)
        )

        switch clipboardResult {
        case .success:
            appState.captureState = .completed
            clearCaptureClockIfCurrent()
        case .failedWrite, .failedReadback:
            throw CapturePipelineError.clipboardFailed(result: clipboardResult)
        }
    }

    nonisolated
    private static func evaluateCandidatesAsync(
        ocrService: any OCRProviding,
        candidates: [CaptureCandidate],
        captureRect: CGRect,
        sourceRect: CGRect,
        captureMode: CaptureMode,
        languageSelection: OCRLanguageSelection,
        attemptLabel: String
    ) async -> CaptureOCRAttemptEvaluation {
        let task = Task(priority: .userInitiated) {
            var bestCandidateResult: CaptureOCRSelection?
            var hadSuccessfulOCRPass = false
            var lastOCRError: CapturePipelineError?
            var summaryParts: [String] = []
            let preferredRegions = CaptureRecognitionHeuristics.preferredOCRRegions(
                sourceRect: sourceRect,
                within: captureRect,
                captureMode: captureMode
            )

            for candidate in candidates {
                if Task.isCancelled {
                    break
                }

                do {
                    let ocrResult = try await ocrService.recognizeText(
                        in: candidate.image,
                        sourceRect: sourceRect,
                        preferredRegions: preferredRegions,
                        captureMode: captureMode,
                        languageSelection: languageSelection
                    )

                    if Task.isCancelled {
                        break
                    }

                    hadSuccessfulOCRPass = true

                    let text = ocrResult.fullText(for: captureMode).trimmingCharacters(in: .whitespacesAndNewlines)
                    let score = CaptureRecognitionHeuristics.scoreOCRResult(ocrResult, text: text, captureMode: captureMode)
                    var bestCandidateSelection: CaptureOCRSelection?

                    if !text.isEmpty {
                        bestCandidateSelection = CaptureOCRSelection(
                            candidate: candidate,
                            ocrResult: ocrResult,
                            text: text,
                            score: score,
                            attemptLabel: attemptLabel,
                            kind: .text
                        )
                    }

                    if CaptureRecognitionHeuristics.shouldAttemptBarcodeDetection(
                        for: captureMode,
                        recognizedText: text,
                        blockCount: ocrResult.blocks.count
                    ),
                       let barcode = try await ocrService.detectBarcode(in: candidate.image) {
                        if Task.isCancelled {
                            break
                        }

                        let barcodeSelection = CaptureRecognitionHeuristics.selectionForBarcode(
                            barcode,
                            candidate: candidate,
                            sourceRect: sourceRect,
                            attemptLabel: attemptLabel
                        )

                        if let current = bestCandidateSelection {
                            if barcodeSelection.score > current.score {
                                bestCandidateSelection = barcodeSelection
                            }
                        } else {
                            bestCandidateSelection = barcodeSelection
                        }
                    }

                    STGLog.ocr.info(
                        "OCR attempt=\(attemptLabel, privacy: .public) strategy=\(candidate.strategy.rawValue, privacy: .public) blocks=\(ocrResult.blocks.count) conf=\(ocrResult.averageConfidence) chars=\(text.count) score=\(score)"
                    )
                    STGLog.capture.info(
                        "Capture attempt=\(attemptLabel, privacy: .public) strategy=\(candidate.strategy.rawValue, privacy: .public) info=\(candidate.debugInfo, privacy: .public)"
                    )

                    summaryParts.append(
                        "\(attemptLabel):\(candidate.strategy.rawValue):chars=\(bestCandidateSelection?.text.count ?? text.count):score=\(Int(bestCandidateSelection?.score ?? score))"
                    )

                    if let selection = bestCandidateSelection {
                        if let current = bestCandidateResult {
                            if selection.score > current.score {
                                bestCandidateResult = selection
                            }
                        } else {
                            bestCandidateResult = selection
                        }
                    }
                } catch {
                    let pipelineError = mapToPipelineError(error)
                    lastOCRError = pipelineError
                    summaryParts.append("\(attemptLabel):\(candidate.strategy.rawValue):ocr-error")
                    STGLog.ocr.error(
                        "OCR attempt failed label=\(attemptLabel, privacy: .public) strategy=\(candidate.strategy.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                }
            }

            let summary = summaryParts.isEmpty
                ? "\(attemptLabel):no-candidates"
                : summaryParts.joined(separator: " | ")

            return CaptureOCRAttemptEvaluation(
                best: bestCandidateResult,
                hadSuccessfulOCRPass: hadSuccessfulOCRPass,
                lastOCRError: lastOCRError,
                summary: summary
            )
        }

        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func presentOverlay(
        trigger: CaptureTrigger,
        source: ClipboardHistoryEntry.SourceContext?,
        sessionConfiguration: CaptureSessionConfiguration
    ) {
        appState.captureState = .selecting
        appState.statusMessage = sessionConfiguration.captureMode.selectionPrompt
        STGLog.capture.info("Overlay shown; trigger=\(trigger.rawValue, privacy: .public)")

        activeOverlay = overlayFactory(
            { [weak self] rect, screen in
                guard let self else { return }
                let environment = ScreenEnvironmentSnapshot.capture()
                let preferredDisplay = environment.descriptor(for: screen)
                self.activeOverlay = nil

                self.runCapture {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard self.captureWorkIsCurrent() else { return }
                    await self.performCapturePipeline(
                        screenRect: rect,
                        preferredDisplay: preferredDisplay,
                        environment: environment,
                        source: source,
                        sessionConfiguration: sessionConfiguration
                    )
                }
            },
            { [weak self] in
                guard let self else { return }
                self.abandonInFlightCapture()
                self.appState.captureState = .cancelled
                self.appState.statusMessage = L10n.captureCancelled
            }
        )
        activeOverlay?.showOverlay()
    }

    private func presentWatchOverlay(
        source: ClipboardHistoryEntry.SourceContext?,
        sessionConfiguration: CaptureSessionConfiguration
    ) {
        appState.updateWatchState(.selecting)
        appState.statusMessage = L10n.chooseWatchRegion(mode: sessionConfiguration.captureMode.title, preset: sessionConfiguration.outputPreset.title)

        activeOverlay = overlayFactory(
            { [weak self] rect, screen in
                guard let self else { return }
                let environment = ScreenEnvironmentSnapshot.capture()
                let preferredDisplay = environment.descriptor(for: screen)
                self.activeOverlay = nil

                Task { @MainActor in
                    guard self.appState.watchState == .selecting else { return }
                    await self.startWatchSession(
                        screenRect: rect,
                        preferredDisplay: preferredDisplay,
                        environment: environment,
                        source: source,
                        sessionConfiguration: sessionConfiguration
                    )
                }
            },
            { [weak self] in
                guard let self else { return }
                self.activeOverlay = nil
                self.appState.updateWatchState(.inactive)
                self.appState.statusMessage = L10n.watchCancelled
            }
        )
        activeOverlay?.showOverlay()
    }

    private func applyPermissionState(_ state: ScreenPermissionState) {
        appState.permissionState = state

        if appState.captureState.isBusy {
            return
        }

        switch state {
        case .granted:
            if appState.captureState == .idle || appState.captureState == .cancelled {
                appState.statusMessage = appState.readyStatusMessage
            }
        case .requiresRestart:
            appState.statusMessage = L10n.permissionRestartShort
        case .denied:
            appState.statusMessage = L10n.permissionDeniedRefresh
        case .requestInProgress:
            appState.statusMessage = L10n.permissionRequesting
        case .unknown:
            appState.statusMessage = L10n.permissionUnknownShort
        }
    }

    private func runWatchLoop(
        initialSession: CaptureWatchSession,
        environment initialEnvironment: ScreenEnvironmentSnapshot
    ) async {
        var session = initialSession
        var environment = initialEnvironment

        while !Task.isCancelled {
            do {
                environment = await MainActor.run { ScreenEnvironmentSnapshot.capture() }
                let preferredDisplay = environment.displays.first(where: { $0.displayID == session.preferredDisplayID })
                let captureRect = CaptureRecognitionHeuristics.preferredCaptureRect(
                    for: session.selectionRect,
                    captureMode: session.captureMode,
                    preferredDisplay: preferredDisplay,
                    environment: environment
                )
                let request = CaptureRequest(
                    selectionRect: captureRect,
                    preferredDisplay: preferredDisplay,
                    environment: environment,
                    singleStrategy: true
                )
                let candidates = try await Self.captureCandidatesAsync(service: screenCaptureService, request: request)
                let evaluation = await Self.evaluateCandidatesAsync(
                    ocrService: ocrService,
                    candidates: candidates,
                    captureRect: captureRect,
                    sourceRect: session.selectionRect,
                    captureMode: session.captureMode,
                    languageSelection: session.ocrLanguageSelection,
                    attemptLabel: "watch"
                )

                if Task.isCancelled || appState.watchState != .active {
                    break
                }

                if let best = evaluation.best {
                    let signature = CaptureRecognitionHeuristics.normalizedRecognizedText(best.text)
                    if !signature.isEmpty, signature != session.lastRecognizedSignature {
                        let payload = WatchTextFilter.payload(
                            from: best.text,
                            previousText: session.lastRawText,
                            configuration: appState.watchConfiguration
                        )
                        if let payload, !payload.isEmpty {
                            let copied = await handleWatchUpdate(
                                best,
                                rawText: payload,
                                preferredDisplay: preferredDisplay
                            )
                            session.lastRecognizedSignature = signature
                            if copied {
                                session.lastRawText = best.text
                            }
                            currentWatchSession = session
                        } else {
                            // Empty filtered payload: mark seen so the same frame is not reconsidered.
                            session.lastRecognizedSignature = signature
                            session.lastRawText = best.text
                            currentWatchSession = session
                        }
                    }
                }
            } catch {
                let pipelineError = Self.mapToPipelineError(error)
                let shouldStop = await handleWatchFailure(pipelineError)
                if shouldStop {
                    break
                }
            }

            do {
                try await Task.sleep(nanoseconds: watchIntervalNanoseconds)
            } catch {
                break
            }
        }
    }

    @discardableResult
    private func handleWatchUpdate(
        _ selection: CaptureOCRSelection,
        rawText: String,
        preferredDisplay: ScreenDescriptor?
    ) async -> Bool {
        guard appState.watchState == .active else { return false }

        let clipboardResult = outputWriter.copyCapturedText(
            rawText: rawText,
            captureMode: currentWatchSession?.captureMode ?? appState.captureMode,
            contentKind: historyContentKind(for: selection),
            source: currentWatchSession?.source,
            outputPreset: currentWatchSession?.outputPreset ?? appState.captureOutputPreset,
            notificationDisplayFrame: preferredDisplay?.frame,
            successStatusMessage: "👁 \(CaptureRecognitionHeuristics.successStatusMessage(for: selection))"
        )
        switch clipboardResult {
        case .success:
            return true
        case .failedWrite, .failedReadback:
            appState.statusMessage = CapturePipelineError.clipboardFailed(result: clipboardResult).errorDescription ?? L10n.watchClipboardFailed
            appState.appendDiagnostic(
                category: "watch",
                message: "Clipboard write failed during watch mode",
                domain: "NSPasteboard",
                code: nil,
                severity: .warning
            )
            return false
        }
    }

    private func handleWatchFailure(_ error: CapturePipelineError) async -> Bool {
        switch error {
        case .permissionDenied:
            let resolved = await permissionService.resolveState()
            appState.permissionState = resolved

            switch resolved {
            case .denied, .unknown:
                appState.statusMessage = L10n.watchStoppedPermissionOff
                appState.updateWatchState(.inactive)
                watchTask?.cancel()
                watchTask = nil
                return true
            case .requiresRestart:
                appState.statusMessage = L10n.watchStoppedNeedsRestart
                appState.updateWatchState(.inactive)
                watchTask?.cancel()
                watchTask = nil
                return true
            case .granted, .requestInProgress:
                appState.appendDiagnostic(
                    category: "watch",
                    message: "Watch permission probe failed but state revalidated as \(resolved.uiMessage). Monitoring continues.",
                    domain: "screen.permission",
                    code: nil,
                    severity: .warning
                )
                if appState.watchState == .active {
                    appState.statusMessage = L10n.watchTemporaryPermissionError
                }
                return false
            }
        case .captureFailed(_, _, let description):
            appState.appendDiagnostic(
                category: "watch",
                message: description,
                domain: "CaptureCoordinator",
                code: nil,
                severity: .warning
            )
        case .ocrFailed(let description):
            appState.appendDiagnostic(
                category: "watch",
                message: description,
                domain: "Vision",
                code: nil,
                severity: .warning
            )
        case .clipboardFailed, .invalidSourceRect, .displayNotFound, .noTextFound:
            break
        }

        return false
    }

    private func resolvedSessionConfiguration(
        for source: ClipboardHistoryEntry.SourceContext?,
        overrides: AutomationCaptureOverrides? = nil
    ) -> CaptureSessionConfiguration {
        let baseConfiguration: CaptureSessionConfiguration

        if let profile = appState.appProfile(for: source?.bundleIdentifier) {
            baseConfiguration = CaptureSessionConfiguration(
                captureMode: profile.captureMode,
                outputPreset: profile.outputPreset,
                ocrLanguageSelection: profile.ocrLanguageSelection,
                profileName: profile.appName
            )
        } else {
            baseConfiguration = CaptureSessionConfiguration(
                captureMode: appState.captureMode,
                outputPreset: appState.captureOutputPreset,
                ocrLanguageSelection: appState.ocrLanguageSelection,
                profileName: nil
            )
        }

        guard let overrides else {
            return baseConfiguration
        }

        return overrides.applying(to: baseConfiguration)
    }

    nonisolated
    private static func mapToPipelineError(_ error: Error) -> CapturePipelineError {
        if let pipelineError = error as? CapturePipelineError {
            return pipelineError
        }

        if let pdfError = error as? PDFProcessingError {
            return .captureFailed(
                domain: "PDFImport",
                code: -20,
                description: pdfError.errorDescription ?? "PDF processing failed."
            )
        }

        let nsError = error as NSError

        if nsError.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain",
           (nsError.code == -3801 || nsError.code == 7) {
            return .permissionDenied(detail: nsError.localizedDescription)
        }

        if nsError.domain == VNErrorDomain {
            return .ocrFailed(description: nsError.localizedDescription)
        }

        return .captureFailed(
            domain: nsError.domain,
            code: nsError.code,
            description: nsError.localizedDescription
        )
    }

    nonisolated
    private static func loadImageFile(at url: URL) throws -> CGImage {
        try PDFProcessingService.validateImportFileSize(at: url)

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw CapturePipelineError.captureFailed(
                domain: "FileImport",
                code: -11,
                description: L10n.imageOpenFailed
            )
        }

        let pixelCount = image.width * image.height
        // ponytail: ~40MP ceiling; raise if large-scan workflows need more
        if pixelCount > 40_000_000 {
            throw CapturePipelineError.captureFailed(
                domain: "FileImport",
                code: -12,
                description: L10n.imageTooLarge
            )
        }

        return image
    }

    private func handleFailure(_ error: CapturePipelineError) {
        guard captureWorkIsCurrent() else { return }
        appState.captureState = .failed
        appState.lastError = error
        appState.statusMessage = error.errorDescription ?? L10n.unknownFailure

        switch error {
        case .permissionDenied(let detail):
            STGLog.permission.error("Permission failure: \(detail ?? "n/a", privacy: .public)")
            Task { @MainActor in
                let resolved = await permissionService.resolveState()
                appState.permissionState = resolved
            }
            appState.appendDiagnostic(
                category: "permission",
                message: detail ?? "Permission denied",
                domain: "screen.permission",
                code: nil
            )

        case .captureFailed(let domain, let code, let description):
            STGLog.capture.error("Capture failed: \(description, privacy: .public) [\(domain, privacy: .public):\(code)]")
            appState.appendDiagnostic(category: "capture", message: description, domain: domain, code: code)

        case .ocrFailed(let description):
            STGLog.ocr.error("OCR failed: \(description, privacy: .public)")
            appState.appendDiagnostic(category: "ocr", message: description, domain: "Vision", code: nil)

        case .clipboardFailed(let result):
            STGLog.clipboard.error("Clipboard failed: \(String(describing: result), privacy: .public)")
            appState.appendDiagnostic(category: "clipboard", message: "\(result)", domain: "NSPasteboard", code: nil)

        case .noTextFound:
            STGLog.ocr.info("No text found in captured region")
            appState.appendDiagnostic(category: "ocr", message: "No text found", domain: nil, code: nil, severity: .warning)

        case .invalidSourceRect:
            STGLog.capture.error("Invalid source rectangle")
            appState.appendDiagnostic(category: "capture", message: "Invalid source rectangle", domain: nil, code: nil)

        case .displayNotFound:
            STGLog.capture.error("Display not found for selection")
            appState.appendDiagnostic(category: "capture", message: "Display not found", domain: nil, code: nil)
        }
    }

    private func historyContentKind(for selection: CaptureOCRSelection) -> ClipboardHistoryEntry.ContentKind {
        switch selection.kind {
        case .text:
            return .text
        case .barcode:
            return .barcode
        }
    }

    nonisolated
    private static func captureHistorySourceContext() -> ClipboardHistoryEntry.SourceContext? {
        SourceContextResolver.currentFrontmostExternalSourceContext()
    }
}
