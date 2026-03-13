import AppKit
import CoreGraphics
import ScreenCaptureKit

protocol ScreenPermissionProviding: AnyObject {
    @MainActor var needsRestartAfterGrant: Bool { get }
    @MainActor func refreshPreflight() -> ScreenPermissionState
    @MainActor func resolveState() async -> ScreenPermissionState
    @MainActor func requestIfNeeded() async -> ScreenPermissionState
    @MainActor func diagnosticSnapshot() async -> PermissionDiagnosticSnapshot
    @MainActor func openSystemSettings()
}

final class ScreenPermissionService: ScreenPermissionProviding {
    typealias PreflightProvider = @Sendable () -> Bool
    typealias AccessRequester = @Sendable () async -> Bool
    typealias ProbeHandler = @Sendable () async -> ScreenPermissionState
    typealias SettingsOpener = @MainActor () -> Void
    typealias NowProvider = @Sendable () -> Date
    typealias SleepHandler = @Sendable (_ nanoseconds: UInt64) async -> Void

    private(set) var needsRestartAfterGrant: Bool = false
    private var isRequestInProgress = false
    private var lastConfirmedGrantAt: Date?
    private var lastProbeState: ScreenPermissionState = .unknown
    private var lastProbeAt: Date?
    private var lastResolvedState: ScreenPermissionState = .unknown
    private let preflightProvider: PreflightProvider
    private let accessRequester: AccessRequester
    private let probeHandler: ProbeHandler
    private let settingsOpener: SettingsOpener
    private let nowProvider: NowProvider
    private let sleepHandler: SleepHandler
    private let probeRetryDelaysNanoseconds: [UInt64]
    private let defaults: UserDefaults
    private let persistsPermissionPreferences: Bool

    init(
        preflightProvider: @escaping PreflightProvider = { CGPreflightScreenCaptureAccess() },
        accessRequester: @escaping AccessRequester = { await ScreenPermissionService.requestScreenCaptureAccess() },
        probeHandler: @escaping ProbeHandler = { await ScreenPermissionService.defaultProbeScreenCaptureKitAccess() },
        settingsOpener: @escaping SettingsOpener = { ScreenPermissionService.defaultOpenSystemSettings() },
        nowProvider: @escaping NowProvider = { Date() },
        defaults: UserDefaults = .standard,
        persistsPermissionPreferences: Bool = ScreenPermissionService.shouldPersistPermissionPreferences,
        sleepHandler: @escaping SleepHandler = { nanoseconds in
            try? await Task.sleep(nanoseconds: nanoseconds)
        },
        probeRetryDelaysNanoseconds: [UInt64] = [0, 250_000_000, 800_000_000]
    ) {
        self.preflightProvider = preflightProvider
        self.accessRequester = accessRequester
        self.probeHandler = probeHandler
        self.settingsOpener = settingsOpener
        self.nowProvider = nowProvider
        self.defaults = defaults
        self.persistsPermissionPreferences = persistsPermissionPreferences
        self.sleepHandler = sleepHandler
        self.probeRetryDelaysNanoseconds = probeRetryDelaysNanoseconds
    }

    @MainActor
    func refreshPreflight() -> ScreenPermissionState {
        if isRequestInProgress {
            return .requestInProgress
        }

        if preflightProvider() {
            recordGrantedEvidence()
            lastResolvedState = .granted
            persistResolvedState(.granted)
            return .granted
        }

        if needsRestartAfterGrant {
            lastResolvedState = .requiresRestart
            persistResolvedState(.requiresRestart)
            return .requiresRestart
        }

        lastResolvedState = .unknown
        persistResolvedState(.unknown)
        return .unknown
    }

    @MainActor
    func resolveState() async -> ScreenPermissionState {
        let preflight = refreshPreflight()

        if preflight == .granted || preflight == .requestInProgress || preflight == .requiresRestart {
            return preflight
        }

        let probe = await probeWithRetries()
        switch probe {
        case .granted:
            recordGrantedEvidence()
            lastResolvedState = .granted
            persistResolvedState(.granted)
            return .granted
        case .denied:
            let resolvedState: ScreenPermissionState = needsRestartAfterGrant ? .requiresRestart : .denied
            lastResolvedState = resolvedState
            persistResolvedState(resolvedState)
            return resolvedState
        case .unknown:
            let resolvedState: ScreenPermissionState = needsRestartAfterGrant ? .requiresRestart : .unknown
            lastResolvedState = resolvedState
            persistResolvedState(resolvedState)
            return resolvedState
        case .requestInProgress:
            lastResolvedState = .requestInProgress
            persistResolvedState(.requestInProgress)
            return .requestInProgress
        case .requiresRestart:
            lastResolvedState = .requiresRestart
            persistResolvedState(.requiresRestart)
            return .requiresRestart
        }
    }

    @MainActor
    func resolveStartupState(isForegroundLaunch: Bool) async -> ScreenPermissionState {
        let resolvedState = await resolveState()
        guard shouldAutoRequestOnLaunch(isForegroundLaunch: isForegroundLaunch, currentState: resolvedState) else {
            return resolvedState
        }

        defaults.set(true, forKey: Self.autoPromptAttemptedKey)
        return await requestIfNeeded()
    }

    @MainActor
    func requestIfNeeded() async -> ScreenPermissionState {
        guard !isRequestInProgress else {
            return .requestInProgress
        }

        let resolvedBeforePrompt = await resolveState()
        if resolvedBeforePrompt == .granted || resolvedBeforePrompt == .requiresRestart {
            return resolvedBeforePrompt
        }

        isRequestInProgress = true
        STGLog.permission.info("Screen capture permission request started")

        let granted = await accessRequester()
        isRequestInProgress = false

        let resolvedAfterRequest = await resolveState()
        switch resolvedAfterRequest {
        case .granted, .requiresRestart:
            return resolvedAfterRequest
        case .requestInProgress:
            lastResolvedState = .requestInProgress
            persistResolvedState(.requestInProgress)
            return .requestInProgress
        case .denied, .unknown:
            if granted {
                recordRestartRequiredAfterGrant()
                STGLog.permission.info("Permission granted; app restart required before capture can continue")
                lastResolvedState = .requiresRestart
                persistResolvedState(.requiresRestart)
                return .requiresRestart
            }

            clearGrantedEvidence()
            STGLog.permission.warning("Permission denied by user")
            lastResolvedState = .denied
            persistResolvedState(.denied)
            return .denied
        }
    }

    @MainActor
    func diagnosticSnapshot() async -> PermissionDiagnosticSnapshot {
        let resolvedState = await resolveState()
        let preflightGranted = preflightProvider()
        let effectiveProbeState = preflightGranted ? .granted : lastProbeState
        let bundle = Bundle.main

        return PermissionDiagnosticSnapshot(
            timestamp: nowProvider(),
            currentState: resolvedState,
            preflightGranted: preflightGranted,
            probeState: effectiveProbeState,
            needsRestartAfterGrant: needsRestartAfterGrant,
            lastConfirmedGrantAt: lastConfirmedGrantAt,
            lastProbeAt: lastProbeAt,
            bundleIdentifier: bundle.bundleIdentifier ?? "n/a",
            appPath: bundle.bundleURL.path,
            marketingVersion: (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "n/a",
            buildVersion: (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "n/a"
        )
    }

    @MainActor
    private func probeWithRetries() async -> ScreenPermissionState {
        var lastState: ScreenPermissionState = .unknown

        for (index, delay) in probeRetryDelaysNanoseconds.enumerated() {
            if index > 0 && delay > 0 {
                await sleepHandler(delay)
            }

            let state = await probeHandler()
            lastState = state
            lastProbeState = state
            lastProbeAt = nowProvider()

            switch state {
            case .granted, .requestInProgress, .requiresRestart:
                return state
            case .denied, .unknown:
                continue
            }
        }

        return lastState
    }

    @MainActor
    private func recordGrantedEvidence() {
        needsRestartAfterGrant = false
        lastConfirmedGrantAt = nowProvider()
    }

    @MainActor
    private func recordRestartRequiredAfterGrant() {
        lastConfirmedGrantAt = nowProvider()
        needsRestartAfterGrant = true
    }

    @MainActor
    private func clearGrantedEvidence() {
        needsRestartAfterGrant = false
        lastConfirmedGrantAt = nil
    }

    @MainActor
    private func shouldAutoRequestOnLaunch(
        isForegroundLaunch: Bool,
        currentState: ScreenPermissionState
    ) -> Bool {
        guard persistsPermissionPreferences, isForegroundLaunch else {
            return false
        }

        switch currentState {
        case .granted, .requiresRestart, .requestInProgress:
            return false
        case .denied, .unknown:
            return defaults.bool(forKey: Self.autoPromptAttemptedKey) == false
        }
    }

    @MainActor
    private func persistResolvedState(_ state: ScreenPermissionState) {
        guard persistsPermissionPreferences else {
            return
        }

        let previouslyGranted = defaults.bool(forKey: Self.permissionPreviouslyGrantedKey)

        switch state {
        case .granted, .requiresRestart:
            defaults.set(true, forKey: Self.autoPromptAttemptedKey)
            defaults.set(true, forKey: Self.permissionPreviouslyGrantedKey)
        case .denied, .unknown:
            if previouslyGranted {
                defaults.set(false, forKey: Self.autoPromptAttemptedKey)
                defaults.set(false, forKey: Self.permissionPreviouslyGrantedKey)
            }
        case .requestInProgress:
            break
        }
    }

    @MainActor
    func openSystemSettings() {
        settingsOpener()
    }

    nonisolated
    private static func requestScreenCaptureAccess() async -> Bool {
        await Task.detached(priority: .userInitiated) {
            CGRequestScreenCaptureAccess()
        }.value
    }

    private static func defaultProbeScreenCaptureKitAccess() async -> ScreenPermissionState {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            STGLog.permission.info("ScreenCaptureKit probe succeeded; access granted")
            return .granted
        } catch {
            let nsError = error as NSError
            if Self.isPermissionError(nsError) {
                STGLog.permission.warning("ScreenCaptureKit probe denied: \(nsError.localizedDescription, privacy: .public)")
                return .denied
            }

            STGLog.permission.error("ScreenCaptureKit probe returned unknown error: \(nsError.localizedDescription, privacy: .public)")
            return .unknown
        }
    }

    @MainActor
    private static func defaultOpenSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private static func isPermissionError(_ error: NSError) -> Bool {
        if matchesPermissionDomain(error) {
            return true
        }

        if containsPermissionSignal(in: error.localizedDescription) {
            return true
        }

        if let reason = error.localizedFailureReason, containsPermissionSignal(in: reason) {
            return true
        }

        if let suggestion = error.localizedRecoverySuggestion, containsPermissionSignal(in: suggestion) {
            return true
        }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isPermissionError(underlying)
        }

        return false
    }

    private static func matchesPermissionDomain(_ error: NSError) -> Bool {
        let lowercasedDomain = error.domain.lowercased()
        if lowercasedDomain.contains("screencapturekit") {
            return error.code == -3801 || error.code == 7 || error.code == 1
        }

        return false
    }

    private static func containsPermissionSignal(in message: String) -> Bool {
        let normalized = message.lowercased()
        let keywords = [
            "permission",
            "not authorized",
            "not permitted",
            "denied",
            "privacy",
            "screen recording",
            "screen capture",
            "tcc"
        ]
        return keywords.contains(where: normalized.contains)
    }

    private static var shouldPersistPermissionPreferences: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }

    private static let autoPromptAttemptedKey = "screenPermission.autoPromptAttempted"
    private static let permissionPreviouslyGrantedKey = "screenPermission.previouslyGranted"
}
