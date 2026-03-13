import XCTest
@testable import ScreenTextGrab

final class ScreenPermissionServiceTests: XCTestCase {
    @MainActor
    func testRequestIfNeededSkipsPromptWhenPreflightAlreadyGranted() async {
        let requestCounter = Counter()
        let probeCounter = Counter()
        let service = ScreenPermissionService(
            preflightProvider: { true },
            accessRequester: {
                requestCounter.count += 1
                return true
            },
            probeHandler: {
                probeCounter.count += 1
                return .granted
            },
            sleepHandler: { _ in },
            probeRetryDelaysNanoseconds: [0]
        )

        let state = await service.requestIfNeeded()

        XCTAssertEqual(state, .granted)
        XCTAssertEqual(requestCounter.count, 0)
        XCTAssertEqual(probeCounter.count, 0)
    }

    @MainActor
    func testResolveStateUsesProbeWhenPreflightIsFalse() async {
        let probeCounter = Counter()
        let service = ScreenPermissionService(
            preflightProvider: { false },
            accessRequester: { false },
            probeHandler: {
                probeCounter.count += 1
                return .granted
            },
            sleepHandler: { _ in },
            probeRetryDelaysNanoseconds: [0]
        )

        let state = await service.resolveState()

        XCTAssertEqual(state, .granted)
        XCTAssertEqual(probeCounter.count, 1)
    }

    @MainActor
    func testRequestIfNeededReturnsRequiresRestartWhenPromptSucceedsButAccessStillUnavailable() async {
        let requestCounter = Counter()
        let service = ScreenPermissionService(
            preflightProvider: { false },
            accessRequester: {
                requestCounter.count += 1
                return true
            },
            probeHandler: { .denied },
            sleepHandler: { _ in },
            probeRetryDelaysNanoseconds: [0]
        )

        let state = await service.requestIfNeeded()

        XCTAssertEqual(state, .requiresRestart)
        XCTAssertEqual(requestCounter.count, 1)
        XCTAssertTrue(service.needsRestartAfterGrant)
    }

    @MainActor
    func testResolveStateRetriesProbeAndEventuallyReturnsGranted() async {
        let probeCounter = Counter()
        let service = ScreenPermissionService(
            preflightProvider: { false },
            accessRequester: { false },
            probeHandler: {
                probeCounter.count += 1
                return probeCounter.count < 3 ? .unknown : .granted
            },
            sleepHandler: { _ in },
            probeRetryDelaysNanoseconds: [0, 0, 0]
        )

        let state = await service.resolveState()

        XCTAssertEqual(state, .granted)
        XCTAssertEqual(probeCounter.count, 3)
    }

    @MainActor
    func testResolveStateReturnsUnknownWhenGrantCanNoLongerBeConfirmed() async {
        let clock = MutableDate()
        let preflightGranted = MutableFlag(true)
        let service = ScreenPermissionService(
            preflightProvider: { preflightGranted.value },
            accessRequester: { false },
            probeHandler: { .unknown },
            nowProvider: { clock.value },
            sleepHandler: { _ in },
            probeRetryDelaysNanoseconds: [0]
        )

        let initialState = await service.resolveState()
        XCTAssertEqual(initialState, .granted)

        preflightGranted.value = false
        clock.value = clock.value.addingTimeInterval(5)

        let state = await service.resolveState()

        XCTAssertEqual(state, .unknown)
    }

    @MainActor
    func testResolveStateDoesNotMaskExplicitDenialAfterRecentGrant() async {
        let clock = MutableDate()
        let preflightGranted = MutableFlag(true)
        let service = ScreenPermissionService(
            preflightProvider: { preflightGranted.value },
            accessRequester: { false },
            probeHandler: { .denied },
            nowProvider: { clock.value },
            sleepHandler: { _ in },
            probeRetryDelaysNanoseconds: [0]
        )

        let initialState = await service.resolveState()
        XCTAssertEqual(initialState, .granted)

        preflightGranted.value = false
        clock.value = clock.value.addingTimeInterval(5)

        let state = await service.resolveState()

        XCTAssertEqual(state, .denied)
    }

    @MainActor
    func testResolveStartupStateRequestsPermissionOnlyOnceBeforeGrant() async {
        let defaults = makeIsolatedDefaults()
        let requestCounter = Counter()

        let firstService = ScreenPermissionService(
            preflightProvider: { false },
            accessRequester: {
                requestCounter.count += 1
                return false
            },
            probeHandler: { .denied },
            defaults: defaults,
            persistsPermissionPreferences: true,
            sleepHandler: { _ in },
            probeRetryDelaysNanoseconds: [0]
        )

        let firstState = await firstService.resolveStartupState(isForegroundLaunch: true)
        XCTAssertEqual(firstState, .denied)
        XCTAssertEqual(requestCounter.count, 1)

        let secondService = ScreenPermissionService(
            preflightProvider: { false },
            accessRequester: {
                requestCounter.count += 1
                return false
            },
            probeHandler: { .denied },
            defaults: defaults,
            persistsPermissionPreferences: true,
            sleepHandler: { _ in },
            probeRetryDelaysNanoseconds: [0]
        )

        let secondState = await secondService.resolveStartupState(isForegroundLaunch: true)
        XCTAssertEqual(secondState, .denied)
        XCTAssertEqual(requestCounter.count, 1)
    }

    @MainActor
    func testResolveStartupStateRePromptsAfterPreviouslyGrantedPermissionIsRevoked() async {
        let defaults = makeIsolatedDefaults()
        let requestCounter = Counter()

        let grantedService = ScreenPermissionService(
            preflightProvider: { false },
            accessRequester: {
                requestCounter.count += 1
                return true
            },
            probeHandler: { .denied },
            defaults: defaults,
            persistsPermissionPreferences: true,
            sleepHandler: { _ in },
            probeRetryDelaysNanoseconds: [0]
        )

        let grantedState = await grantedService.resolveStartupState(isForegroundLaunch: true)
        XCTAssertEqual(grantedState, .requiresRestart)
        XCTAssertEqual(requestCounter.count, 1)

        let revokedService = ScreenPermissionService(
            preflightProvider: { false },
            accessRequester: { false },
            probeHandler: { .denied },
            defaults: defaults,
            persistsPermissionPreferences: true,
            sleepHandler: { _ in },
            probeRetryDelaysNanoseconds: [0]
        )

        let revokedState = await revokedService.resolveState()
        XCTAssertEqual(revokedState, .denied)

        let promptAgainService = ScreenPermissionService(
            preflightProvider: { false },
            accessRequester: {
                requestCounter.count += 1
                return false
            },
            probeHandler: { .denied },
            defaults: defaults,
            persistsPermissionPreferences: true,
            sleepHandler: { _ in },
            probeRetryDelaysNanoseconds: [0]
        )

        let promptAgainState = await promptAgainService.resolveStartupState(isForegroundLaunch: true)
        XCTAssertEqual(promptAgainState, .denied)
        XCTAssertEqual(requestCounter.count, 2)
    }
}

private final class Counter: @unchecked Sendable {
    var count = 0
}

private final class MutableFlag: @unchecked Sendable {
    var value: Bool

    init(_ value: Bool) {
        self.value = value
    }
}

private final class MutableDate: @unchecked Sendable {
    var value = Date(timeIntervalSince1970: 1_000)
}

private func makeIsolatedDefaults() -> UserDefaults {
    let suiteName = "ScreenPermissionServiceTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        fatalError("Failed to create isolated defaults suite")
    }
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
