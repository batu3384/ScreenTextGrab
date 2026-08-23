import AppKit
import Combine
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    private var hotkeyService: HotkeyService?
    private var launchAtLoginService: LaunchAtLoginService?
    private var permissionService: ScreenPermissionService?
    private var captureCoordinator: CaptureCoordinator?
    private var speechService: SpeechService?
    private var appUpdateService: AppUpdateService?
    var previewWindowController: NSWindowController?
    var previewLaunchAtLoginManager: PreviewLaunchAtLoginManager?
    var previewPermissionProvider: PreviewPermissionProvider?
    private var finderImportServiceProvider: FinderImportServiceProvider?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var workspaceActivationObserver: NSObjectProtocol?
    private var captureStateObserver: AnyCancellable?
    private var automationCommandQueue = AutomationCommandQueue()
    private var urlSchemeAutomationAllowedThisSession = false
    private var screenshotLaunchMode: ScreenshotLaunchMode? {
        ScreenshotLaunchMode(arguments: ProcessInfo.processInfo.arguments)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let screenshotLaunchMode {
            NSApp.setActivationPolicy(.regular)
            configurePreviewState()
            showPreview(for: screenshotLaunchMode)
            return
        }

        let launchAtLoginService = LaunchAtLoginService()
        self.launchAtLoginService = launchAtLoginService

        if handleLaunchAtLoginCommandIfNeeded(using: launchAtLoginService) {
            return
        }

        if let automationCommand = AutomationCommand(arguments: ProcessInfo.processInfo.arguments) {
            automationCommandQueue.enqueue([automationCommand])
        }

        NSApp.setActivationPolicy(.accessory)

        guard enforceCanonicalInstallLocation() else {
            return
        }

        let permissionService = ScreenPermissionService()
        let screenCaptureService = ScreenCaptureService()
        let ocrService = OCRService()
        let clipboardService = ClipboardManager()

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: ocrService,
            clipboardService: clipboardService
        )

        self.permissionService = permissionService
        self.captureCoordinator = coordinator
        appState.coordinator = coordinator
        appState.permissionDiagnosticsProvider = permissionService

        let hotkeyService = HotkeyService { [weak coordinator] in
            coordinator?.startCapture(trigger: .hotkey)
        }
        let speechService = SpeechService { [weak appState] state in
            appState?.updateSpeechState(state)
        }
        self.hotkeyService = hotkeyService
        self.speechService = speechService
        self.appUpdateService = AppUpdateService(appState: appState)
        appState.hotkeyManager = self
        appState.launchAtLoginManager = self
        appState.speechManager = self
        appState.updateManager = appUpdateService
        appState.updateLaunchAtLoginState(launchAtLoginService.refreshState())
        appState.updateSpeechState(speechService.state)
        Task { @MainActor [weak self] in
            let state = await launchAtLoginService.bootstrapState()
            self?.appState.updateLaunchAtLoginState(state)
        }

        do {
            try hotkeyService.registerHotkey()
            appState.updateHotkeyAvailability(isAvailable: true, label: hotkeyService.hotkeyDisplayLabel)
        } catch {
            let nsError = error as NSError
            appState.updateHotkeyAvailability(isAvailable: false, label: hotkeyService.hotkeyDisplayLabel)
            appState.appendDiagnostic(
                category: "hotkey",
                message: error.localizedDescription,
                domain: nsError.domain,
                code: nsError.code,
                severity: .warning
            )
            STGLog.capture.error("Hotkey registration failed: \(error.localizedDescription, privacy: .public)")
        }

        beginActiveAppTracking()

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak coordinator] _ in
            Task { @MainActor in
                coordinator?.refreshPermission()
                if let state = self?.launchAtLoginService?.refreshState() {
                    self?.appState.updateLaunchAtLoginState(state)
                }
            }
        }

        if #available(macOS 14.0, *) {
            ScreenTextGrabShortcutsProvider.updateAppShortcutParameters()
        }

        captureStateObserver = appState.$captureState
            .removeDuplicates()
            .sink { [weak self] state in
                guard let self else { return }
                self.automationCommandQueue.captureStateDidChange(state)
                guard !state.isBusy else { return }
                Task { @MainActor [weak self] in
                    self?.flushPendingAutomationCommands()
                }
            }

        configureFinderImportServices()
        flushPendingAutomationCommands()

        beginStartupExperience(using: coordinator, permissionService: permissionService)
    }

    func applicationWillTerminate(_ notification: Notification) {
        captureCoordinator?.stopWatching()
        speechService?.stopSpeaking()
        hotkeyService?.unregisterHotkey()
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
        if let workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceActivationObserver)
        }
        captureStateObserver?.cancel()
    }

    private func enforceCanonicalInstallLocation() -> Bool {
        let currentURL = Bundle.main.bundleURL.resolvingSymlinksInPath()

        #if DEBUG
        // Debug builds may run from any location (e.g. Xcode DerivedData) for development.
        // To avoid Spotlight clutter, unregister this transient copy from Launch Services.
        unregisterNonCanonicalCopyFromLaunchServicesIfNeeded(currentURL)
        return true
        #else
        let currentPath = currentURL.path

        if isRunningUnderTests {
            return true
        }

        if InstalledAppLocator.isInstalledAppURL(currentURL) {
            STGLog.lifecycle.info("Running from supported app location: \(currentPath, privacy: .public)")
            return true
        }

        guard let installedCopyURL = InstalledAppLocator.preferredInstalledCopy(
            currentURL: currentURL,
            bundleIdentifier: Bundle.main.bundleIdentifier
        ) else {
            do {
                let relocatedURL = try InstalledAppRelocator.installCurrentCopy(
                    from: currentURL,
                    bundleIdentifier: Bundle.main.bundleIdentifier
                )

                STGLog.lifecycle.info("Relocated app to canonical path: \(relocatedURL.path, privacy: .public)")
                appState.captureState = .idle
                appState.permissionState = .unknown
                appState.statusMessage = L10n.installRelocatingStatus

                unregisterNonCanonicalCopyFromLaunchServicesIfNeeded(currentURL)
                NSWorkspace.shared.open(relocatedURL)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    NSApplication.shared.terminate(nil)
                }

                return false
            } catch {
                STGLog.lifecycle.warning("Canonical install relocation failed: \(error.localizedDescription, privacy: .public)")
                appState.statusMessage = L10n.installOpenFromApplicationsStatus
                presentInstallLocationAlert(for: currentURL, error: error)
                return true
            }
        }

        STGLog.lifecycle.error("Unsupported app path: \(currentPath, privacy: .public)")
        appState.captureState = .failed
        appState.permissionState = .unknown
        appState.statusMessage = L10n.installOpeningInstalledCopyStatus

        unregisterNonCanonicalCopyFromLaunchServicesIfNeeded(currentURL)

        NSWorkspace.shared.open(installedCopyURL)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            NSApplication.shared.terminate(nil)
        }

        return false
        #endif
    }

    private func presentInstallLocationAlert(for appURL: URL, error: Error) {
        guard !isRunningUnderTests else {
            return
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.installAlertTitle
        alert.informativeText = [
            L10n.installAlertBody,
            error.localizedDescription
        ].joined(separator: "\n\n")
        alert.addButton(withTitle: L10n.actionOpenApplicationsFolder)
        alert.addButton(withTitle: L10n.actionContinue)

        if alert.runModal() == .alertFirstButtonReturn {
            let destinationFolder = InstalledAppLocator.defaultSearchRoots().first ?? appURL.deletingLastPathComponent()
            NSWorkspace.shared.open(destinationFolder)
        }
    }

    private func unregisterNonCanonicalCopyFromLaunchServicesIfNeeded(_ appURL: URL) {
        guard !InstalledAppLocator.isInstalledAppURL(appURL) else {
            return
        }

        guard let lsregisterPath = launchServicesRegisterExecutablePath() else {
            STGLog.lifecycle.warning("Launch Services executable not found; skipping unregister")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: lsregisterPath)
        process.arguments = ["-u", appURL.path]

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                STGLog.lifecycle.info("Unregistered non-canonical copy from Launch Services: \(appURL.path, privacy: .public)")
            } else {
                STGLog.lifecycle.warning("Launch Services unregister returned status=\(process.terminationStatus, privacy: .public)")
            }
        } catch {
            STGLog.lifecycle.warning("Launch Services unregister failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func launchServicesRegisterExecutablePath() -> String? {
        let candidates = [
            "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister",
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        ]

        return candidates.first(where: { FileManager.default.fileExists(atPath: $0) })
    }

    private var isRunningUnderTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil
    }

    private func beginActiveAppTracking() {
        updateActiveSourceApp(SourceContextResolver.currentFrontmostExternalSourceContext())

        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.updateActiveSourceApp(SourceContextResolver.externalSourceContext(for: application))
        }
    }

    private func updateActiveSourceApp(_ source: ClipboardHistoryEntry.SourceContext?) {
        guard let source else {
            return
        }

        appState.updateActiveSourceApp(source)
    }

    private func handleLaunchAtLoginCommandIfNeeded(using service: LaunchAtLoginService) -> Bool {
        guard let command = LaunchAtLoginCommand(arguments: ProcessInfo.processInfo.arguments) else {
            return false
        }

        Task { @MainActor in
            do {
                let state: LaunchAtLoginState
                switch command {
                case .status:
                    state = service.refreshState()
                case .enable:
                    state = try await service.setEnabled(true)
                case .disable:
                    state = try await service.setEnabled(false)
                }

                writeLaunchAtLoginCommandOutput("launch-at-login=\(state.cliValue)")
            } catch {
                writeLaunchAtLoginCommandOutput("launch-at-login-error=\(error.localizedDescription)")
            }

            NSApplication.shared.terminate(nil)
        }

        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor [weak self] in
            self?.handleIncomingURLs(urls)
        }
    }

    private func writeLaunchAtLoginCommandOutput(_ message: String) {
        guard let data = "\(message)\n".data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }

    private func scheduleInitialPermissionRefreshes(for coordinator: CaptureCoordinator) {
        let refreshDelays: [TimeInterval] = [0.8, 2.0]
        for delay in refreshDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak coordinator] in
                Task { @MainActor in
                    coordinator?.refreshPermission()
                }
            }
        }
    }

    private func configureFinderImportServices() {
        guard !isRunningUnderTests else {
            return
        }

        let provider = FinderImportServiceProvider { [weak self] urls in
            self?.handleIncomingURLs(urls)
        }
        finderImportServiceProvider = provider
        NSApp.servicesProvider = provider

        let portName = ((Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 } ?? "ScreenTextGrab"
        NSRegisterServicesProvider(provider, portName)
        NSUpdateDynamicServices()
    }

    @MainActor
    private func handleIncomingURLs(_ urls: [URL]) {
        switch AutomationCommand.resolveIncomingURLs(urls) {
        case .unsupported:
            if !urls.isEmpty {
                appState.statusMessage = L10n.pair(
                    "⚠️ Yalnızca görsel veya PDF dosyaları desteklenir.",
                    "⚠️ Only image and PDF files are supported."
                )
            }
        case .commands(let commands, let requiresURLSchemeAuthorization):
            if requiresURLSchemeAuthorization,
               !authorizeURLSchemeAutomationIfNeeded() {
                return
            }

            automationCommandQueue.enqueue(commands)
            let importedFileCount = commands.filter(\.isImportedFileCommand).count
            if importedFileCount > 1 {
                appState.statusMessage = L10n.format(
                    "📥 %d dosya sıraya alındı. İçe aktarma işlemi otomatik sırayla devam edecek.",
                    "📥 %d files were queued. Imports will continue automatically one by one.",
                    importedFileCount
                )
            }
            flushPendingAutomationCommands()
        }
    }

    @MainActor
    private func authorizeURLSchemeAutomationIfNeeded() -> Bool {
        if appState.urlSchemeAutomationEnabled ||
            urlSchemeAutomationAllowedThisSession ||
            isRunningUnderTests {
            return true
        }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.pair(
            "URL otomasyonu isteği",
            "URL automation request"
        )
        alert.informativeText = L10n.pair(
            "Başka bir uygulama ScreenTextGrab'ı stg:// bağlantısıyla tetiklemek istiyor. Ekran yakalama, dosya OCR veya pano işlemleri çalışabilir.",
            "Another app wants to trigger ScreenTextGrab via an stg:// link. This can run screen capture, file OCR, or clipboard actions."
        )
        alert.addButton(withTitle: L10n.pair("Bu oturumda izin ver", "Allow This Session"))
        alert.addButton(withTitle: L10n.pair("Her zaman izin ver", "Always Allow"))
        alert.addButton(withTitle: L10n.pair("Reddet", "Deny"))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            urlSchemeAutomationAllowedThisSession = true
            return true
        case .alertSecondButtonReturn:
            appState.setURLSchemeAutomationEnabled(true)
            return true
        default:
            appState.statusMessage = L10n.pair(
                "⚠️ URL otomasyonu reddedildi.",
                "⚠️ URL automation was denied."
            )
            return false
        }
    }

    private func beginStartupExperience(
        using coordinator: CaptureCoordinator,
        permissionService: ScreenPermissionService
    ) {
        DispatchQueue.main.async { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }

            Task { @MainActor [weak self, weak coordinator] in
                guard let self, let coordinator else { return }

                let ownBundleIdentifier = Bundle.main.bundleIdentifier
                let isForegroundLaunch = NSApp.isActive ||
                    NSWorkspace.shared.frontmostApplication?.bundleIdentifier == ownBundleIdentifier
                let state = await permissionService.resolveStartupState(isForegroundLaunch: isForegroundLaunch)
                coordinator.syncPermissionState(state)
                self.scheduleInitialPermissionRefreshes(for: coordinator)
            }
        }
    }

    @MainActor
    private func flushPendingAutomationCommands() {
        guard let coordinator = captureCoordinator else {
            return
        }

        while let command = automationCommandQueue.nextCommand(captureState: appState.captureState) {
            dispatchAutomationCommand(command, coordinator: coordinator)
            let startedBusyWork = appState.captureState.isBusy
            automationCommandQueue.markDispatchResult(for: command, startedBusyWork: startedBusyWork)

            if startedBusyWork {
                return
            }
        }
    }

    @MainActor
    private func dispatchAutomationCommand(
        _ command: AutomationCommand,
        coordinator: CaptureCoordinator
    ) {
        switch command {
        case .capture(let overrides):
            NSApp.activate(ignoringOtherApps: true)
            coordinator.startCapture(trigger: .automation, sessionOverrides: overrides.isEmpty ? nil : overrides)
        case .repeatLast(let overrides):
            NSApp.activate(ignoringOtherApps: true)
            coordinator.repeatLastCapture(sessionOverrides: overrides.isEmpty ? nil : overrides)
        case .savedRegion(let name, let overrides):
            NSApp.activate(ignoringOtherApps: true)
            coordinator.captureSavedRegion(named: name, sessionOverrides: overrides.isEmpty ? nil : overrides)
        case .activeSnippet:
            guard let suggestion = appState.activeSavedSnippetSuggestion else {
                appState.statusMessage = L10n.pair(
                    "⚠️ Aktif uygulama için kullanılabilir snippet bulunamadı.",
                    "⚠️ No available snippet was found for the active app."
                )
                return
            }
            _ = coordinator.copySavedSnippet(suggestion.snippet)
        case .snippet(let name):
            _ = coordinator.copySavedSnippet(named: name)
        case .snippetCollection(let name):
            NSApp.activate(ignoringOtherApps: true)
            if !appState.presentSettingsForSavedSnippetCollection(named: name) {
                appState.statusMessage = L10n.usesEnglish
                    ? "⚠️ Saved snippet collection not found: \(name)"
                    : "⚠️ Snippet koleksiyonu bulunamadı: \(name)"
            }
        case .clipboardImage(let overrides):
            coordinator.captureClipboardImage(sessionOverrides: overrides.isEmpty ? nil : overrides)
        case .imageFile(let url, let overrides):
            coordinator.captureImageFile(at: url, sessionOverrides: overrides.isEmpty ? nil : overrides)
        case .pdfFile(let url, let overrides):
            coordinator.capturePDFFile(at: url, sessionOverrides: overrides.isEmpty ? nil : overrides)
        case .searchablePDF(let url, let destinationURL, let overrides):
            coordinator.exportSearchablePDF(
                at: url,
                destinationURL: destinationURL,
                sessionOverrides: overrides.isEmpty ? nil : overrides
            )
        }
    }

}

private enum LaunchAtLoginCommand {
    case status
    case enable
    case disable

    init?(arguments: [String]) {
        guard let flagIndex = arguments.firstIndex(of: "--launch-at-login"),
              arguments.indices.contains(flagIndex + 1)
        else {
            return nil
        }

        switch arguments[flagIndex + 1].lowercased() {
        case "status":
            self = .status
        case "on", "enable", "enabled":
            self = .enable
        case "off", "disable", "disabled":
            self = .disable
        default:
            return nil
        }
    }
}

enum ImportedDocumentRoute: Equatable {
    case image(URL)
    case pdf(URL)
}

final class FinderImportServiceProvider: NSObject {
    private let onImportURLs: @MainActor ([URL]) -> Void

    init(onImportURLs: @escaping @MainActor ([URL]) -> Void) {
        self.onImportURLs = onImportURLs
    }

    @objc func importSelectedFiles(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = Self.readFileURLs(from: pasteboard)
        guard !urls.isEmpty else {
            error.pointee = L10n.pair(
                "Yalnızca görsel veya PDF dosyaları desteklenir.",
                "Only image and PDF files are supported."
            ) as NSString
            return
        }

        Task { @MainActor in
            onImportURLs(urls)
        }
    }

    static func readFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
           !urls.isEmpty {
            return urls
                .filter(\.isFileURL)
                .map { $0.resolvingSymlinksInPath().standardizedFileURL }
        }

        return pasteboard.pasteboardItems?
            .compactMap { item -> URL? in
                guard let rawValue = item.string(forType: .fileURL),
                      let url = URL(string: rawValue),
                      url.isFileURL else {
                    return nil
                }
                return url.resolvingSymlinksInPath().standardizedFileURL
            } ?? []
    }
}


@MainActor
extension AppDelegate: HotkeyManaging {
    var hotkeyDisplayLabel: String {
        hotkeyService?.hotkeyDisplayLabel ?? HotkeyConfiguration.defaultValue.displayLabel
    }

    var isHotkeyRegistered: Bool {
        hotkeyService?.isRegistered ?? false
    }

    func updateHotkey(to configuration: HotkeyConfiguration) throws {
        guard let hotkeyService else { return }

        do {
            try hotkeyService.updateHotkey(to: configuration)
            appState.updateHotkeyAvailability(isAvailable: hotkeyService.isRegistered, label: hotkeyService.hotkeyDisplayLabel)
            appState.appendDiagnostic(
                category: "hotkey",
                message: "Shortcut updated to \(hotkeyService.hotkeyDisplayLabel)",
                domain: "HotkeyService",
                code: nil,
                severity: .info
            )
        } catch {
            let nsError = error as NSError
            appState.updateHotkeyAvailability(isAvailable: hotkeyService.isRegistered, label: hotkeyService.hotkeyDisplayLabel)
            appState.appendDiagnostic(
                category: "hotkey",
                message: error.localizedDescription,
                domain: nsError.domain,
                code: nsError.code,
                severity: .warning
            )
            throw error
        }
    }

    func resetHotkeyToDefault() throws {
        try updateHotkey(to: .defaultValue)
    }
}

@MainActor
extension AppDelegate: LaunchAtLoginManaging {
    var launchAtLoginState: LaunchAtLoginState {
        launchAtLoginService?.refreshState() ?? .unavailable
    }

    func refreshLaunchAtLoginState() -> LaunchAtLoginState {
        let state = launchAtLoginService?.refreshState() ?? .unavailable
        appState.updateLaunchAtLoginState(state)
        return state
    }

    func setLaunchAtLogin(enabled: Bool) async throws -> LaunchAtLoginState {
        guard let launchAtLoginService else {
            let fallbackState: LaunchAtLoginState = .unavailable
            appState.updateLaunchAtLoginState(fallbackState)
            return fallbackState
        }

        do {
            let state = try await launchAtLoginService.setEnabled(enabled)
            appState.updateLaunchAtLoginState(state)
            appState.appendDiagnostic(
                category: "startup",
                message: enabled ? "Launch at login enabled" : "Launch at login disabled",
                domain: "LaunchAtLoginService",
                code: nil,
                severity: .info
            )
            return state
        } catch {
            let nsError = error as NSError
            let state = launchAtLoginService.refreshState()
            appState.updateLaunchAtLoginState(state)
            appState.appendDiagnostic(
                category: "startup",
                message: error.localizedDescription,
                domain: nsError.domain,
                code: nsError.code,
                severity: .warning
            )
            throw error
        }
    }

    func openLoginItemsSettings() {
        launchAtLoginService?.openSystemSettings()
    }
}

@MainActor
extension AppDelegate: SpeechManaging {
    var speechState: SpeechPlaybackState {
        speechService?.state ?? .idle
    }

    func toggleSpeechPlayback(for text: String) {
        speechService?.toggleSpeaking(text)
        appState.updateSpeechState(speechState)
    }

    func stopSpeechPlayback() {
        speechService?.stopSpeaking()
        appState.updateSpeechState(speechState)
    }
}

@MainActor
extension AppDelegate: AppUpdateManaging {
    func performPrimaryUpdateAction() {
        appUpdateService?.performPrimaryUpdateAction()
    }
}
