import AppKit
import Foundation

@MainActor
protocol AppUpdateManaging: AnyObject {
    func performPrimaryUpdateAction()
}

enum AppUpdateState: Equatable {
    case idle
    case checking
    case downloading(version: String, progressPercent: Int?)
    case readyToInstall(version: String)
    case upToDate
    case failed(message: String)

    var buttonTitle: String {
        switch self {
        case .idle:
            return L10n.actionCheckForUpdates
        case .checking:
            return L10n.actionCheckingForUpdates
        case .downloading(_, let progressPercent):
            guard let progressPercent else {
                return L10n.actionDownloadingUpdate
            }

            return L10n.format(
                "İndiriliyor %d%%",
                "Downloading %d%%",
                progressPercent
            )
        case .readyToInstall:
            return L10n.actionRestartToUpdate
        case .upToDate:
            return L10n.actionUpToDate
        case .failed:
            return L10n.actionRetryUpdate
        }
    }

    var buttonIcon: String {
        switch self {
        case .idle:
            return "arrow.down.circle"
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .downloading:
            return "arrow.down.circle.fill"
        case .readyToInstall:
            return "arrow.clockwise.circle.fill"
        case .upToDate:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var isBusy: Bool {
        switch self {
        case .checking, .downloading:
            return true
        default:
            return false
        }
    }

    var helpText: String {
        switch self {
        case .idle:
            return L10n.pair(
                "GitHub sürümlerini kontrol eder ve yeni bir paket varsa indirir.",
                "Checks GitHub releases and downloads a new package when one is available."
            )
        case .checking:
            return L10n.pair(
                "Yeni sürüm olup olmadığı kontrol ediliyor.",
                "Checking whether a newer release is available."
            )
        case .downloading(let version, _):
            return L10n.format(
                "%@ sürümü indiriliyor.",
                "Downloading version %@.",
                version
            )
        case .readyToInstall(let version):
            return L10n.format(
                "%@ indirildi. Kurulumu tamamlamak için uygulamayı yeniden başlat.",
                "%@ is ready. Restart the app to finish installing the update.",
                version
            )
        case .upToDate:
            return L10n.pair(
                "Bu cihazdaki sürüm zaten güncel.",
                "This device is already running the latest version."
            )
        case .failed(let message):
            return message
        }
    }
}

struct AppVersion: Comparable, Equatable {
    let rawValue: String
    let components: [Int]

    init(_ rawValue: String) {
        let trimmed = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^[vV]"#, with: "", options: .regularExpression)

        self.rawValue = trimmed
        self.components = trimmed
            .split(separator: ".")
            .map { segment in
                Int(segment.filter(\.isNumber)) ?? 0
            }
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)

        for index in 0..<maxCount {
            let lhsValue = index < lhs.components.count ? lhs.components[index] : 0
            let rhsValue = index < rhs.components.count ? rhs.components[index] : 0

            if lhsValue != rhsValue {
                return lhsValue < rhsValue
            }
        }

        return false
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

struct GitHubReleaseInfo: Decodable, Equatable {
    struct Asset: Decodable, Equatable {
        let name: String
        let browserDownloadURL: URL
        let size: Int?

        private enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
            case size
        }
    }

    let tagName: String
    let htmlURL: URL?
    let assets: [Asset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }

    var normalizedVersion: String {
        AppVersion(tagName).rawValue
    }

    func primaryAsset(named assetName: String) -> Asset? {
        assets.first { $0.name == assetName }
    }
}

final class AppUpdateService: NSObject, AppUpdateManaging {
    struct Configuration {
        let latestReleaseAPIURL: URL
        let releaseAssetName: String
        let bundleIdentifier: String
        let currentVersion: AppVersion
        let currentBundleURL: URL
        let expectedTeamIdentifier: String?

        static func current(bundle: Bundle = .main) -> Configuration? {
            guard
                let bundleIdentifier = bundle.bundleIdentifier,
                let apiURLString = bundle.object(forInfoDictionaryKey: "STGUpdateLatestReleaseAPIURL") as? String,
                let latestReleaseAPIURL = URL(string: apiURLString)
            else {
                return nil
            }

            let assetName = (bundle.object(forInfoDictionaryKey: "STGUpdateAssetName") as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let versionString = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

            return Configuration(
                latestReleaseAPIURL: latestReleaseAPIURL,
                releaseAssetName: assetName?.isEmpty == false ? assetName! : "ScreenTextGrab.zip",
                bundleIdentifier: bundleIdentifier,
                currentVersion: AppVersion(versionString),
                currentBundleURL: bundle.bundleURL.resolvingSymlinksInPath().standardizedFileURL,
                expectedTeamIdentifier: codeSigningTeamIdentifier(for: bundle.bundleURL)
            )
        }

        fileprivate static func codeSigningTeamIdentifier(for bundleURL: URL) -> String? {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            process.arguments = ["-dv", "--verbose=4", bundleURL.path]

            let pipe = Pipe()
            process.standardError = pipe
            process.standardOutput = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                return nil
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return nil
            }

            return output
                .split(separator: "\n")
                .compactMap { line -> String? in
                    let prefix = "TeamIdentifier="
                    let lineString = String(line)
                    guard lineString.hasPrefix(prefix) else {
                        return nil
                    }

                    let value = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.isEmpty ? nil : value
                }
                .first
        }
    }

    private weak var appState: AppState?
    private let configuration: Configuration
    private let fileManager: FileManager
    private lazy var downloadSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60 * 30
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private var downloadTask: URLSessionDownloadTask?
    private var preparedUpdateRootURL: URL?
    private var preparedAppURL: URL?
    private var latestRelease: GitHubReleaseInfo?
    private var transientResetTask: Task<Void, Never>?

    init?(appState: AppState, configuration: Configuration? = Configuration.current(), fileManager: FileManager = .default) {
        guard let configuration else {
            return nil
        }

        self.appState = appState
        self.configuration = configuration
        self.fileManager = fileManager
        super.init()
    }

    @MainActor
    func performPrimaryUpdateAction() {
        switch appState?.updateState ?? .idle {
        case .readyToInstall:
            installPreparedUpdate()
        case .checking, .downloading:
            break
        case .idle, .upToDate, .failed:
            Task {
                await checkForUpdates()
            }
        }
    }

    @MainActor
    private func checkForUpdates() async {
        transientResetTask?.cancel()
        preparedAppURL = nil
        preparedUpdateRootURL = nil
        latestRelease = nil
        appState?.updateUpdateState(.checking)

        var request = URLRequest(url: configuration.latestReleaseAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ScreenTextGrab", forHTTPHeaderField: "User-Agent")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw UpdateError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw UpdateError.serverStatus(httpResponse.statusCode)
            }

            let release = try JSONDecoder().decode(GitHubReleaseInfo.self, from: data)
            latestRelease = release

            let latestVersion = AppVersion(release.tagName)
            guard latestVersion > configuration.currentVersion else {
                presentUpToDateState()
                return
            }

            guard let asset = release.primaryAsset(named: configuration.releaseAssetName) else {
                throw UpdateError.missingReleaseAsset(configuration.releaseAssetName)
            }

            startDownload(asset: asset, version: release.normalizedVersion)
        } catch {
            fail(with: error)
        }
    }

    @MainActor
    private func startDownload(asset: GitHubReleaseInfo.Asset, version: String) {
        downloadTask?.cancel()
        appState?.updateUpdateState(.downloading(version: version, progressPercent: 0))

        var request = URLRequest(url: asset.browserDownloadURL)
        request.setValue("ScreenTextGrab", forHTTPHeaderField: "User-Agent")
        let task = downloadSession.downloadTask(with: request)
        downloadTask = task
        task.resume()
    }

    @MainActor
    private func presentUpToDateState() {
        appState?.updateUpdateState(.upToDate)
        appState?.appendDiagnostic(
            category: "update",
            message: "No newer release found",
            domain: "AppUpdateService",
            code: nil,
            severity: .info
        )

        transientResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            self?.appState?.updateUpdateState(.idle)
        }
    }

    @MainActor
    private func fail(with error: Error) {
        let wrappedError = (error as? UpdateError) ?? .wrapped(error.localizedDescription)
        STGLog.update.error("App update failed: \(wrappedError.localizedDescription, privacy: .public)")
        appState?.appendDiagnostic(
            category: "update",
            message: wrappedError.localizedDescription,
            domain: "AppUpdateService",
            code: nil,
            severity: .warning
        )
        appState?.updateUpdateState(.failed(message: wrappedError.localizedDescription))
        downloadTask = nil
        preparedAppURL = nil
    }

    @MainActor
    private func finishDownload(from temporaryURL: URL) {
        do {
            let version = latestRelease?.normalizedVersion ?? configuration.currentVersion.rawValue
            let updateRoot = try updateRootURL(for: version)
            let zipURL = updateRoot.appendingPathComponent(configuration.releaseAssetName)
            let extractionURL = updateRoot.appendingPathComponent("extracted", isDirectory: true)

            if fileManager.fileExists(atPath: updateRoot.path) {
                try fileManager.removeItem(at: updateRoot)
            }

            try fileManager.createDirectory(at: extractionURL, withIntermediateDirectories: true)
            try fileManager.copyItem(at: temporaryURL, to: zipURL)
            try runProcess(
                executable: "/usr/bin/ditto",
                arguments: ["-x", "-k", zipURL.path, extractionURL.path]
            )

            guard let extractedAppURL = locateAppBundle(in: extractionURL) else {
                throw UpdateError.extractedAppMissing
            }

            try verifyExtractedApp(at: extractedAppURL)

            preparedUpdateRootURL = updateRoot
            preparedAppURL = extractedAppURL
            appState?.appendDiagnostic(
                category: "update",
                message: "Prepared update \(version)",
                domain: "AppUpdateService",
                code: nil,
                severity: .info
            )
            appState?.updateUpdateState(.readyToInstall(version: version))
            downloadTask = nil
        } catch {
            fail(with: error)
        }
    }

    @MainActor
    private func installPreparedUpdate() {
        guard let preparedAppURL else {
            fail(with: UpdateError.installPreparationMissing)
            return
        }

        do {
            let targetURL = InstalledAppLocator.preferredInstallDestination(
                currentURL: configuration.currentBundleURL,
                bundleIdentifier: configuration.bundleIdentifier
            ) ?? configuration.currentBundleURL

            let scriptURL = try writeInstallerScript(preparedAppURL: preparedAppURL, targetURL: targetURL)
            let launcher = Process()
            launcher.executableURL = URL(fileURLWithPath: "/bin/bash")
            launcher.arguments = [scriptURL.path, "\(ProcessInfo.processInfo.processIdentifier)"]

            try launcher.run()

            appState?.appendDiagnostic(
                category: "update",
                message: "Installing downloaded update",
                domain: "AppUpdateService",
                code: nil,
                severity: .info
            )
            NSApp.terminate(nil)
        } catch {
            fail(with: error)
        }
    }

    private func updateRootURL(for version: String) throws -> URL {
        let baseURL = try fileManager
            .url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            .appendingPathComponent("ScreenTextGrab", isDirectory: true)
            .appendingPathComponent("Updates", isDirectory: true)

        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        return baseURL.appendingPathComponent(version, isDirectory: true)
    }

    private func locateAppBundle(in rootURL: URL) -> URL? {
        let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        while let item = enumerator?.nextObject() as? URL {
            if item.pathExtension.lowercased() == "app" {
                return item
            }
        }

        return nil
    }

    private func verifyExtractedApp(at appURL: URL) throws {
        guard let bundle = Bundle(url: appURL) else {
            throw UpdateError.invalidDownloadedBundle
        }

        let downloadedBundleIdentifier = bundle.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard downloadedBundleIdentifier == configuration.bundleIdentifier else {
            throw UpdateError.bundleIdentifierMismatch
        }

        let downloadedVersion = AppVersion(
            bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        )

        guard downloadedVersion >= configuration.currentVersion else {
            throw UpdateError.olderDownloadedVersion
        }

        if let expectedTeamIdentifier = configuration.expectedTeamIdentifier,
           let downloadedTeamIdentifier = Configuration.codeSigningTeamIdentifier(for: appURL),
           downloadedTeamIdentifier != expectedTeamIdentifier {
            throw UpdateError.signingIdentityMismatch
        }
    }

    private func writeInstallerScript(preparedAppURL: URL, targetURL: URL) throws -> URL {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("screen-text-grab-update-\(UUID().uuidString).sh")

        let backupURL = targetURL.deletingLastPathComponent()
            .appendingPathComponent("\(targetURL.lastPathComponent).backup", isDirectory: true)
        let cleanupRootURL = preparedUpdateRootURL

        let script = """
        #!/bin/bash
        set -euo pipefail

        APP_PID="$1"
        SOURCE_APP=\(shellEscaped(preparedAppURL.path))
        TARGET_APP=\(shellEscaped(targetURL.path))
        BACKUP_APP=\(shellEscaped(backupURL.path))
        CLEANUP_ROOT=\(shellEscaped(cleanupRootURL?.path ?? ""))
        SCRIPT_PATH=\(shellEscaped(scriptURL.path))

        cleanup() {
          if [[ -n "${CLEANUP_ROOT}" && -d "${CLEANUP_ROOT}" ]]; then
            rm -rf "${CLEANUP_ROOT}"
          fi
          rm -f "${SCRIPT_PATH}"
        }

        restore_backup() {
          if [[ -d "${BACKUP_APP}" && ! -d "${TARGET_APP}" ]]; then
            mv "${BACKUP_APP}" "${TARGET_APP}"
          fi
        }

        trap restore_backup ERR

        while kill -0 "${APP_PID}" >/dev/null 2>&1; do
          sleep 0.2
        done

        rm -rf "${BACKUP_APP}"
        if [[ -d "${TARGET_APP}" ]]; then
          mv "${TARGET_APP}" "${BACKUP_APP}"
        fi

        /usr/bin/ditto "${SOURCE_APP}" "${TARGET_APP}"
        rm -rf "${BACKUP_APP}"
        /usr/bin/open "${TARGET_APP}"
        cleanup
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try runProcess(executable: "/bin/chmod", arguments: ["755", scriptURL.path])
        return scriptURL
    }

    private func runProcess(executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw UpdateError.processFailed(message?.isEmpty == false ? message! : executable)
        }
    }

    private func shellEscaped(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}

extension AppUpdateService: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            let progress: Int?
            if totalBytesExpectedToWrite > 0 {
                let normalized = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                progress = max(0, min(100, Int((normalized * 100).rounded())))
            } else {
                progress = nil
            }

            let version = self.latestRelease?.normalizedVersion ?? self.configuration.currentVersion.rawValue
            self.appState?.updateUpdateState(.downloading(version: version, progressPercent: progress))
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task { @MainActor [weak self] in
            self?.finishDownload(from: location)
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else {
            return
        }

        Task { @MainActor [weak self] in
            self?.fail(with: error)
        }
    }
}

private enum UpdateError: LocalizedError {
    case invalidResponse
    case serverStatus(Int)
    case missingReleaseAsset(String)
    case extractedAppMissing
    case invalidDownloadedBundle
    case bundleIdentifierMismatch
    case olderDownloadedVersion
    case signingIdentityMismatch
    case installPreparationMissing
    case processFailed(String)
    case wrapped(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return L10n.pair("Güncelleme sunucusundan geçersiz bir yanıt alındı.", "The update server returned an invalid response.")
        case .serverStatus(let statusCode):
            return L10n.format(
                "Güncelleme isteği başarısız oldu (%d).",
                "The update request failed (%d).",
                statusCode
            )
        case .missingReleaseAsset(let assetName):
            return L10n.format(
                "%@ paketi son sürümde bulunamadı.",
                "The latest release does not contain %@.",
                assetName
            )
        case .extractedAppMissing:
            return L10n.pair("İndirilen arşivin içinde uygulama bulunamadı.", "The downloaded archive did not contain an app bundle.")
        case .invalidDownloadedBundle:
            return L10n.pair("İndirilen uygulama paketi açılamadı.", "The downloaded app bundle could not be opened.")
        case .bundleIdentifierMismatch:
            return L10n.pair("İndirilen paket farklı bir uygulamaya ait görünüyor.", "The downloaded package appears to belong to a different app.")
        case .olderDownloadedVersion:
            return L10n.pair("İndirilen sürüm mevcut uygulamadan daha eski.", "The downloaded version is older than the installed app.")
        case .signingIdentityMismatch:
            return L10n.pair("İndirilen güncellemenin imzası mevcut uygulamayla eşleşmiyor.", "The downloaded update was signed by a different identity.")
        case .installPreparationMissing:
            return L10n.pair("Kurulmaya hazır bir güncelleme bulunamadı.", "No downloaded update is ready to install.")
        case .processFailed(let message):
            return L10n.format(
                "Güncelleme aracı çalıştırılamadı: %@",
                "The update helper failed: %@",
                message
            )
        case .wrapped(let message):
            return message
        }
    }
}
