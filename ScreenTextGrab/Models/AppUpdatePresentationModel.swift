import Foundation

struct AppUpdatePresentationModel: Equatable {
    let title: String
    let iconName: String
    let helpText: String
    let accessibilityLabel: String

    init(state: AppUpdateState) {
        switch state {
        case .idle:
            self.title = L10n.actionCheckForUpdates
            self.iconName = "arrow.down.circle"
            self.helpText = L10n.pair(
                "GitHub sürümlerini kontrol eder ve yeni bir paket varsa indirir.",
                "Checks GitHub releases and downloads a new package when one is available."
            )
            self.accessibilityLabel = L10n.accessibilityCheckForUpdates
        case .checking:
            self.title = L10n.actionCheckingForUpdates
            self.iconName = "arrow.triangle.2.circlepath"
            self.helpText = L10n.pair(
                "Yeni sürüm olup olmadığı kontrol ediliyor.",
                "Checking whether a newer release is available."
            )
            self.accessibilityLabel = L10n.pair("Güncellemeler kontrol ediliyor", "Checking for updates")
        case .downloading(let version, let progressPercent):
            if let progressPercent {
                self.title = L10n.format(
                    "İndiriliyor %d%%",
                    "Downloading %d%%",
                    progressPercent
                )
                self.accessibilityLabel = L10n.format(
                    "%@ indiriliyor, %d%% tamamlandı",
                    "Downloading %@, %d%% complete",
                    version,
                    progressPercent
                )
            } else {
                self.title = L10n.actionDownloadingUpdate
                self.accessibilityLabel = L10n.format(
                    "%@ indiriliyor",
                    "Downloading %@",
                    version
                )
            }

            self.iconName = "arrow.down.circle.fill"
            self.helpText = L10n.format(
                "%@ sürümü indiriliyor.",
                "Downloading version %@.",
                version
            )
        case .readyToInstall(let version):
            self.title = L10n.actionRestartToUpdate
            self.iconName = "arrow.clockwise.circle.fill"
            self.helpText = L10n.format(
                "%@ indirildi. Kurulumu tamamlamak için uygulamayı yeniden başlat.",
                "%@ is ready. Restart the app to finish installing the update.",
                version
            )
            self.accessibilityLabel = L10n.format(
                "%@ yüklemeye hazır, yeniden başlat ve güncelle",
                "%@ is ready, restart and update",
                version
            )
        case .upToDate:
            self.title = L10n.actionUpToDate
            self.iconName = "checkmark.circle.fill"
            self.helpText = L10n.pair(
                "Bu cihazdaki sürüm zaten güncel.",
                "This device is already running the latest version."
            )
            self.accessibilityLabel = L10n.pair("Uygulama güncel", "App is up to date")
        case .failed(let message):
            self.title = L10n.actionRetryUpdate
            self.iconName = "exclamationmark.triangle.fill"
            self.helpText = message
            self.accessibilityLabel = L10n.pair("Güncelleme yeniden denenebilir", "Retry update")
        }
    }
}
