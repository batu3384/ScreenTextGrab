import SwiftUI

struct MenuBarQuickSettingsSection: View {
    let isCompact: Bool
    let captureMode: CaptureMode
    let outputPreset: CaptureOutputPreset
    let watchStatusTitle: String
    let watchSummary: String
    let watchActionTitle: String
    let watchActionIcon: String
    let watchTint: Color
    let smartActions: [SmartActionDescriptor]
    let canOfferSpeechAction: Bool
    let speechState: SpeechPlaybackState
    let captureModeFeedback: InlineFeedback?
    let outputPresetFeedback: InlineFeedback?
    let smartActionFeedback: InlineFeedback?
    let onSelectCaptureMode: (CaptureMode) -> Void
    let onSelectOutputPreset: (CaptureOutputPreset) -> Void
    let onToggleWatch: () -> Void
    let onPerformSmartAction: (SmartActionDescriptor) -> Void
    let onToggleSpeech: () -> Void
    let captureModeTint: (CaptureMode) -> Color
    let captureModeIcon: (CaptureMode) -> String
    let captureModeSummary: (CaptureMode) -> String
    let outputPresetIcon: (CaptureOutputPreset) -> String

    var body: some View {
        MenuBarCard(isCompact: isCompact) {
            VStack(alignment: .leading, spacing: isCompact ? 10 : 12) {
                HStack(spacing: 8) {
                    Text(L10n.controlsTitle)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    MenuBarStatusBadge(text: captureMode.title, tint: .accentMint, isCompact: isCompact)
                }

                VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
                    Text(L10n.pair("Yakalama Modu", "Capture Mode"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ],
                        spacing: 8
                    ) {
                        ForEach(CaptureMode.allCases) { mode in
                            captureModeToggle(mode)
                        }
                    }
                }

                MenuBarQuickSettingRow(
                    isCompact: isCompact,
                    title: L10n.pair("Çıktı Biçimi", "Output Format"),
                    detail: L10n.pair("Panoya kopyalanacak biçimi belirle.", "Choose the format copied to the clipboard.")
                ) {
                    outputPresetMenu
                }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                watchRow

                if let captureModeFeedback {
                    MenuBarFeedbackText(message: captureModeFeedback.message, tint: captureModeFeedback.tint, isCompact: isCompact)
                }

                if let outputPresetFeedback {
                    MenuBarFeedbackText(message: outputPresetFeedback.message, tint: outputPresetFeedback.tint, isCompact: isCompact)
                }

                if shouldShowSmartActionsPanel {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(L10n.pair("Hızlı İşlem", "Quick Actions"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        HStack(spacing: 8) {
                            ForEach(Array(smartActions.prefix(2))) { action in
                                MenuBarCompactInlineButton(
                                    title: action.title,
                                    icon: action.icon,
                                    tint: .accentNeutral,
                                    isCompact: isCompact,
                                    action: { onPerformSmartAction(action) }
                                )
                            }

                            if canOfferSpeechAction {
                                MenuBarCompactInlineButton(
                                    title: speechState == .speaking ? L10n.pair("Durdur", "Stop") : L10n.pair("Sesli Oku", "Read Aloud"),
                                    icon: speechState == .speaking ? "stop.fill" : "speaker.wave.2.fill",
                                    tint: speechState == .speaking ? .accentRose : .accentMint,
                                    isCompact: isCompact,
                                    action: onToggleSpeech
                                )
                            }
                        }

                        if let smartActionFeedback {
                            MenuBarFeedbackText(message: smartActionFeedback.message, tint: smartActionFeedback.tint, isCompact: isCompact)
                        }
                    }
                }
            }
        }
    }

    private var shouldShowSmartActionsPanel: Bool {
        !smartActions.isEmpty || canOfferSpeechAction
    }

    private var outputPresetMenu: some View {
        Menu {
            ForEach(CaptureOutputPreset.allCases) { preset in
                Button {
                    onSelectOutputPreset(preset)
                } label: {
                    HStack {
                        Text(preset.title)
                        if preset == outputPreset {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: outputPresetIcon(outputPreset))
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))

                VStack(alignment: .leading, spacing: 1) {
                    Text(outputPreset.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(outputPreset.summary)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.68))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.65))
            }
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minWidth: isCompact ? 146 : 160, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.controlFillStrong)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentCool.opacity(0.08))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.controlStroke, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
    }

    private var watchRow: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.pair("İzleme", "Watch"))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(watchSummary)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                MenuBarStatusBadge(text: watchStatusTitle, tint: watchTint, isCompact: isCompact)
                MenuBarSmallActionButton(
                    title: watchActionTitle,
                    icon: watchActionIcon,
                    tint: watchTint,
                    isCompact: isCompact,
                    action: onToggleWatch
                )
            }
        }
        .padding(.vertical, 1)
    }

    private func captureModeToggle(_ mode: CaptureMode) -> some View {
        let isSelected = captureMode == mode
        let tint = captureModeTint(mode)

        return Button(action: { onSelectCaptureMode(mode) }) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: captureModeIcon(mode))
                        .font(.system(size: isCompact ? 9.5 : 10.5, weight: .bold))
                        .foregroundStyle(isSelected ? .white : tint)
                        .frame(width: isCompact ? 22 : 24, height: isCompact ? 22 : 24)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? Color.white.opacity(0.14) : tint.opacity(0.12))
                        )
                    Text(mode.title)
                        .font(.system(size: isCompact ? 11 : 12, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.92)
                }

                Text(captureModeSummary(mode))
                    .font(.system(size: isCompact ? 9.5 : 10.5, weight: .medium, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.84))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, isCompact ? 9 : 10)
            .padding(.vertical, isCompact ? 8 : 10)
            .frame(maxWidth: .infinity, minHeight: isCompact ? 68 : 74, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.controlFillStrong : Color.controlFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tint.opacity(isSelected ? 0.18 : 0.07))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.62) : Color.controlStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(L10n.accessibilityCaptureMode): \(mode.title)")
    }
}
