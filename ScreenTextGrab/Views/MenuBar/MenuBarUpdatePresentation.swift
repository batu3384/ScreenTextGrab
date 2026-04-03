import SwiftUI

struct MenuBarUpdatePresentation: Equatable {
    let content: AppUpdatePresentationModel
    let width: CGFloat
    let tint: Color
    let backgroundOpacity: Double
    let isAvailable: Bool
    let isBusy: Bool

    init(state: AppUpdateState, isCompact: Bool, isAvailable: Bool) {
        let content = AppUpdatePresentationModel(state: state)
        self.content = content
        self.isAvailable = isAvailable
        self.isBusy = state.isBusy

        switch state {
        case .idle:
            self.width = isCompact ? 110 : 122
            self.tint = .accentMint
            self.backgroundOpacity = 0.22
        case .checking:
            self.width = isCompact ? 118 : 132
            self.tint = .accentCool
            self.backgroundOpacity = 0.18
        case .downloading:
            self.width = isCompact ? 108 : 118
            self.tint = .accentAmber
            self.backgroundOpacity = 0.20
        case .readyToInstall:
            self.width = isCompact ? 136 : 156
            self.tint = .accentCool
            self.backgroundOpacity = 0.24
        case .upToDate:
            self.width = isCompact ? 106 : 118
            self.tint = .accentMint
            self.backgroundOpacity = 0.16
        case .failed:
            self.width = isCompact ? 116 : 126
            self.tint = .accentRose
            self.backgroundOpacity = 0.20
        }
    }
}
