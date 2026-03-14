import XCTest

final class ScreenTextGrabUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchPanelShowsPrimaryCaptureAction() {
        let app = launchPanelApp()
        XCTAssertTrue(waitForStartCaptureButton(in: app).exists)
    }

    func testLaunchPanelShowsPermissionGuidanceWhenPermissionMissing() {
        let app = launchPanelApp(additionalArguments: ["--ui-test-permission-denied"])
        XCTAssertTrue(permissionHint(in: app).waitForExistence(timeout: 5))
    }

    func testLaunchPanelDisablesCaptureWhenPermissionMissing() {
        let app = launchPanelApp(additionalArguments: ["--ui-test-permission-denied"])
        let startCaptureButton = waitForStartCaptureButton(in: app)
        XCTAssertFalse(startCaptureButton.isEnabled)
    }

    func testLaunchPanelShowsRestartGuidanceWhenPermissionRequiresRestart() {
        let app = launchPanelApp(additionalArguments: ["--ui-test-permission-requires-restart"])
        let permissionHint = permissionHint(in: app)

        XCTAssertTrue(permissionHint.waitForExistence(timeout: 5))
        let hintText = (permissionHint.value as? String) ?? permissionHint.label
        XCTAssertTrue(hintText.localizedCaseInsensitiveContains("yeniden başlat"))
    }

    func testLaunchPanelDisablesCaptureWhileWatchModeIsActive() {
        let app = launchPanelApp(additionalArguments: ["--ui-test-watch-active"])
        let startCaptureButton = waitForStartCaptureButton(in: app)
        XCTAssertFalse(startCaptureButton.isEnabled)
    }

    @discardableResult
    private func launchPanelApp(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
            XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
        }

        app.launchArguments = ["--ui-test-launch-panel"] + additionalArguments
        app.launch()
        XCTAssertTrue(waitForLaunch(of: app, timeout: 10))
        app.activate()
        return app
    }

    private func waitForStartCaptureButton(in app: XCUIApplication, timeout: TimeInterval = 8) -> XCUIElement {
        let button = startCaptureButton(in: app)
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if button.exists {
                return button
            }

            app.activate()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }

        XCTAssertTrue(button.waitForExistence(timeout: 1))
        return button
    }

    private func permissionHint(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["launch-panel-permission-hint"]
    }

    private func startCaptureButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons["launch-panel-start-capture"]
    }

    private func waitForLaunch(of app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            switch app.state {
            case .runningForeground, .runningBackground:
                return true
            default:
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            }
        }

        return false
    }
}
