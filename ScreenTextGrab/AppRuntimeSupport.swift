import ApplicationServices
import AppKit
import Foundation

enum ScreenshotLaunchMode {
    case menuPanel
    case settingsGeneral
    case settingsOCR
    case settingsDiagnostics
    case settingsHistory
    case tableReview

    init?(arguments: [String]) {
        if arguments.contains("--screenshot-menu-panel") {
            self = .menuPanel
            return
        }

        if arguments.contains("--screenshot-settings-general") || arguments.contains("--screenshot-settings") {
            self = .settingsGeneral
            return
        }

        if arguments.contains("--screenshot-settings-ocr") {
            self = .settingsOCR
            return
        }

        if arguments.contains("--screenshot-settings-diagnostics") {
            self = .settingsDiagnostics
            return
        }

        if arguments.contains("--screenshot-settings-history") {
            self = .settingsHistory
            return
        }

        if arguments.contains("--screenshot-table-review") {
            self = .tableReview
            return
        }

        return nil
    }
}

@MainActor
final class PreviewLaunchAtLoginManager: LaunchAtLoginManaging {
    private(set) var launchAtLoginState: LaunchAtLoginState

    init(state: LaunchAtLoginState) {
        self.launchAtLoginState = state
    }

    func refreshLaunchAtLoginState() -> LaunchAtLoginState {
        launchAtLoginState
    }

    func setLaunchAtLogin(enabled: Bool) async throws -> LaunchAtLoginState {
        launchAtLoginState = enabled ? .enabled : .disabled
        return launchAtLoginState
    }

    func openLoginItemsSettings() {}
}

@MainActor
final class PreviewPermissionProvider: ScreenPermissionProviding {
    var needsRestartAfterGrant: Bool { false }

    private let snapshot: PermissionDiagnosticSnapshot

    init(snapshot: PermissionDiagnosticSnapshot) {
        self.snapshot = snapshot
    }

    func refreshPreflight() -> ScreenPermissionState {
        snapshot.currentState
    }

    func resolveState() async -> ScreenPermissionState {
        snapshot.currentState
    }

    func requestIfNeeded() async -> ScreenPermissionState {
        snapshot.currentState
    }

    func diagnosticSnapshot() async -> PermissionDiagnosticSnapshot {
        snapshot
    }

    func openSystemSettings() {}
}

enum InstalledAppLocator {
    static func isInstalledAppURL(
        _ url: URL,
        searchRoots: [URL] = defaultSearchRoots()
    ) -> Bool {
        let currentPath = standardizedPath(for: url)
        return searchRoots.contains { root in
            currentPath.hasPrefix(standardizedPath(for: root) + "/")
        }
    }

    static func preferredInstalledCopy(
        currentURL: URL,
        bundleIdentifier: String?,
        searchRoots: [URL] = defaultSearchRoots(),
        fileManager: FileManager = .default
    ) -> URL? {
        guard let targetBundleIdentifier = bundleIdentifier else {
            return nil
        }

        let currentPath = standardizedPath(for: currentURL)
        let currentBuildVersion = buildVersion(for: currentURL)
        let appName = currentURL.lastPathComponent
        let bundledCandidates = searchRoots.flatMap { root in
            appBundleCandidates(in: root, fileManager: fileManager)
        }
        let directNameCandidates = searchRoots.map {
            $0.appendingPathComponent(appName, isDirectory: true)
        }

        let candidates = uniqueURLs(from: directNameCandidates + bundledCandidates)
            .filter { standardizedPath(for: $0) != currentPath }
            .filter { appBundleIdentifier(for: $0) == targetBundleIdentifier }
            .sorted { lhs, rhs in
                ranking(for: lhs, preferredAppName: appName) < ranking(for: rhs, preferredAppName: appName)
            }

        guard let candidate = candidates.first else {
            return nil
        }

        if let currentBuildVersion, let candidateBuildVersion = buildVersion(for: candidate),
           candidateBuildVersion.compare(currentBuildVersion, options: .numeric) == .orderedAscending {
            return nil
        }

        return candidate
    }

    static func preferredInstallDestination(
        currentURL: URL,
        bundleIdentifier: String?,
        searchRoots: [URL] = defaultSearchRoots(),
        fileManager: FileManager = .default
    ) -> URL? {
        let appName = currentURL.lastPathComponent
        let bundledCandidates = searchRoots.flatMap { root in
            appBundleCandidates(in: root, fileManager: fileManager)
        }
        let directNameCandidates = searchRoots.map {
            $0.appendingPathComponent(appName, isDirectory: true)
        }

        let existingCandidates = uniqueURLs(from: directNameCandidates + bundledCandidates)
            .filter { candidate in
                guard let bundleIdentifier else {
                    return candidate.lastPathComponent == appName
                }

                return appBundleIdentifier(for: candidate) == bundleIdentifier
            }
            .sorted { lhs, rhs in
                ranking(for: lhs, preferredAppName: appName) < ranking(for: rhs, preferredAppName: appName)
            }

        if let existingCandidate = existingCandidates.first {
            return existingCandidate
        }

        for root in searchRoots {
            if ensureInstallRootExistsAndIsWritable(root, fileManager: fileManager) {
                return root.appendingPathComponent(appName, isDirectory: true)
            }
        }

        return nil
    }

    static func defaultSearchRoots(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            homeDirectory.appendingPathComponent("Applications", isDirectory: true)
        ]
    }

    private static func appBundleCandidates(in root: URL, fileManager: FileManager) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter { $0.pathExtension.lowercased() == "app" }
    }

    private static func appBundleIdentifier(for url: URL) -> String? {
        Bundle(url: url)?.bundleIdentifier
    }

    private static func buildVersion(for url: URL) -> String? {
        Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    private static func uniqueURLs(from urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { url in
            let path = standardizedPath(for: url)
            return seen.insert(path).inserted
        }
    }

    private static func ranking(for url: URL, preferredAppName: String) -> (Int, Int, String) {
        let path = standardizedPath(for: url)
        let applicationsRank = path.hasPrefix("/Applications/") ? 0 : 1
        let nameRank = url.lastPathComponent == preferredAppName ? 0 : 1
        return (applicationsRank, nameRank, path)
    }

    private static func standardizedPath(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private static func ensureInstallRootExistsAndIsWritable(_ root: URL, fileManager: FileManager) -> Bool {
        let path = standardizedPath(for: root)
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            return isDirectory.boolValue && fileManager.isWritableFile(atPath: path)
        }

        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            return fileManager.isWritableFile(atPath: path)
        } catch {
            return false
        }
    }
}

enum InstalledAppRelocatorError: LocalizedError {
    case noInstallDestination
    case copyFailed(String)

    var errorDescription: String? {
        switch self {
        case .noInstallDestination:
            return L10n.installRootUnavailable
        case .copyFailed(let message):
            return "\(L10n.installCopyFailedPrefix) \(message)"
        }
    }
}

enum InstalledAppRelocator {
    static func installCurrentCopy(
        from currentURL: URL,
        bundleIdentifier: String?,
        searchRoots: [URL] = InstalledAppLocator.defaultSearchRoots(),
        fileManager: FileManager = .default
    ) throws -> URL {
        guard let destinationURL = InstalledAppLocator.preferredInstallDestination(
            currentURL: currentURL,
            bundleIdentifier: bundleIdentifier,
            searchRoots: searchRoots,
            fileManager: fileManager
        ) else {
            throw InstalledAppRelocatorError.noInstallDestination
        }

        let sourceURL = currentURL.resolvingSymlinksInPath().standardizedFileURL
        let targetURL = destinationURL.resolvingSymlinksInPath().standardizedFileURL

        if sourceURL.path == targetURL.path {
            return targetURL
        }

        do {
            try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }

            try fileManager.copyItem(at: sourceURL, to: targetURL)
            return targetURL
        } catch {
            throw InstalledAppRelocatorError.copyFailed(error.localizedDescription)
        }
    }
}

enum SourceContextResolver {
    static func currentFrontmostExternalSourceContext() -> ClipboardHistoryEntry.SourceContext? {
        externalSourceContext(for: NSWorkspace.shared.frontmostApplication)
    }

    static func externalSourceContext(
        for application: NSRunningApplication?
    ) -> ClipboardHistoryEntry.SourceContext? {
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let bundleIdentifier = application?.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)

        if bundleIdentifier == ownBundleIdentifier {
            return nil
        }

        let appName = application?.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (appName?.isEmpty == false) || (bundleIdentifier?.isEmpty == false) else {
            return nil
        }

        return ClipboardHistoryEntry.SourceContext(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            windowTitle: focusedWindowTitle(for: application)
        )
    }

    private static func focusedWindowTitle(for application: NSRunningApplication?) -> String? {
        guard AXIsProcessTrusted(),
              let application else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        if let title = windowTitle(attribute: kAXFocusedWindowAttribute as CFString, for: appElement) {
            return title
        }

        return windowTitle(attribute: kAXMainWindowAttribute as CFString, for: appElement)
    }

    private static func windowTitle(attribute: CFString, for appElement: AXUIElement) -> String? {
        var rawWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, attribute, &rawWindow) == .success,
              let rawWindow else {
            return nil
        }

        guard CFGetTypeID(rawWindow) == AXUIElementGetTypeID() else {
            return nil
        }

        let windowElement = unsafeBitCast(rawWindow, to: AXUIElement.self)
        var rawTitle: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &rawTitle) == .success,
              let title = rawTitle as? String else {
            return nil
        }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
