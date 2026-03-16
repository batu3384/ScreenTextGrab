import Foundation
import ServiceManagement

enum LaunchAtLoginError: LocalizedError, Equatable {
    case unavailable
    case updateFailed(description: String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return L10n.pair("Bu seçenek yalnızca kurulu ve imzalı uygulama kopyasında kullanılabilir.", "This option is only available in an installed and signed app copy.")
        case .updateFailed(let description):
            return L10n.format("Açılışta başlatma ayarı güncellenemedi: %@", "Launch at login could not be updated: %@", description)
        }
    }
}

enum LaunchAtLoginState: Equatable, Sendable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable

    var toggleIsOn: Bool {
        self == .enabled || self == .requiresApproval
    }

    var title: String {
        switch self {
        case .enabled:
            return L10n.pair("Açık", "On")
        case .disabled:
            return L10n.pair("Kapalı", "Off")
        case .requiresApproval:
            return L10n.pair("Onay Bekliyor", "Approval Needed")
        case .unavailable:
            return L10n.pair("Kullanılamıyor", "Unavailable")
        }
    }

    var detail: String {
        switch self {
        case .enabled:
            return L10n.pair("Uygulama bilgisayar açıldığında otomatik başlatılacak.", "The app will start automatically when your Mac turns on.")
        case .disabled:
            return L10n.pair("İstersen uygulamayı oturum açılışında otomatik başlatabilirsin.", "You can start the app automatically when you log in.")
        case .requiresApproval:
            return L10n.pair("macOS ek onay bekliyor. Giriş Öğeleri bölümünden durumu kontrol etmen gerekebilir.", "macOS is waiting for an extra approval. You may need to check Login Items.")
        case .unavailable:
            return L10n.pair("Bu özellik yalnızca kurulu ve imzalı uygulama kopyasında çalışır.", "This feature only works in an installed and signed app copy.")
        }
    }

    var cliValue: String {
        switch self {
        case .enabled:
            return "enabled"
        case .disabled:
            return "disabled"
        case .requiresApproval:
            return "requires-approval"
        case .unavailable:
            return "unavailable"
        }
    }
}

@MainActor
protocol LaunchAtLoginManaging: AnyObject {
    var launchAtLoginState: LaunchAtLoginState { get }
    func refreshLaunchAtLoginState() -> LaunchAtLoginState
    func setLaunchAtLogin(enabled: Bool) async throws -> LaunchAtLoginState
    func openLoginItemsSettings()
}

protocol LaunchAtLoginAppServicing {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LaunchAtLoginAppServicing {}

final class LaunchAtLoginService {
    private static let registrationStampKey = "ScreenTextGrabLaunchAtLoginRegistrationStamp"
    private static let pollingDelayNanoseconds: UInt64 = 80_000_000

    private let service: any LaunchAtLoginAppServicing
    private let defaults: UserDefaults
    private let bundle: Bundle
    private let sleepHandler: @Sendable (UInt64) async -> Void

    init(
        service: any LaunchAtLoginAppServicing = SMAppService.mainApp,
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        sleepHandler: @escaping @Sendable (UInt64) async -> Void = { nanoseconds in
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.service = service
        self.defaults = defaults
        self.bundle = bundle
        self.sleepHandler = sleepHandler
    }

    func refreshState() -> LaunchAtLoginState {
        Self.map(service.status, isInstalledApp: isInstalledApp)
    }

    func bootstrapState() async -> LaunchAtLoginState {
        let state = refreshState()
        guard state.toggleIsOn, needsRegistrationRefresh else {
            return state
        }

        do {
            try unregisterForRefreshIfNeeded()
            try service.register()
            let refreshedState = await waitForExpectedState(enabled: true)
            syncPersistedRegistrationStamp(for: refreshedState)
            STGLog.lifecycle.info("Launch at login registration refreshed; state=\(refreshedState.title, privacy: .public)")
            return refreshedState
        } catch {
            STGLog.lifecycle.error("Launch at login refresh failed: \(error.localizedDescription, privacy: .public)")
            let refreshedState = refreshState()
            syncPersistedRegistrationStamp(for: refreshedState)
            return refreshedState
        }
    }

    func setEnabled(_ enabled: Bool) async throws -> LaunchAtLoginState {
        let currentState = refreshState()
        if enabled, currentState == .unavailable, !isInstalledApp {
            throw LaunchAtLoginError.unavailable
        }

        do {
            if enabled {
                try unregisterForRefreshIfNeeded()
                try service.register()
                STGLog.lifecycle.info("Launch at login enable request sent")
            } else {
                try unregisterIfRegistered()
                STGLog.lifecycle.info("Launch at login disable request sent")
            }
        } catch {
            STGLog.lifecycle.error("Launch at login update failed: \(error.localizedDescription, privacy: .public)")
            throw LaunchAtLoginError.updateFailed(description: error.localizedDescription)
        }

        let refreshedState = await waitForExpectedState(enabled: enabled)
        syncPersistedRegistrationStamp(for: refreshedState)
        return refreshedState
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    static func map(_ status: SMAppService.Status, isInstalledApp: Bool = false) -> LaunchAtLoginState {
        switch status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return isInstalledApp ? .disabled : .unavailable
        @unknown default:
            return .unavailable
        }
    }

    private var isInstalledApp: Bool {
        InstalledAppLocator.isInstalledAppURL(bundle.bundleURL)
    }

    private var needsRegistrationRefresh: Bool {
        persistedRegistrationStamp != currentRegistrationStamp
    }

    private var persistedRegistrationStamp: String? {
        defaults.string(forKey: Self.registrationStampKey)
    }

    private var currentRegistrationStamp: String? {
        guard let executableURL = bundle.executableURL else {
            return nil
        }

        let version = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"
        let modificationDate = try? executableURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        let timestamp = modificationDate?.timeIntervalSince1970 ?? 0
        return "\(version)-\(Int(timestamp))"
    }

    private func persistCurrentRegistrationStamp() {
        guard let currentRegistrationStamp else { return }
        defaults.set(currentRegistrationStamp, forKey: Self.registrationStampKey)
    }

    private func clearPersistedRegistrationStamp() {
        defaults.removeObject(forKey: Self.registrationStampKey)
    }

    private func syncPersistedRegistrationStamp(for state: LaunchAtLoginState) {
        if state.toggleIsOn {
            persistCurrentRegistrationStamp()
        } else {
            clearPersistedRegistrationStamp()
        }
    }

    private func unregisterIgnoringMissing() throws {
        do {
            try service.unregister()
        } catch {
            let nsError = error as NSError
            if nsError.code == Int(kSMErrorJobNotFound) {
                return
            }
            throw error
        }
    }

    private func unregisterForRefreshIfNeeded() throws {
        let state = refreshState()
        guard state.toggleIsOn else {
            return
        }

        try unregisterIgnoringMissing()
    }

    private func unregisterIfRegistered() throws {
        let state = refreshState()
        guard state.toggleIsOn else {
            return
        }

        try unregisterIgnoringMissing()
    }

    private func waitForExpectedState(enabled: Bool) async -> LaunchAtLoginState {
        var lastKnownState = refreshState()

        for attempt in 0..<4 {
            if enabled {
                if lastKnownState.toggleIsOn {
                    return lastKnownState
                }
            } else if !lastKnownState.toggleIsOn {
                return lastKnownState
            }

            if attempt < 3 {
                await sleepHandler(Self.pollingDelayNanoseconds)
                lastKnownState = refreshState()
            }
        }

        return lastKnownState
    }
}
