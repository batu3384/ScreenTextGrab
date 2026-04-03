import XCTest

final class ScreenTextGrabUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMenuPanelPreviewLaunches() {
        let app = previewApp(argument: "--screenshot-menu-panel")
        XCTAssertTrue(waitForPreviewWindow(in: app).exists)
    }

    func testSettingsGeneralPreviewLaunches() {
        let app = previewApp(argument: "--screenshot-settings-general")
        XCTAssertTrue(waitForPreviewWindow(in: app).exists)
    }

    func testSettingsOCRPreviewLaunches() {
        let app = previewApp(argument: "--screenshot-settings-ocr")
        XCTAssertTrue(waitForPreviewWindow(in: app).exists)
    }

    func testSettingsDiagnosticsPreviewLaunches() {
        let app = previewApp(argument: "--screenshot-settings-diagnostics")
        XCTAssertTrue(waitForPreviewWindow(in: app).exists)
    }

    func testSettingsHistoryPreviewLaunches() {
        let app = previewApp(argument: "--screenshot-settings-history")
        XCTAssertTrue(waitForPreviewWindow(in: app).exists)
    }

    func testTableReviewPreviewLaunches() {
        let app = previewApp(argument: "--screenshot-table-review")
        XCTAssertTrue(waitForPreviewWindow(in: app).exists)
    }

    @discardableResult
    private func previewApp(argument: String) -> XCUIApplication {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
            XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
        }

        app.launchArguments = [argument]
        app.launch()
        XCTAssertTrue(waitForLaunch(of: app, timeout: 10))
        return app
    }

    private func waitForPreviewWindow(in app: XCUIApplication, timeout: TimeInterval = 8) -> XCUIElement {
        let window = app.windows.firstMatch
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if window.exists {
                return window
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }

        XCTAssertTrue(window.waitForExistence(timeout: 1))
        return window
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
