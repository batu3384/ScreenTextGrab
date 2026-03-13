import ServiceManagement
import XCTest
@testable import ScreenTextGrab

final class LaunchAtLoginServiceTests: XCTestCase {
    func testRefreshStateMapsEnabledStatus() {
        let service = MockLaunchAtLoginAppService(status: .enabled)
        let sut = LaunchAtLoginService(service: service)

        XCTAssertEqual(sut.refreshState(), .enabled)
    }

    func testSetEnabledRegistersService() async throws {
        let service = MockLaunchAtLoginAppService(status: .notRegistered)
        let sut = makeSut(service: service)

        let state = try await sut.setEnabled(true)

        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(state, .enabled)
    }

    func testSetEnabledRefreshesExistingRegistrationWhenAlreadyEnabled() async throws {
        let service = MockLaunchAtLoginAppService(status: .enabled)
        let sut = makeSut(service: service)

        let state = try await sut.setEnabled(true)

        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(state, .enabled)
    }

    func testSetDisabledUnregistersService() async throws {
        let service = MockLaunchAtLoginAppService(status: .enabled)
        let sut = makeSut(service: service)

        let state = try await sut.setEnabled(false)

        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(state, .disabled)
    }

    func testUnavailableStateThrowsFriendlyErrorWhenEnableRequested() async {
        let service = MockLaunchAtLoginAppService(status: .notFound)
        let sut = makeSut(service: service)

        await XCTAssertThrowsErrorAsync(try await sut.setEnabled(true)) { error in
            XCTAssertEqual(error as? LaunchAtLoginError, .unavailable)
        }
    }

    func testRegisterFailureIsWrapped() async {
        let service = MockLaunchAtLoginAppService(status: .notRegistered)
        service.registerError = NSError(domain: "LaunchAtLoginTests", code: 17, userInfo: [NSLocalizedDescriptionKey: "no permission"])
        let sut = makeSut(service: service)

        await XCTAssertThrowsErrorAsync(try await sut.setEnabled(true)) { error in
            XCTAssertEqual(
                error as? LaunchAtLoginError,
                .updateFailed(description: "no permission")
            )
        }
    }

    func testRequiresApprovalKeepsToggleOn() {
        XCTAssertTrue(LaunchAtLoginState.requiresApproval.toggleIsOn)
        XCTAssertTrue(LaunchAtLoginState.enabled.toggleIsOn)
        XCTAssertFalse(LaunchAtLoginState.disabled.toggleIsOn)
    }

    func testCLIValueUsesStableMachineReadableTokens() {
        XCTAssertEqual(LaunchAtLoginState.enabled.cliValue, "enabled")
        XCTAssertEqual(LaunchAtLoginState.disabled.cliValue, "disabled")
        XCTAssertEqual(LaunchAtLoginState.requiresApproval.cliValue, "requires-approval")
        XCTAssertEqual(LaunchAtLoginState.unavailable.cliValue, "unavailable")
    }

    func testSetEnabledReturnsActualStateWhenStatusDoesNotChange() async throws {
        let service = MockLaunchAtLoginAppService(status: .notRegistered)
        service.updatesStatusOnRegister = false
        let sut = makeSut(service: service)

        let state = try await sut.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(state, .disabled)
    }

    func testSetDisabledReturnsActualStateWhenServiceStaysEnabled() async throws {
        let service = MockLaunchAtLoginAppService(status: .enabled)
        service.updatesStatusOnUnregister = false
        let sut = makeSut(service: service)

        let state = try await sut.setEnabled(false)

        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(state, .enabled)
    }
}

private func makeSut(service: MockLaunchAtLoginAppService) -> LaunchAtLoginService {
    LaunchAtLoginService(service: service, sleepHandler: { _ in })
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ handler: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown", file: file, line: line)
    } catch {
        handler(error)
    }
}

private final class MockLaunchAtLoginAppService: LaunchAtLoginAppServicing {
    var status: SMAppService.Status
    var registerError: Error?
    var unregisterError: Error?
    var updatesStatusOnRegister = true
    var updatesStatusOnUnregister = true
    var registerCallCount = 0
    var unregisterCallCount = 0

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
        if updatesStatusOnRegister {
            status = .enabled
        }
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError {
            throw unregisterError
        }
        if updatesStatusOnUnregister {
            status = .notRegistered
        }
    }
}
