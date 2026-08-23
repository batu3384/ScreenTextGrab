import SwiftUI

@main
struct ScreenTextGrabApp: App {
    static let settingsWindowID = "settings-window"
    static let tableReviewWindowID = "table-review-window"

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appDelegate.appState)
        } label: {
            MenuBarStatusIcon()
        }
        .menuBarExtraStyle(.window)

        Window(L10n.pair("Ayarlar", "Settings"), id: Self.settingsWindowID) {
            SettingsView()
                .environmentObject(appDelegate.appState)
                .frame(width: 620, height: 560)
        }

        Window(L10n.pair("Tablo Duzenleyici", "Table Editor"), id: Self.tableReviewWindowID) {
            TableReviewView()
                .environmentObject(appDelegate.appState)
                .frame(minWidth: 860, idealWidth: 920, minHeight: 580, idealHeight: 640)
        }
    }
}
