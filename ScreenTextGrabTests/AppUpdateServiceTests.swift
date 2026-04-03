import XCTest
@testable import ScreenTextGrab

final class AppUpdateServiceTests: XCTestCase {
    func testAppVersionComparesNumericComponents() {
        XCTAssertLessThan(AppVersion("1.0.9"), AppVersion("1.0.10"))
        XCTAssertLessThan(AppVersion("v1.2.0"), AppVersion("1.10.0"))
        XCTAssertEqual(AppVersion("1.0"), AppVersion("1.0.0"))
    }

    func testReleaseSelectsNamedPrimaryAsset() throws {
        let payload = """
        {
          "tag_name": "v1.0.4",
          "html_url": "https://github.com/batu3384/ScreenTextGrab/releases/tag/v1.0.4",
          "assets": [
            {
              "name": "notes.txt",
              "browser_download_url": "https://example.com/notes.txt",
              "size": 42
            },
            {
              "name": "ScreenTextGrab.zip",
              "browser_download_url": "https://example.com/ScreenTextGrab.zip",
              "size": 2048
            }
          ]
        }
        """

        let release = try JSONDecoder().decode(GitHubReleaseInfo.self, from: Data(payload.utf8))

        XCTAssertEqual(release.normalizedVersion, "1.0.4")
        XCTAssertEqual(release.primaryAsset(named: "ScreenTextGrab.zip")?.name, "ScreenTextGrab.zip")
        XCTAssertNil(release.primaryAsset(named: "missing.zip"))
    }

    func testUpdateStateTitlesCoverPrimaryButtonFlow() {
        XCTAssertEqual(AppUpdateState.idle.buttonTitle, L10n.actionCheckForUpdates)
        XCTAssertEqual(AppUpdateState.checking.buttonTitle, L10n.actionCheckingForUpdates)
        XCTAssertEqual(
            AppUpdateState.downloading(version: "1.0.4", progressPercent: 57).buttonTitle,
            L10n.format("İndiriliyor %d%%", "Downloading %d%%", 57)
        )
        XCTAssertEqual(
            AppUpdateState.readyToInstall(version: "1.0.4").buttonTitle,
            L10n.actionRestartToUpdate
        )
    }

    func testUpdateStateAccessibilityLabelsFollowVisibleState() {
        XCTAssertEqual(AppUpdateState.idle.accessibilityLabel, L10n.accessibilityCheckForUpdates)
        XCTAssertEqual(
            AppUpdateState.checking.accessibilityLabel,
            L10n.pair("Güncellemeler kontrol ediliyor", "Checking for updates")
        )
        XCTAssertEqual(
            AppUpdateState.downloading(version: "1.0.4", progressPercent: 57).accessibilityLabel,
            L10n.format("%@ indiriliyor, %d%% tamamlandı", "Downloading %@, %d%% complete", "1.0.4", 57)
        )
        XCTAssertEqual(
            AppUpdateState.readyToInstall(version: "1.0.4").accessibilityLabel,
            L10n.format("%@ yüklemeye hazır, yeniden başlat ve güncelle", "%@ is ready, restart and update", "1.0.4")
        )
    }

    func testMenuBarUpdatePresentationMapsCompactAndRestartStates() {
        let idle = MenuBarUpdatePresentation(state: .idle, isCompact: true, isAvailable: true)
        XCTAssertEqual(idle.content.title, L10n.actionCheckForUpdates)
        XCTAssertEqual(idle.width, 110)
        XCTAssertTrue(idle.isAvailable)

        let restart = MenuBarUpdatePresentation(
            state: .readyToInstall(version: "1.0.4"),
            isCompact: false,
            isAvailable: true
        )
        XCTAssertEqual(restart.content.title, L10n.actionRestartToUpdate)
        XCTAssertEqual(restart.width, 156)
        XCTAssertFalse(restart.isBusy)
    }
}
