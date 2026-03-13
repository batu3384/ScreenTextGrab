import AppKit
import Carbon
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var appState: AppState
    @State private var isRecordingHotkey = false
    @State private var hotkeyFeedback: HotkeyFeedback?
    @State private var launchAtLoginFeedback: InlineFeedback?
    @State private var captureModeFeedback: InlineFeedback?
    @State private var outputPresetFeedback: InlineFeedback?
    @State private var ocrFeedback: InlineFeedback?
    @State private var smartActionFeedback: InlineFeedback?
    @State private var hotkeyRecorderMonitor: Any?

    var body: some View {
        ZStack {
            background
            panelContent
                .padding(panelPadding)
        }
        .frame(width: panelWidth)
        .frame(maxHeight: panelMaxHeight)
        .onAppear {
            refreshLaunchAtLoginState()
            refreshPermission()
        }
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            header
            statusPanel
            primaryAction
            quickSettingsPanel

            if let notice = helperNotice {
                noticePanel(notice)
            }

            actions
        }
    }

    private var panelMaxHeight: CGFloat {
        let visibleHeight = preferredPanelScreen?.visibleFrame.height ?? 760
        return max(visibleHeight - 12, 320)
    }

    private var isCompactPanel: Bool {
        panelMaxHeight <= 430
    }

    private var panelWidth: CGFloat {
        isCompactPanel ? 356 : 372
    }

    private var panelPadding: CGFloat {
        isCompactPanel ? 12 : 14
    }

    private var sectionSpacing: CGFloat {
        isCompactPanel ? 10 : 12
    }

    private var preferredPanelScreen: NSScreen? {
        NSApp.keyWindow?.screen ??
            NSApp.mainWindow?.screen ??
            NSApp.windows.first(where: \.isVisible)?.screen ??
            NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ??
            NSScreen.main
    }

    private var quickSettingsPanel: some View {
        card {
            VStack(alignment: .leading, spacing: isCompactPanel ? 10 : 12) {
                HStack(spacing: 8) {
                    Text(L10n.controlsTitle)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    statusBadge(text: appState.captureMode.title, tint: .accentMint)
                }

                VStack(alignment: .leading, spacing: isCompactPanel ? 8 : 10) {
                    Text("Yakalama Modu")
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

                    Text(selectedModeSummary)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.76))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                quickSettingRow(
                    title: "Çıktı Biçimi",
                    detail: "Yakalamadan sonra panoya hangi biçimin kopyalanacağını seçersin."
                ) {
                    Menu {
                        ForEach(CaptureOutputPreset.allCases) { preset in
                            Button {
                                setCaptureOutputPreset(preset)
                            } label: {
                                HStack {
                                    Text(preset.title)
                                    if preset == appState.captureOutputPreset {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: outputPresetIcon(for: appState.captureOutputPreset))
                                .font(.system(size: 10.5, weight: .bold))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(appState.captureOutputPreset.title)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                Text(appState.captureOutputPreset.summary)
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
                        .padding(.vertical, 8)
                        .frame(minWidth: isCompactPanel ? 156 : 172, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kısayol")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(isRecordingHotkey ? "Yeni tuşu gir" : appState.hotkeyDisplayLabel)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.66))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 8) {
                        Button(action: toggleHotkeyRecording) {
                            Text(isRecordingHotkey ? "Tuşa Bas..." : appState.hotkeyDisplayLabel)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                                .padding(.horizontal, isCompactPanel ? 10 : 11)
                                .padding(.vertical, isCompactPanel ? 7 : 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill((isRecordingHotkey ? Color.accentCool : Color.white).opacity(isRecordingHotkey ? 0.22 : 0.12))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                        iconActionButton(
                            systemName: "arrow.counterclockwise",
                            tint: .accentNeutral,
                            accessibilityLabel: L10n.accessibilityResetHotkey,
                            action: resetHotkey
                        )
                    }
                }

                Group {
                    if isCompactPanel {
                        VStack(spacing: 10) {
                            compactControlCard(
                                title: "İzleme",
                                subtitle: appState.watchState.isActive ? "Arka planda çalışıyor" : "Kapalı",
                                tint: watchTint,
                                actionTitle: appState.watchState.isActive || appState.watchState == .selecting ? "Durdur" : "Başlat",
                                actionIcon: appState.watchState.isActive || appState.watchState == .selecting ? "stop.fill" : "dot.scope",
                                action: toggleWatching
                            )

                            compactToggleCard(
                                title: "Açılışta Başlat",
                                subtitle: appState.launchAtLoginState.title,
                                tint: launchAtLoginTint
                            ) {
                                Toggle("", isOn: launchAtLoginBinding)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .tint(.accentMint)
                                    .accessibilityLabel(L10n.accessibilityLaunchAtLoginToggle)
                            }
                        }
                    } else {
                        HStack(spacing: 10) {
                            compactControlCard(
                                title: "İzleme",
                                subtitle: appState.watchState.isActive ? "Arka planda çalışıyor" : "Kapalı",
                                tint: watchTint,
                                actionTitle: appState.watchState.isActive || appState.watchState == .selecting ? "Durdur" : "Başlat",
                                actionIcon: appState.watchState.isActive || appState.watchState == .selecting ? "stop.fill" : "dot.scope",
                                action: toggleWatching
                            )

                            compactToggleCard(
                                title: "Açılışta Başlat",
                                subtitle: appState.launchAtLoginState.title,
                                tint: launchAtLoginTint
                            ) {
                                Toggle("", isOn: launchAtLoginBinding)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .tint(.accentMint)
                                    .accessibilityLabel(L10n.accessibilityLaunchAtLoginToggle)
                            }
                        }
                    }
                }

                if let hotkeyFeedback {
                    feedbackText(hotkeyFeedback.message, tint: hotkeyFeedback.tint)
                }

                if let captureModeFeedback {
                    feedbackText(captureModeFeedback.message, tint: captureModeFeedback.tint)
                }

                if let outputPresetFeedback {
                    feedbackText(outputPresetFeedback.message, tint: outputPresetFeedback.tint)
                }

                if let launchAtLoginFeedback {
                    feedbackText(launchAtLoginFeedback.message, tint: launchAtLoginFeedback.tint)
                }

                if appState.launchAtLoginState == .requiresApproval {
                    compactInlineButton(
                        title: L10n.actionLoginItems,
                        icon: "person.crop.circle.badge.gearshape",
                        tint: .accentAmber,
                        action: openLoginItemsSettings
                    )
                }

                if shouldShowSmartActionsPanel {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Hızlı İşlem")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        HStack(spacing: 8) {
                            ForEach(Array(smartActions.prefix(2))) { action in
                                compactInlineButton(
                                    title: action.title,
                                    icon: action.icon,
                                    tint: .accentNeutral,
                                    action: { performSmartAction(action) }
                                )
                            }

                            if canOfferSpeechAction {
                                compactInlineButton(
                                    title: appState.speechState == .speaking ? "Durdur" : "Sesli Oku",
                                    icon: appState.speechState == .speaking ? "stop.fill" : "speaker.wave.2.fill",
                                    tint: appState.speechState == .speaking ? .accentRose : .accentMint,
                                    action: toggleSpeechPlayback
                                )
                            }
                        }

                        if let smartActionFeedback {
                            feedbackText(smartActionFeedback.message, tint: smartActionFeedback.tint)
                        }
                    }
                }
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [.surfaceTop, .surfaceBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.accentMint.opacity(0.20))
                .frame(width: 132, height: 132)
                .blur(radius: 24)
                .offset(x: 44, y: -36)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color.accentAmber.opacity(0.16))
                .frame(width: 150, height: 150)
                .blur(radius: 32)
                .offset(x: -36, y: 50)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: isCompactPanel ? 10 : 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: isCompactPanel ? 38 : 42, height: isCompactPanel ? 38 : 42)
                .clipShape(RoundedRectangle(cornerRadius: isCompactPanel ? 11 : 12, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 5)

            VStack(alignment: .leading, spacing: 2) {
                Text("ScreenTextGrab")
                    .font(.system(size: isCompactPanel ? 16.5 : 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(headerLine)
                    .font(.system(size: isCompactPanel ? 10.5 : 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer()

            iconActionButton(
                systemName: "power",
                tint: .accentRose,
                accessibilityLabel: L10n.accessibilityQuitApp,
                action: quitApp
            )
        }
    }

    private var statusPanel: some View {
        card {
            VStack(alignment: .leading, spacing: isCompactPanel ? 6 : 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusTint)
                        .frame(width: 8, height: 8)

                    Text(statusTitle)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    statusBadge(text: permissionBadge, tint: permissionTint)
                }

                Text(statusDescription)
                    .font(.system(size: isCompactPanel ? 11 : 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(isCompactPanel ? 2 : 3)
            }
        }
    }

    private var primaryAction: some View {
        Button(action: startCapture) {
            HStack(spacing: 12) {
                Image(systemName: "viewfinder")
                    .font(.system(size: isCompactPanel ? 15 : 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: isCompactPanel ? 32 : 36, height: isCompactPanel ? 32 : 36)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: isCompactPanel ? 10 : 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(canStartCapture ? "Metni Yakala" : "Yakalama Hazır Değil")
                        .font(.system(size: isCompactPanel ? 14 : 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(primarySubtitle)
                        .font(.system(size: isCompactPanel ? 10.5 : 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(isCompactPanel ? 12 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: canStartCapture ? [.accentAmber, .accentCoral] : [.white.opacity(0.12), .white.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canStartCapture)
        .opacity(canStartCapture ? 1 : 0.76)
    }

    private func noticePanel(_ notice: NoticeContent) -> some View {
        card {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: notice.icon)
                    .font(.system(size: isCompactPanel ? 12 : 13, weight: .bold))
                    .foregroundStyle(notice.tint)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(notice.title)
                        .font(.system(size: isCompactPanel ? 11 : 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(notice.message)
                        .font(.system(size: isCompactPanel ? 10 : 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.66))
                        .lineLimit(isCompactPanel ? 2 : 3)
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            if appState.permissionState == .denied || appState.permissionState == .unknown {
                secondaryButton(title: L10n.actionAllow, icon: "lock.open.display", tint: .accentAmber, action: requestPermission)
            } else if appState.permissionState == .requiresRestart {
                secondaryButton(title: L10n.actionSystemSettings, icon: "gearshape.2", tint: .accentNeutral, action: openSystemSettings)
            }

            secondaryButton(title: L10n.actionSettings, icon: "slider.horizontal.3", tint: .accentNeutral, action: openSettingsWindow)
            secondaryButton(title: L10n.actionRefresh, icon: "arrow.clockwise", tint: .accentMint, action: refreshPermission)
        }
    }

    private var smartActions: [SmartActionDescriptor] {
        Array(SmartActionBuilder.actions(for: appState.lastCopiedEntry).prefix(3))
    }

    private var canOfferSpeechAction: Bool {
        appState.speechState == .speaking || SmartActionBuilder.shouldOfferReadAloud(for: appState.lastCopiedEntry)
    }

    private var shouldShowSmartActionsPanel: Bool {
        !smartActions.isEmpty || canOfferSpeechAction
    }

    private func compactControlCard(
        title: String,
        subtitle: String,
        tint: Color,
        actionTitle: String,
        actionIcon: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: isCompactPanel ? 6 : 8) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.66))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            compactInlineButton(title: actionTitle, icon: actionIcon, tint: tint, action: action)
        }
        .padding(isCompactPanel ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func compactToggleCard<Control: View>(
        title: String,
        subtitle: String,
        tint: Color,
        @ViewBuilder control: () -> Control
    ) -> some View {
        VStack(alignment: .leading, spacing: isCompactPanel ? 6 : 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer(minLength: 8)

                control()
            }

            Text(subtitle)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(isCompactPanel ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func compactInlineButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: isCompactPanel ? 10 : 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, isCompactPanel ? 9 : 10)
            .padding(.vertical, isCompactPanel ? 7 : 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .padding(isCompactPanel ? 12 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.cardStroke, lineWidth: 1)
            )
    }

    private func quickSettingRow<Control: View>(
        title: String,
        detail: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            control()
        }
    }

    private func statusBadge(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule(style: .continuous))
    }

    private func secondaryButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: isCompactPanel ? 10 : 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, isCompactPanel ? 10 : 11)
            .padding(.vertical, isCompactPanel ? 8 : 9)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func iconActionButton(
        systemName: String,
        tint: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: isCompactPanel ? 28 : 30, height: isCompactPanel ? 28 : 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(tint.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func feedbackText(_ message: String, tint: Color) -> some View {
        Text(message)
            .font(.system(size: isCompactPanel ? 10 : 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(isCompactPanel ? 2 : 3)
    }

    private func captureModeToggle(_ mode: CaptureMode) -> some View {
        let isSelected = appState.captureMode == mode

        return Button(action: { setCaptureMode(mode) }) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: captureModeIcon(for: mode))
                        .font(.system(size: isCompactPanel ? 9.5 : 10.5, weight: .bold))
                    Text(mode.title)
                        .font(.system(size: isCompactPanel ? 11 : 12, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.92)
                }

                Text(captureModeSummary(for: mode))
                    .font(.system(size: isCompactPanel ? 9.5 : 10.5, weight: .medium, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle((isSelected ? Color.white : Color.white.opacity(0.84)))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, isCompactPanel ? 9 : 10)
            .padding(.vertical, isCompactPanel ? 8 : 10)
            .frame(maxWidth: .infinity, minHeight: isCompactPanel ? 68 : 74, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill((isSelected ? Color.accentAmber : Color.white).opacity(isSelected ? 0.24 : 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke((isSelected ? Color.accentAmber : Color.white).opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(L10n.accessibilityCaptureMode): \(mode.title)")
    }

    private func captureModeIcon(for mode: CaptureMode) -> String {
        switch mode {
        case .standard:
            return "doc.text.viewfinder"
        case .subtitle:
            return "captions.bubble"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        case .table:
            return "tablecells"
        }
    }

    private func captureModeSummary(for mode: CaptureMode) -> String {
        switch mode {
        case .standard:
            return "Genel OCR"
        case .subtitle:
            return "Video ve altyazı"
        case .code:
            return "Kod ve terminal"
        case .table:
            return "Tablo ve liste"
        }
    }

    private func outputPresetIcon(for preset: CaptureOutputPreset) -> String {
        switch preset {
        case .smart:
            return "wand.and.stars"
        case .plainText:
            return "text.alignleft"
        case .cleaned:
            return "text.badge.checkmark"
        case .office:
            return "doc.richtext"
        case .markdown:
            return "curlybraces.square"
        case .json:
            return "curlybraces"
        }
    }

    private var selectedModeSummary: String {
        isCompactPanel ? appState.captureMode.readyDescription : appState.captureMode.detail
    }

    private var canStartCapture: Bool {
        !appState.captureState.isBusy &&
        appState.permissionState == .granted &&
        appState.watchState != .active &&
        appState.watchState != .selecting
    }

    private var headerLine: String {
        if appState.captureMode == .subtitle {
            return appState.isHotkeyAvailable
                ? "\(appState.hotkeyDisplayLabel) ile video ve canlı altyazı yakala."
                : "Video ve canlı altyazılar için optimize."
        }

        if appState.captureMode == .code {
            return appState.isHotkeyAvailable
                ? "\(appState.hotkeyDisplayLabel) ile kod blokları ve terminal çıktıları yakala."
                : "Kod blokları ve terminal çıktıları için optimize."
        }

        if appState.captureMode == .table {
            return appState.isHotkeyAvailable
                ? "\(appState.hotkeyDisplayLabel) ile tablo ve çok sütunlu listeleri yakala."
                : "Tablo ve çok sütunlu içerikler için optimize."
        }

        if appState.isHotkeyAvailable {
            return "\(appState.hotkeyDisplayLabel) ile veya panelden başlat."
        }

        return "Ekrandaki metni tek adımda yakala."
    }

    private var statusTitle: String {
        if appState.watchState == .active {
            return "İzleme Aktif"
        }

        if appState.watchState == .selecting {
            return "İzleme Seçimi"
        }

        switch appState.captureState {
        case .idle:
            return appState.permissionState == .granted ? "Hazır" : "Kurulum Gerekli"
        case .preparing:
            return "Hazırlanıyor"
        case .selecting:
            return "Alan Seçiliyor"
        case .capturing:
            return "Görüntü Alınıyor"
        case .recognizing:
            return "Metin Tanınıyor"
        case .copying:
            return "Panoya Yazılıyor"
        case .completed:
            return "Kopyalandı"
        case .completedEmpty:
            return "Metin Bulunamadı"
        case .failed:
            return "İşlem Başarısız"
        case .cancelled:
            return "İptal Edildi"
        }
    }

    private var statusDescription: String {
        if appState.watchState == .active {
            return "Seçilen alan arka planda izleniyor. Yeni içerik algılanırsa pano otomatik güncellenir."
        }

        if appState.watchState == .selecting {
            return "İzlenecek alanı seçmen bekleniyor. ESC ile iptal edebilirsin."
        }

        switch appState.permissionState {
        case .granted:
            if appState.captureState == .idle || appState.captureState == .completed || appState.captureState == .cancelled {
                return appState.isHotkeyAvailable
                    ? "Ekran kaydı izni aktif. \(appState.hotkeyDisplayLabel) ile veya aşağıdaki butonla \(appState.captureMode.title.lowercased()) yakalamayı başlatabilirsin."
                    : "Ekran kaydı izni aktif. \(appState.captureMode.title) modunda doğrudan yakalama başlatabilirsin."
            }
            return appState.statusMessage
        case .requiresRestart:
            return "İzin verildi ancak yeni yetkiyi almak için uygulamayı yeniden açman gerekiyor."
        case .denied:
            return "Ekran kaydı izni kapalı görünüyor. İzin verdiysen Yenile'ye bas."
        case .unknown:
            return "İzin durumu şu anda doğrulanamadı. Sistem Ayarları veya Yenile ile tekrar kontrol et."
        case .requestInProgress:
            return "İzin penceresi açık. Onay verdikten sonra durum otomatik güncellenecek."
        }
    }

    private var primarySubtitle: String {
        if appState.watchState == .active {
            return "İzleme aktifken normal yakalama devre dışı."
        }

        if appState.watchState == .selecting {
            return "Önce izlenecek alanı seç."
        }

        switch appState.permissionState {
        case .granted:
            return appState.captureMode.readyDescription
        case .requiresRestart:
            return "Önce uygulamayı yeniden aç."
        case .denied:
            return "Önce ekran kaydı iznini etkinleştir."
        case .unknown:
            return "Önce izin durumunu doğrula."
        case .requestInProgress:
            return "İzin işlemi tamamlanınca yakalama açılacak."
        }
    }

    private var permissionBadge: String {
        switch appState.permissionState {
        case .granted: return "Açık"
        case .requiresRestart: return "Yeniden Aç"
        case .denied: return "Kapalı"
        case .unknown: return "Belirsiz"
        case .requestInProgress: return "Bekliyor"
        }
    }

    private var permissionTint: Color {
        switch appState.permissionState {
        case .granted:
            return .accentCool
        case .requiresRestart:
            return .accentWarm
        case .denied, .unknown:
            return .accentRose
        case .requestInProgress:
            return .accentNeutral
        }
    }

    private var statusTint: Color {
        if appState.watchState == .active {
            return .accentCool
        }

        if appState.captureState.isBusy {
            return .accentWarm
        }

        switch appState.permissionState {
        case .granted:
            if appState.captureState == .failed {
                return .accentRose
            }
            return .accentCool
        case .requiresRestart:
            return .accentWarm
        case .denied, .unknown:
            return .accentRose
        case .requestInProgress:
            return .accentNeutral
        }
    }

    private var helperNotice: NoticeContent? {
        if appState.watchState == .active {
            return NoticeContent(
                title: "İzleme açık",
                message: "Seçilen bölgede metin değişirse yeni içerik otomatik olarak panoya kopyalanır.",
                icon: "dot.radiowaves.left.and.right",
                tint: .accentMint
            )
        }

        if appState.permissionState == .requiresRestart {
            return NoticeContent(
                title: "Yeniden başlatma gerekiyor",
                message: "macOS yeni ekran kaydı iznini bir sonraki açılışta uyguluyor.",
                icon: "power.circle",
                tint: .accentAmber
            )
        }

        if !appState.isHotkeyAvailable {
            return NoticeContent(
                title: "Global kısayol etkin değil",
                message: "Seçili kombinasyon başka bir uygulamayla çakışıyor veya sistem hotkey kaydı tamamlanamadı. Farklı bir kombinasyon deneyebilirsin.",
                icon: "bolt.horizontal.circle",
                tint: .accentNeutral
            )
        }

        if appState.launchAtLoginState == .requiresApproval {
            return NoticeContent(
                title: "Açılış ayarı onay bekliyor",
                message: "macOS giriş öğesi değişikliğini hemen uygulamamış olabilir. Ayarlar penceresinden Giriş Öğeleri'ni açabilirsin.",
                icon: "person.crop.circle.badge.clock",
                tint: .accentAmber
            )
        }

        if appState.captureState == .failed, let lastError = appState.lastError {
            return NoticeContent(
                title: "Son hata",
                message: lastError.errorDescription ?? "Beklenmeyen bir hata oluştu.",
                icon: "exclamationmark.triangle",
                tint: .accentRose
            )
        }

        return nil
    }

    private func startCapture() {
        appState.coordinator?.startCapture(trigger: .menu)
    }

    private func toggleHotkeyRecording() {
        if isRecordingHotkey {
            hotkeyFeedback = HotkeyFeedback(
                message: "Kısayol değiştirme iptal edildi.",
                tint: .accentNeutral
            )
            stopHotkeyRecording()
            return
        }

        beginHotkeyRecording()
    }

    private func beginHotkeyRecording() {
        stopHotkeyRecording()
        isRecordingHotkey = true
        hotkeyFeedback = HotkeyFeedback(
            message: "Yeni kısayol için bir kombinasyona bas.",
            tint: .accentCool
        )

        hotkeyRecorderMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleHotkeyRecording(event)
        }
    }

    private func handleHotkeyRecording(_ event: NSEvent) -> NSEvent? {
        guard isRecordingHotkey else {
            return event
        }

        if event.keyCode == UInt16(kVK_Escape) {
            hotkeyFeedback = HotkeyFeedback(
                message: "Kısayol değiştirme iptal edildi.",
                tint: .accentNeutral
            )
            stopHotkeyRecording()
            return nil
        }

        guard let configuration = HotkeyConfiguration.from(event: event) else {
            hotkeyFeedback = HotkeyFeedback(
                message: "En az bir değiştirici tuş ile harf, rakam veya özel tuş kullan.",
                tint: .accentWarm
            )
            return nil
        }

        guard let hotkeyManager = appState.hotkeyManager else {
            hotkeyFeedback = HotkeyFeedback(
                message: "Kısayol servisi şu anda hazır değil.",
                tint: .accentRose
            )
            stopHotkeyRecording()
            return nil
        }

        do {
            try hotkeyManager.updateHotkey(to: configuration)
            hotkeyFeedback = HotkeyFeedback(
                message: "Kısayol güncellendi: \(configuration.displayLabel)",
                tint: .accentCool
            )
            stopHotkeyRecording()
        } catch {
            hotkeyFeedback = HotkeyFeedback(
                message: error.localizedDescription,
                tint: .accentRose
            )
        }

        return nil
    }

    private func stopHotkeyRecording() {
        if let hotkeyRecorderMonitor {
            NSEvent.removeMonitor(hotkeyRecorderMonitor)
            self.hotkeyRecorderMonitor = nil
        }
        isRecordingHotkey = false
    }

    private func resetHotkey() {
        do {
            try appState.hotkeyManager?.resetHotkeyToDefault()
            hotkeyFeedback = HotkeyFeedback(
                message: "Kısayol varsayılana döndü: \(HotkeyConfiguration.defaultValue.displayLabel)",
                tint: .accentCool
            )
            stopHotkeyRecording()
        } catch {
            hotkeyFeedback = HotkeyFeedback(
                message: error.localizedDescription,
                tint: .accentRose
            )
        }
    }

    private func setCaptureMode(_ mode: CaptureMode) {
        guard appState.captureMode != mode else { return }
        appState.setCaptureMode(mode)
        captureModeFeedback = InlineFeedback(
            message: "\(mode.title) modu etkin. \(mode.readyDescription)",
            tint: .accentCool
        )
    }

    private func setCaptureOutputPreset(_ preset: CaptureOutputPreset) {
        guard appState.captureOutputPreset != preset else { return }
        appState.setCaptureOutputPreset(preset)
        outputPresetFeedback = InlineFeedback(
            message: "Çıktı biçimi \(preset.title) olarak ayarlandı.",
            tint: .accentCool
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appState.launchAtLoginState.toggleIsOn },
            set: { setLaunchAtLogin($0) }
        )
    }

    private var launchAtLoginTint: Color {
        switch appState.launchAtLoginState {
        case .enabled:
            return .accentCool
        case .disabled:
            return .accentNeutral
        case .requiresApproval:
            return .accentWarm
        case .unavailable:
            return .accentRose
        }
    }

    private func refreshLaunchAtLoginState() {
        let state = appState.launchAtLoginManager?.refreshLaunchAtLoginState() ?? .unavailable
        if state != .enabled {
            launchAtLoginFeedback = nil
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        guard let launchAtLoginManager = appState.launchAtLoginManager else {
            launchAtLoginFeedback = InlineFeedback(
                message: "Başlangıç servisi şu anda hazır değil.",
                tint: .accentRose
            )
            return
        }

        Task { @MainActor in
            do {
                let state = try await launchAtLoginManager.setLaunchAtLogin(enabled: enabled)
                switch state {
                case .enabled:
                    launchAtLoginFeedback = InlineFeedback(
                        message: "Uygulama artık bilgisayar açıldığında otomatik başlayacak.",
                        tint: .accentCool
                    )
                case .disabled:
                    launchAtLoginFeedback = InlineFeedback(
                        message: "Otomatik başlatma kapatıldı.",
                        tint: .accentNeutral
                    )
                case .requiresApproval:
                    openLoginItemsSettings()
                    launchAtLoginFeedback = InlineFeedback(
                        message: "macOS ek onay istiyor. Giriş Öğeleri açıldı; onaydan sonra durum otomatik yenilenecek.",
                        tint: .accentWarm
                    )
                case .unavailable:
                    launchAtLoginFeedback = InlineFeedback(
                        message: LaunchAtLoginError.unavailable.errorDescription ?? "Bu özellik şu anda kullanılamıyor.",
                        tint: .accentRose
                    )
                }
            } catch {
                launchAtLoginFeedback = InlineFeedback(
                    message: error.localizedDescription,
                    tint: .accentRose
                )
            }
        }
    }

    private func toggleOCRLanguage(_ language: OCRLanguagePreference) {
        let enabled = !appState.ocrLanguageSelection.contains(language)
        if appState.setOCRLanguage(language, enabled: enabled) {
            let summary = appState.ocrLanguageSelection.languages
                .map(\.shortTitle)
                .joined(separator: " + ")
            ocrFeedback = InlineFeedback(
                message: "OCR dili güncellendi: \(summary)",
                tint: .accentCool
            )
        } else {
            ocrFeedback = InlineFeedback(
                message: "En az bir OCR dili seçili kalmalı.",
                tint: .accentWarm
            )
        }
    }

    private func openLoginItemsSettings() {
        appState.launchAtLoginManager?.openLoginItemsSettings()
    }

    private func requestPermission() {
        appState.coordinator?.requestPermission()
    }

    private func refreshPermission() {
        appState.coordinator?.refreshPermission()
    }

    private var watchTint: Color {
        switch appState.watchState {
        case .inactive:
            return .accentNeutral
        case .selecting:
            return .accentWarm
        case .active:
            return .accentCool
        }
    }

    private func toggleWatching() {
        if appState.watchState == .active || appState.watchState == .selecting {
            appState.coordinator?.stopWatching()
        } else {
            appState.coordinator?.startWatching()
        }
    }

    private func performSmartAction(_ action: SmartActionDescriptor) {
        switch action.kind {
        case let .copyAsPreset(preset):
            guard let entry = appState.lastCopiedEntry else {
                smartActionFeedback = InlineFeedback(
                    message: "Dönüştürülecek bir son yakalama bulunamadı.",
                    tint: .accentRose
                )
                return
            }

            guard let result = appState.coordinator?.copyCapturedText(
                rawText: entry.effectiveRawText,
                captureMode: entry.captureMode,
                contentKind: entry.contentKind,
                source: entry.source,
                outputPreset: preset
            ) else {
                smartActionFeedback = InlineFeedback(
                    message: "Kopyalama servisi şu anda hazır değil.",
                    tint: .accentRose
                )
                return
            }

            smartActionFeedback = InlineFeedback(
                message: result == .success
                    ? "\(preset.title) çıktısı panoya kopyalandı."
                    : "\(preset.title) çıktısı üretilemedi.",
                tint: result == .success ? .accentCool : .accentRose
            )
        default:
            guard let url = action.url else {
                smartActionFeedback = InlineFeedback(
                    message: "\(action.title) şu anda kullanılamıyor.",
                    tint: .accentRose
                )
                return
            }

            if NSWorkspace.shared.open(url) {
                smartActionFeedback = InlineFeedback(
                    message: "\(action.title) çalıştırıldı.",
                    tint: .accentCool
                )
            } else {
                smartActionFeedback = InlineFeedback(
                    message: "\(action.title) açılamadı.",
                    tint: .accentRose
                )
            }
        }
    }

    private func toggleSpeechPlayback() {
        guard let speechManager = appState.speechManager else {
            smartActionFeedback = InlineFeedback(
                message: "Sesli okuma servisi şu anda hazır değil.",
                tint: .accentRose
            )
            return
        }

        let speechSource = appState.lastCopiedEntry?.effectiveRawText ?? appState.lastCopiedText
        let wasSpeaking = appState.speechState == .speaking
        speechManager.toggleSpeechPlayback(for: speechSource)
        smartActionFeedback = InlineFeedback(
            message: wasSpeaking ? "Sesli okuma durduruldu." : "Sesli okuma başlatıldı.",
            tint: wasSpeaking ? .accentNeutral : .accentCool
        )
    }

    private func openSystemSettings() {
        appState.coordinator?.openSystemSettings()
    }

    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: ScreenTextGrabApp.settingsWindowID)
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

private enum SettingsTab: String, Hashable {
    case general
    case ocr
    case diagnostics
    case history
}

struct SettingsView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var appState: AppState

    @State private var selectedTab: SettingsTab = .general
    @State private var isRecordingHotkey = false
    @State private var hotkeyFeedback: HotkeyFeedback?
    @State private var launchAtLoginFeedback: InlineFeedback?
    @State private var captureModeFeedback: InlineFeedback?
    @State private var outputPresetFeedback: InlineFeedback?
    @State private var watchFeedback: InlineFeedback?
    @State private var ocrFeedback: InlineFeedback?
    @State private var historyFeedback: InlineFeedback?
    @State private var profileFeedback: InlineFeedback?
    @State private var diagnosticsFeedback: InlineFeedback?
    @State private var permissionDiagnostics: PermissionDiagnosticSnapshot?
    @State private var historySearchQuery = ""
    @State private var watchRegexDraft = ""
    @State private var hotkeyRecorderMonitor: Any?

    private struct ProfileTarget: Identifiable {
        let appName: String
        let bundleIdentifier: String

        var id: String { bundleIdentifier }
    }

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader

            TabView(selection: $selectedTab) {
                generalTab
                    .tag(SettingsTab.general)
                    .tabItem {
                        Label(L10n.settingsTabGeneral, systemImage: "slider.horizontal.3")
                    }

                ocrTab
                    .tag(SettingsTab.ocr)
                    .tabItem {
                        Label(L10n.settingsTabOCR, systemImage: "text.viewfinder")
                    }

                diagnosticsTab
                    .tag(SettingsTab.diagnostics)
                    .tabItem {
                        Label(L10n.settingsTabDiagnostics, systemImage: "stethoscope")
                    }

                historyTab
                    .tag(SettingsTab.history)
                    .tabItem {
                        Label(L10n.settingsTabHistory, systemImage: "clock.arrow.circlepath")
                    }
            }
            .padding(18)
        }
        .background(
            LinearGradient(
                colors: [Color.surfaceTop.opacity(0.10), Color.surfaceBottom.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            refreshLaunchAtLoginState()
            refreshPermission()
            refreshPermissionDiagnostics()
            watchRegexDraft = appState.watchConfiguration.regexFilter
        }
        .onDisappear(perform: stopHotkeyRecording)
    }

    private var settingsHeader: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.settingsTitle)
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(L10n.settingsSubtitle)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.96))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var generalTab: some View {
        ScrollView {
            VStack(spacing: 14) {
                settingsCard(
                    title: "Yakalama Modu",
                    subtitle: "Metin, altyazı, kod veya tablo odaklı yakalama arasında geçiş yap."
                ) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 148), spacing: 10)],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(CaptureMode.allCases) { mode in
                            settingsCaptureModeButton(mode)
                        }
                    }

                    Text(appState.captureMode.detail)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    if let captureModeFeedback {
                        feedbackLabel(captureModeFeedback.message, tint: captureModeFeedback.tint)
                    }
                }

                settingsCard(
                    title: "Çıktı Biçimi",
                    subtitle: appState.captureOutputPreset.detail
                ) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 136), spacing: 10)],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(CaptureOutputPreset.allCases) { preset in
                            outputPresetButton(preset)
                        }
                    }

                    if let outputPresetFeedback {
                        feedbackLabel(outputPresetFeedback.message, tint: outputPresetFeedback.tint)
                    }
                }

                settingsCard(
                    title: "Global Kısayol",
                    subtitle: isRecordingHotkey
                        ? "Yeni kombinasyonu gir. Esc ile iptal edebilirsin."
                        : "Yakalamayı her yerden başlatmak için kullanılır."
                ) {
                    HStack(spacing: 10) {
                        Button(action: toggleHotkeyRecording) {
                            Text(isRecordingHotkey ? "Tuşa Bas..." : appState.hotkeyDisplayLabel)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill((isRecordingHotkey ? Color.accentCool : Color.surfaceTop).opacity(isRecordingHotkey ? 0.85 : 0.82))
                                )
                        }
                        .buttonStyle(.plain)

                        settingsActionButton(
                            title: isRecordingHotkey ? L10n.actionCancel : L10n.actionChange,
                            icon: isRecordingHotkey ? "xmark" : "keyboard",
                            tint: isRecordingHotkey ? .accentRose : .accentCool,
                            action: toggleHotkeyRecording
                        )

                        settingsActionButton(
                            title: L10n.actionDefault,
                            icon: "arrow.counterclockwise",
                            tint: .accentNeutral,
                            action: resetHotkey
                        )
                    }

                    if let hotkeyFeedback {
                        feedbackLabel(hotkeyFeedback.message, tint: hotkeyFeedback.tint)
                    }
                }

                settingsCard(
                    title: "Açılışta Başlat",
                    subtitle: appState.launchAtLoginState.detail
                ) {
                    HStack(spacing: 12) {
                        statusPill(appState.launchAtLoginState.title, tint: launchAtLoginTint)
                        Spacer()
                        Toggle("", isOn: launchAtLoginBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityLabel(L10n.accessibilityLaunchAtLoginToggle)
                    }

                    HStack(spacing: 10) {
                        if appState.launchAtLoginState == .requiresApproval {
                            settingsActionButton(
                                title: L10n.actionLoginItems,
                                icon: "person.crop.circle.badge.gearshape",
                                tint: .accentWarm,
                                action: openLoginItemsSettings
                            )
                        }

                        settingsActionButton(
                            title: L10n.actionRefresh,
                            icon: "arrow.clockwise",
                            tint: .accentNeutral,
                            action: refreshLaunchAtLoginState
                        )
                    }

                    if let launchAtLoginFeedback {
                        feedbackLabel(launchAtLoginFeedback.message, tint: launchAtLoginFeedback.tint)
                    }
                }

                settingsCard(
                    title: "İzleme Kuralları",
                    subtitle: appState.watchConfiguration.summary
                ) {
                    HStack(spacing: 10) {
                        ForEach(WatchCopyBehavior.allCases) { behavior in
                            watchBehaviorButton(behavior)
                        }
                    }

                    TextField("İsteğe bağlı regex filtresi", text: $watchRegexDraft)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 10) {
                        settingsActionButton(
                            title: "Regex'i Kaydet",
                            icon: "checkmark.circle",
                            tint: .accentCool,
                            action: saveWatchRegex
                        )

                        settingsActionButton(
                            title: "Temizle",
                            icon: "eraser",
                            tint: .accentNeutral,
                            action: clearWatchRegex
                        )
                    }

                    Text("Regex doluysa izleme yalnızca eşleşen parçaları kopyalar.")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    if let watchFeedback {
                        feedbackLabel(watchFeedback.message, tint: watchFeedback.tint)
                    }
                }

                settingsCard(
                    title: "Ekran Kaydı İzni",
                    subtitle: appState.permissionState.uiMessage
                ) {
                    HStack(spacing: 12) {
                        statusPill(permissionTitle, tint: permissionTint)
                        Spacer()
                        Text(permissionDescription)
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack(spacing: 10) {
                        if appState.permissionState == .denied || appState.permissionState == .unknown {
                            settingsActionButton(
                                title: L10n.actionRequestPermission,
                                icon: "lock.open.display",
                                tint: .accentWarm,
                                action: requestPermission
                            )
                        }

                        settingsActionButton(
                            title: L10n.actionSystemSettings,
                            icon: "gearshape.2",
                            tint: .accentNeutral,
                            action: openSystemSettings
                        )

                        settingsActionButton(
                            title: L10n.actionRefresh,
                            icon: "arrow.clockwise",
                            tint: .accentCool,
                            action: refreshPermission
                        )

                        settingsActionButton(
                            title: L10n.actionDiagnostics,
                            icon: "stethoscope",
                            tint: .accentNeutral,
                            action: { selectedTab = .diagnostics }
                        )
                    }
                }

                settingsCard(
                    title: "Uygulama Profilleri",
                    subtitle: appState.appProfiles.isEmpty
                        ? "Henüz kayıtlı bir uygulama profili yok."
                        : "\(appState.appProfiles.count) profil kayıtlı."
                ) {
                    Menu {
                        ForEach(profileTargets) { target in
                            Button {
                                saveProfile(for: target)
                            } label: {
                                Text(target.appName)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                            Text("Çalışan Uygulamadan Profil Oluştur")
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.accentMint.opacity(0.12))
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(profileTargets.isEmpty)
                    .opacity(profileTargets.isEmpty ? 0.55 : 1)

                    Text("Profil seçilen uygulama için mod, çıktı biçimi ve OCR dili override eder.")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    if let profileFeedback {
                        feedbackLabel(profileFeedback.message, tint: profileFeedback.tint)
                    }

                    if appState.appProfiles.isEmpty {
                        Text("Safari, Xcode veya terminal gibi uygulamalar için ayrı profiller kaydedebilirsin.")
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(appState.appProfiles) { profile in
                                profileRow(profile)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }

    private var ocrTab: some View {
        ScrollView {
            VStack(spacing: 14) {
                settingsCard(
                    title: "Tanıma Modu",
                    subtitle: "Otomatik algılamayı açabilir veya tercih ettiğin dilleri sabitleyebilirsin."
                ) {
                    Toggle(L10n.ocrAutomaticLanguage, isOn: automaticDetectionBinding)
                        .toggleStyle(.switch)
                        .accessibilityLabel(L10n.accessibilityAutomaticLanguage)

                    Text(appState.ocrLanguageSelection.automaticDetection
                         ? "Vision dilini otomatik seçer. Çok dilli kullanım için uygundur."
                         : "Aşağıdaki diller öncelikli olarak kullanılacak.")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    if let ocrFeedback {
                        feedbackLabel(ocrFeedback.message, tint: ocrFeedback.tint)
                    }
                }

                settingsCard(
                    title: "Desteklenen Diller",
                    subtitle: appState.ocrLanguageSelection.summary
                ) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 94), spacing: 10)],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(supportedOCRLanguages) { language in
                            settingsLanguageToggle(language)
                        }
                    }
                    .opacity(appState.ocrLanguageSelection.automaticDetection ? 0.56 : 1)
                    .disabled(appState.ocrLanguageSelection.automaticDetection)
                }
            }
            .padding(.bottom, 8)
        }
    }

    private var historyTab: some View {
        ScrollView {
            VStack(spacing: 14) {
                settingsCard(
                    title: "Yakalama Geçmişi",
                    subtitle: appState.copyHistory.isEmpty
                        ? "Henüz kaydedilmiş bir metin yok."
                        : "\(filteredHistoryEntries.count)/\(appState.copyHistory.count) kayıt gösteriliyor."
                ) {
                    TextField("Geçmişte ara", text: $historySearchQuery)
                        .textFieldStyle(.roundedBorder)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Dışa Aktarma Biçimi")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 120), spacing: 10)],
                            alignment: .leading,
                            spacing: 10
                        ) {
                            ForEach(ClipboardHistoryExportFormat.allCases) { format in
                                historyExportFormatButton(format)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        settingsActionButton(
                            title: L10n.actionExport,
                            icon: "square.and.arrow.up",
                            tint: .accentCool,
                            action: exportHistory
                        )
                        .disabled(filteredHistoryEntries.isEmpty)
                        .opacity(filteredHistoryEntries.isEmpty ? 0.55 : 1)

                        settingsActionButton(
                            title: L10n.actionClear,
                            icon: "trash",
                            tint: .accentRose,
                            action: clearHistory
                        )
                        .disabled(appState.copyHistory.isEmpty)
                        .opacity(appState.copyHistory.isEmpty ? 0.55 : 1)
                    }

                    if let historyFeedback {
                        feedbackLabel(historyFeedback.message, tint: historyFeedback.tint)
                    }

                    if appState.copyHistory.isEmpty {
                        historyEmptyState
                    } else if filteredHistoryEntries.isEmpty {
                        historySearchEmptyState
                    } else {
                        VStack(spacing: 10) {
                            ForEach(filteredHistoryEntries) { entry in
                                historyRow(entry)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }

    private var diagnosticsTab: some View {
        ScrollView {
            VStack(spacing: 14) {
                settingsCard(
                    title: "İzin Tanısı",
                    subtitle: permissionDiagnostics?.currentState.uiMessage ?? appState.permissionState.uiMessage
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let permissionDiagnostics {
                            diagnosticValueRow("Durum", value: permissionDiagnostics.currentState.uiMessage)
                            diagnosticValueRow("Preflight", value: permissionDiagnostics.preflightLabel)
                            diagnosticValueRow("Probe", value: permissionDiagnostics.probeState.uiMessage)
                            diagnosticValueRow(
                                "Yeniden Açma",
                                value: permissionDiagnostics.needsRestartAfterGrant ? "Gerekli" : "Gerekmiyor"
                            )
                            diagnosticValueRow("Bundle ID", value: permissionDiagnostics.bundleIdentifier)
                            diagnosticValueRow("Sürüm", value: permissionDiagnostics.versionLabel)
                            diagnosticValueRow("Uygulama", value: permissionDiagnostics.appPath)

                            if let lastProbeAt = permissionDiagnostics.lastProbeAt {
                                diagnosticValueRow(
                                    "Son Probe",
                                    value: lastProbeAt.formatted(.dateTime.day().month(.abbreviated).hour().minute().second())
                                )
                            }

                            if let lastConfirmedGrantAt = permissionDiagnostics.lastConfirmedGrantAt {
                                diagnosticValueRow(
                                    "Son Grant Kanıtı",
                                    value: lastConfirmedGrantAt.formatted(.dateTime.day().month(.abbreviated).hour().minute().second())
                                )
                            }
                        } else {
                            Text("Henüz tanı verisi yüklenmedi. Yenile ile tekrar dene.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 10) {
                            settingsActionButton(
                                title: L10n.actionRefresh,
                                icon: "arrow.clockwise",
                                tint: .accentCool,
                                action: refreshPermissionDiagnostics
                            )

                            settingsActionButton(
                                title: L10n.actionCopyDiagnostics,
                                icon: "doc.on.doc",
                                tint: .accentNeutral,
                                action: copyPermissionDiagnostics
                            )
                        }

                        HStack(spacing: 10) {
                            settingsActionButton(
                                title: L10n.actionSupportBundle,
                                icon: "square.and.arrow.up",
                                tint: .accentWarm,
                                action: exportSupportBundle
                            )

                            settingsActionButton(
                                title: L10n.actionSystemSettings,
                                icon: "gearshape.2",
                                tint: .accentNeutral,
                                action: openSystemSettings
                            )
                        }

                        if let diagnosticsFeedback {
                            feedbackLabel(diagnosticsFeedback.message, tint: diagnosticsFeedback.tint)
                        }
                    }
                }

                settingsCard(
                    title: "Uygulama Tanı Kayıtları",
                    subtitle: appState.diagnostics.isEmpty
                        ? "Henüz kayıt yok."
                        : "\(appState.diagnostics.count) kayıt son hata ve uyarıları gösteriyor."
                ) {
                    if appState.diagnostics.isEmpty {
                        Text("İzin, OCR, clipboard ve launch akışından gelen kayıtlar burada listelenecek.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(appState.diagnostics.reversed()) { entry in
                                diagnosticEntryRow(entry)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }

    private var historyEmptyState: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.secondary)

                    Text("İlk yakalamadan sonra son metinler burada listelenecek.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
    }

    private var historySearchEmptyState: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.secondary)

                    Text("Aramanla eşleşen bir geçmiş kaydı bulunamadı.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
    }

    private func historyRow(_ entry: ClipboardHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.previewText)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .lineLimit(3)

                    Text(entry.date, format: .dateTime.day().month(.abbreviated).hour().minute())
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                historyMetaBadge(entry.captureMode.title, tint: .accentWarm)
                historyMetaBadge(entry.outputPreset.title, tint: .accentMint)
                historyMetaBadge(entry.contentKind.title, tint: .accentCool)

                if let source = entry.source?.displayName {
                    historyMetaBadge(source, tint: .accentNeutral)
                }
            }

            HStack(spacing: 10) {
                if entry.captureMode == .table, entry.contentKind == .text {
                    settingsActionButton(
                        title: "Duzenle",
                        icon: "tablecells.badge.ellipsis",
                        tint: .accentMint,
                        action: { openTableReview(entry) }
                    )
                }

                settingsActionButton(
                    title: L10n.actionCopy,
                    icon: "doc.on.doc",
                    tint: .accentCool,
                    action: { copyHistoryEntry(entry) }
                )

                settingsActionButton(
                    title: L10n.actionDelete,
                    icon: "trash",
                    tint: .accentRose,
                    action: { removeHistoryEntry(entry) }
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var filteredHistoryEntries: [ClipboardHistoryEntry] {
        appState.copyHistory.filter { $0.matches(query: historySearchQuery) }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appState.launchAtLoginState.toggleIsOn },
            set: { setLaunchAtLogin($0) }
        )
    }

    private var automaticDetectionBinding: Binding<Bool> {
        Binding(
            get: { appState.ocrLanguageSelection.automaticDetection },
            set: { enabled in
                appState.setOCRAutomaticDetection(enabled)
                ocrFeedback = InlineFeedback(
                    message: enabled
                        ? "OCR artık dili otomatik algılayacak."
                        : "OCR seçtiğin dillere öncelik verecek.",
                    tint: .accentCool
                )
            }
        )
    }

    private var supportedOCRLanguages: [OCRLanguagePreference] {
        OCRService.availableLanguagePreferences
    }

    private var profileTargets: [ProfileTarget] {
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.runningApplications
            .compactMap { application -> ProfileTarget? in
                guard let bundleIdentifier = application.bundleIdentifier,
                      bundleIdentifier != ownBundleIdentifier,
                      application.activationPolicy != .prohibited else {
                    return nil
                }

                let appName = application.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let appName, !appName.isEmpty else {
                    return nil
                }

                return ProfileTarget(appName: appName, bundleIdentifier: bundleIdentifier)
            }
            .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    private var permissionTitle: String {
        switch appState.permissionState {
        case .granted:
            return "Hazır"
        case .requiresRestart:
            return "Yeniden Aç"
        case .denied:
            return "Kapalı"
        case .unknown:
            return "Belirsiz"
        case .requestInProgress:
            return "Bekliyor"
        }
    }

    private func diagnosticEntryRow(_ entry: DiagnosticEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                statusPill(entry.severity.rawValue.uppercased(), tint: tint(for: entry.severity))
                Spacer()
                Text(entry.timestamp, format: .dateTime.hour().minute().second())
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(entry.summary)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var permissionDescription: String {
        switch appState.permissionState {
        case .granted:
            return "Uygulama ekran yakalamaya hazır."
        case .requiresRestart:
            return "Yetki verildi. Uygulamayı yeniden aç."
        case .denied:
            return "macOS izin vermedi veya henüz onaylanmadı."
        case .unknown:
            return "Durum doğrulanamadı, tekrar yenile."
        case .requestInProgress:
            return "Sistem onayı bekleniyor."
        }
    }

    private var permissionTint: Color {
        switch appState.permissionState {
        case .granted:
            return .accentCool
        case .requiresRestart:
            return .accentWarm
        case .denied, .unknown:
            return .accentRose
        case .requestInProgress:
            return .accentNeutral
        }
    }

    private func diagnosticValueRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var launchAtLoginTint: Color {
        switch appState.launchAtLoginState {
        case .enabled:
            return .accentCool
        case .disabled:
            return .accentNeutral
        case .requiresApproval:
            return .accentWarm
        case .unavailable:
            return .accentRose
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private func settingsActionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                    .layoutPriority(1)
            }
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 36)
            .foregroundStyle(Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func historyMetaBadge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule(style: .continuous))
    }

    private func historyExportFormatButton(_ format: ClipboardHistoryExportFormat) -> some View {
        let isSelected = appState.historyExportFormat == format

        return Button(action: { appState.setHistoryExportFormat(format) }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(format.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))

                Text(format.subtitle)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .lineLimit(2)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.surfaceTop : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentMint.opacity(0.7) : Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Geçmiş dışa aktarma biçimi: \(format.title)")
    }

    private func outputPresetButton(_ preset: CaptureOutputPreset) -> some View {
        let isSelected = appState.captureOutputPreset == preset

        return Button(action: { setCaptureOutputPreset(preset) }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)

                Text(preset.detail)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.surfaceTop : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentMint.opacity(0.72) : Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Çıktı biçimi: \(preset.title)")
    }

    private func watchBehaviorButton(_ behavior: WatchCopyBehavior) -> some View {
        let isSelected = appState.watchConfiguration.copyBehavior == behavior

        return Button(action: { setWatchCopyBehavior(behavior) }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(behavior.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)

                Text(behavior.detail)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.surfaceTop : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentCool.opacity(0.72) : Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func profileRow(_ profile: AppCaptureProfile) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.appName)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))

                Text(profile.summary)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(profile.bundleIdentifier)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.8))
            }

            Spacer()

            settingsActionButton(
                title: L10n.actionDelete,
                icon: "trash",
                tint: .accentRose,
                action: { removeProfile(profile) }
            )
            .frame(width: 92)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private func statusPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule(style: .continuous))
    }

    private func feedbackLabel(_ message: String, tint: Color) -> some View {
        Text(message)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func settingsLanguageToggle(_ language: OCRLanguagePreference) -> some View {
        let isSelected = appState.ocrLanguageSelection.contains(language)

        return Button(action: { toggleOCRLanguage(language) }) {
            VStack(spacing: 4) {
                Text(language.shortTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(language.title)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.surfaceTop : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentCool.opacity(0.7) : Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(L10n.accessibilityOCRLanguage): \(language.title)")
    }

    private func settingsCaptureModeButton(_ mode: CaptureMode) -> some View {
        let isSelected = appState.captureMode == mode

        return Button(action: { setCaptureMode(mode) }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(mode.title)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)

                Text(settingsCaptureModeSubtitle(for: mode))
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.surfaceTop : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentWarm.opacity(0.72) : Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(L10n.accessibilityCaptureMode): \(mode.title)")
    }

    private func toggleHotkeyRecording() {
        if isRecordingHotkey {
            hotkeyFeedback = HotkeyFeedback(
                message: "Kısayol değiştirme iptal edildi.",
                tint: .accentNeutral
            )
            stopHotkeyRecording()
            return
        }

        stopHotkeyRecording()
        isRecordingHotkey = true
        hotkeyFeedback = HotkeyFeedback(
            message: "Yeni kısayol için bir kombinasyona bas.",
            tint: .accentCool
        )

        hotkeyRecorderMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleHotkeyRecording(event)
        }
    }

    private func handleHotkeyRecording(_ event: NSEvent) -> NSEvent? {
        guard isRecordingHotkey else {
            return event
        }

        if event.keyCode == UInt16(kVK_Escape) {
            hotkeyFeedback = HotkeyFeedback(
                message: "Kısayol değiştirme iptal edildi.",
                tint: .accentNeutral
            )
            stopHotkeyRecording()
            return nil
        }

        guard let configuration = HotkeyConfiguration.from(event: event) else {
            hotkeyFeedback = HotkeyFeedback(
                message: "En az bir değiştirici tuş ile geçerli bir tuş kullan.",
                tint: .accentWarm
            )
            return nil
        }

        guard let hotkeyManager = appState.hotkeyManager else {
            hotkeyFeedback = HotkeyFeedback(
                message: "Kısayol servisi şu anda hazır değil.",
                tint: .accentRose
            )
            stopHotkeyRecording()
            return nil
        }

        do {
            try hotkeyManager.updateHotkey(to: configuration)
            hotkeyFeedback = HotkeyFeedback(
                message: "Kısayol güncellendi: \(configuration.displayLabel)",
                tint: .accentCool
            )
            stopHotkeyRecording()
        } catch {
            hotkeyFeedback = HotkeyFeedback(
                message: error.localizedDescription,
                tint: .accentRose
            )
        }

        return nil
    }

    private func stopHotkeyRecording() {
        if let hotkeyRecorderMonitor {
            NSEvent.removeMonitor(hotkeyRecorderMonitor)
            self.hotkeyRecorderMonitor = nil
        }
        isRecordingHotkey = false
    }

    private func resetHotkey() {
        do {
            try appState.hotkeyManager?.resetHotkeyToDefault()
            hotkeyFeedback = HotkeyFeedback(
                message: "Kısayol varsayılana döndü: \(HotkeyConfiguration.defaultValue.displayLabel)",
                tint: .accentCool
            )
            stopHotkeyRecording()
        } catch {
            hotkeyFeedback = HotkeyFeedback(
                message: error.localizedDescription,
                tint: .accentRose
            )
        }
    }

    private func setCaptureMode(_ mode: CaptureMode) {
        guard appState.captureMode != mode else { return }
        appState.setCaptureMode(mode)
        captureModeFeedback = InlineFeedback(
            message: "\(mode.title) modu etkin. \(mode.readyDescription)",
            tint: .accentCool
        )
    }

    private func setCaptureOutputPreset(_ preset: CaptureOutputPreset) {
        guard appState.captureOutputPreset != preset else { return }
        appState.setCaptureOutputPreset(preset)
        outputPresetFeedback = InlineFeedback(
            message: "Çıktı biçimi \(preset.title) olarak ayarlandı.",
            tint: .accentCool
        )
    }

    private func setWatchCopyBehavior(_ behavior: WatchCopyBehavior) {
        guard appState.watchConfiguration.copyBehavior != behavior else { return }
        appState.setWatchCopyBehavior(behavior)
        watchFeedback = InlineFeedback(
            message: "İzleme kuralı güncellendi: \(behavior.title)",
            tint: .accentCool
        )
    }

    private func saveWatchRegex() {
        if appState.setWatchRegexFilter(watchRegexDraft) {
            watchRegexDraft = appState.watchConfiguration.regexFilter
            watchFeedback = InlineFeedback(
                message: watchRegexDraft.isEmpty
                    ? "Regex filtresi temizlendi."
                    : "Regex filtresi kaydedildi.",
                tint: .accentCool
            )
        } else {
            watchFeedback = InlineFeedback(
                message: "Regex deseni geçersiz. Örneği kontrol edip tekrar dene.",
                tint: .accentRose
            )
        }
    }

    private func clearWatchRegex() {
        watchRegexDraft = ""
        _ = appState.setWatchRegexFilter("")
        watchFeedback = InlineFeedback(
            message: "Regex filtresi temizlendi.",
            tint: .accentNeutral
        )
    }

    private func saveProfile(for target: ProfileTarget) {
        appState.upsertAppProfile(
            bundleIdentifier: target.bundleIdentifier,
            appName: target.appName
        )
        profileFeedback = InlineFeedback(
            message: "\(target.appName) için profil kaydedildi.",
            tint: .accentCool
        )
    }

    private func removeProfile(_ profile: AppCaptureProfile) {
        appState.removeAppProfile(profile)
        profileFeedback = InlineFeedback(
            message: "\(profile.appName) profili kaldırıldı.",
            tint: .accentNeutral
        )
    }

    private func settingsCaptureModeSubtitle(for mode: CaptureMode) -> String {
        switch mode {
        case .standard:
            return "Genel OCR"
        case .subtitle:
            return "Video ve canlı altyazı"
        case .code:
            return "Kod ve terminal"
        case .table:
            return "Tablo ve liste"
        }
    }

    private func refreshLaunchAtLoginState() {
        let state = appState.launchAtLoginManager?.refreshLaunchAtLoginState() ?? .unavailable
        if state != .enabled {
            launchAtLoginFeedback = nil
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        guard let launchAtLoginManager = appState.launchAtLoginManager else {
            launchAtLoginFeedback = InlineFeedback(
                message: "Başlangıç servisi şu anda hazır değil.",
                tint: .accentRose
            )
            return
        }

        Task { @MainActor in
            do {
                let state = try await launchAtLoginManager.setLaunchAtLogin(enabled: enabled)
                switch state {
                case .enabled:
                    launchAtLoginFeedback = InlineFeedback(
                        message: "Uygulama artık bilgisayar açıldığında otomatik başlayacak.",
                        tint: .accentCool
                    )
                case .disabled:
                    launchAtLoginFeedback = InlineFeedback(
                        message: "Otomatik başlatma kapatıldı.",
                        tint: .accentNeutral
                    )
                case .requiresApproval:
                    openLoginItemsSettings()
                    launchAtLoginFeedback = InlineFeedback(
                        message: "macOS ek onay istiyor. Giriş Öğeleri açıldı; onaydan sonra durum otomatik yenilenecek.",
                        tint: .accentWarm
                    )
                case .unavailable:
                    launchAtLoginFeedback = InlineFeedback(
                        message: LaunchAtLoginError.unavailable.errorDescription ?? "Bu özellik şu anda kullanılamıyor.",
                        tint: .accentRose
                    )
                }
            } catch {
                launchAtLoginFeedback = InlineFeedback(
                    message: error.localizedDescription,
                    tint: .accentRose
                )
            }
        }
    }

    private func toggleOCRLanguage(_ language: OCRLanguagePreference) {
        let enabled = !appState.ocrLanguageSelection.contains(language)
        if appState.setOCRLanguage(language, enabled: enabled) {
            ocrFeedback = InlineFeedback(
                message: "OCR dili güncellendi: \(appState.ocrLanguageSelection.summary)",
                tint: .accentCool
            )
        } else {
            ocrFeedback = InlineFeedback(
                message: "En az bir OCR dili seçili kalmalı.",
                tint: .accentWarm
            )
        }
    }

    private func copyHistoryEntry(_ entry: ClipboardHistoryEntry) {
        guard let result = appState.coordinator?.copyCapturedText(
            rawText: entry.effectiveRawText,
            captureMode: entry.captureMode,
            contentKind: entry.contentKind,
            source: entry.source,
            outputPreset: entry.outputPreset
        ) else {
            historyFeedback = InlineFeedback(
                message: "Kopyalama servisi şu anda hazır değil.",
                tint: .accentRose
            )
            return
        }

        switch result {
        case .success:
            historyFeedback = InlineFeedback(
                message: "Seçilen geçmiş metni yeniden panoya kopyalandı.",
                tint: .accentCool
            )
        case .failedWrite, .failedReadback:
            historyFeedback = InlineFeedback(
                message: "Geçmiş metni panoya yazılamadı.",
                tint: .accentRose
            )
        }
    }

    private func openTableReview(_ entry: ClipboardHistoryEntry) {
        appState.presentTableReview(for: entry)
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: ScreenTextGrabApp.tableReviewWindowID)
        historyFeedback = InlineFeedback(
            message: "Tablo duzenleyici acildi.",
            tint: .accentCool
        )
    }

    private func removeHistoryEntry(_ entry: ClipboardHistoryEntry) {
        appState.removeHistoryEntry(entry)
        historyFeedback = InlineFeedback(
            message: "Seçilen kayıt geçmişten kaldırıldı.",
            tint: .accentNeutral
        )
    }

    private func clearHistory() {
        appState.clearHistory()
        historyFeedback = InlineFeedback(
            message: "Tüm geçmiş temizlendi.",
            tint: .accentNeutral
        )
    }

    private func exportHistory() {
        let entries = filteredHistoryEntries
        guard !entries.isEmpty else {
            historyFeedback = InlineFeedback(
                message: "Dışa aktarılacak geçmiş bulunmuyor.",
                tint: .accentWarm
            )
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let exportFormat = appState.historyExportFormat

        let panel = NSSavePanel()
        panel.allowedContentTypes = [historyExportContentType(for: exportFormat)]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "ScreenTextGrab-Gecmis-\(formatter.string(from: Date())).\(exportFormat.fileExtension)"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let exportText = ClipboardHistoryStore.export(entries, format: exportFormat)
            try exportText.write(to: url, atomically: true, encoding: .utf8)
            historyFeedback = InlineFeedback(
                message: "\(entries.count) kayıt \(exportFormat.title) olarak dışa aktarıldı: \(url.lastPathComponent)",
                tint: .accentCool
            )
        } catch {
            historyFeedback = InlineFeedback(
                message: "Geçmiş dışa aktarılamadı: \(error.localizedDescription)",
                tint: .accentRose
            )
        }
    }

    private func historyExportContentType(for format: ClipboardHistoryExportFormat) -> UTType {
        switch format {
        case .text:
            return .plainText
        case .markdown:
            return UTType(filenameExtension: "md") ?? .plainText
        case .json:
            return .json
        case .csv:
            return .commaSeparatedText
        }
    }

    private func refreshPermissionDiagnostics() {
        Task { @MainActor in
            appState.coordinator?.refreshPermission()
            permissionDiagnostics = await appState.permissionDiagnosticsProvider?.diagnosticSnapshot()
            diagnosticsFeedback = InlineFeedback(
                message: "Tanı verisi güncellendi.",
                tint: .accentCool
            )
        }
    }

    private func copyPermissionDiagnostics() {
        guard let permissionDiagnostics else {
            diagnosticsFeedback = InlineFeedback(
                message: "Önce tanı verisini yenile.",
                tint: .accentWarm
            )
            return
        }

        if copyTextToPasteboard(permissionDiagnostics.reportText) {
            diagnosticsFeedback = InlineFeedback(
                message: "İzin tanısı panoya kopyalandı.",
                tint: .accentCool
            )
        } else {
            diagnosticsFeedback = InlineFeedback(
                message: "İzin tanısı panoya kopyalanamadı.",
                tint: .accentRose
            )
        }
    }

    private func exportSupportBundle() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "ScreenTextGrab-Support-\(formatter.string(from: Date())).txt"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let report = appState.buildSupportBundleReport(permissionSnapshot: permissionDiagnostics)
            try report.write(to: url, atomically: true, encoding: .utf8)
            diagnosticsFeedback = InlineFeedback(
                message: "Support paketi dışa aktarıldı: \(url.lastPathComponent)",
                tint: .accentCool
            )
        } catch {
            diagnosticsFeedback = InlineFeedback(
                message: "Support paketi dışa aktarılamadı: \(error.localizedDescription)",
                tint: .accentRose
            )
        }
    }

    private func copyTextToPasteboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    private func tint(for severity: DiagnosticSeverity) -> Color {
        switch severity {
        case .info:
            return .accentCool
        case .warning:
            return .accentWarm
        case .error:
            return .accentRose
        }
    }

    private func openLoginItemsSettings() {
        appState.launchAtLoginManager?.openLoginItemsSettings()
    }

    private func requestPermission() {
        appState.coordinator?.requestPermission()
    }

    private func refreshPermission() {
        appState.coordinator?.refreshPermission()
    }

    private func openSystemSettings() {
        appState.coordinator?.openSystemSettings()
    }
}

struct TableReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var document = TableReviewDocument(rows: [[""]])
    @State private var feedback: InlineFeedback?

    private let cellWidth: CGFloat = 176

    private var session: TableReviewSession? {
        appState.activeTableReview
    }

    private var currentPreset: CaptureOutputPreset? {
        guard let session else {
            return nil
        }

        return session.entry.outputPreset == .office ? nil : session.entry.outputPreset
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if let session {
                content(for: session)
            } else {
                emptyState
            }
        }
        .background(
            LinearGradient(
                colors: [Color.surfaceTop.opacity(0.10), Color.surfaceBottom.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear(perform: loadCurrentSession)
        .onChange(of: appState.activeTableReview?.id, initial: false) {
            loadCurrentSession()
        }
        .onDisappear {
            appState.clearTableReview()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("Tablo Duzenleyici")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("OCR ile cikan tabloyu hucre bazinda duzelt, sonra Office uyumlu sekilde yeniden kopyala.")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            if let session {
                VStack(alignment: .trailing, spacing: 8) {
                    tableReviewBadge(session.entry.captureMode.title, tint: .accentWarm)
                    tableReviewBadge(session.entry.outputPreset.title, tint: .accentMint)

                    if let source = session.entry.source?.displayName {
                        tableReviewBadge(source, tint: .accentNeutral)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.96))
    }

    private func content(for session: TableReviewSession) -> some View {
        VStack(spacing: 0) {
            tableToolbar

            Divider()

            tableGrid

            Divider()

            tableFooter
        }
    }

    private var tableToolbar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                tableReviewBadge("\(document.rowCount) Satir", tint: .accentCool)
                tableReviewBadge("\(document.columnCount) Sutun", tint: .accentMint)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    tableReviewToolButton(title: "Satir Ekle", icon: "plus", tint: .accentCool, action: addRow)
                    tableReviewToolButton(title: "Sutun Ekle", icon: "rectangle.split.3x1", tint: .accentCool, action: addColumn)
                    tableReviewToolButton(title: "Son Satiri Sil", icon: "minus", tint: .accentRose, action: removeLastRow)
                }

                HStack(spacing: 10) {
                    tableReviewToolButton(title: "Son Sutunu Sil", icon: "rectangle.split.3x1.fill", tint: .accentRose, action: removeLastColumn)
                    tableReviewToolButton(title: "Bos Kenarlari Temizle", icon: "wand.and.stars", tint: .accentWarm, action: trimEmptyEdges)
                    tableReviewToolButton(title: "Sifirla", icon: "arrow.counterclockwise", tint: .accentNeutral, action: resetDocument)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var tableGrid: some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .topLeading, horizontalSpacing: 10, verticalSpacing: 10) {
                tableHeaderRow

                ForEach(0..<document.rowCount, id: \.self) { rowIndex in
                    tableDataRow(rowIndex)
                }
            }
            .padding(24)
        }
    }

    private var tableHeaderRow: some View {
        GridRow {
            Text("")
                .frame(width: 48)

            ForEach(0..<document.columnCount, id: \.self) { columnIndex in
                Text("S\(columnIndex + 1)")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: cellWidth, alignment: .leading)
            }
        }
    }

    private func tableDataRow(_ rowIndex: Int) -> some View {
        GridRow {
            Text("\(rowIndex + 1)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            ForEach(0..<document.columnCount, id: \.self) { columnIndex in
                tableCell(rowIndex: rowIndex, columnIndex: columnIndex)
            }
        }
    }

    private func tableCell(rowIndex: Int, columnIndex: Int) -> some View {
        TextField(
            rowIndex == 0 ? "Baslik" : "Hucre",
            text: cellBinding(row: rowIndex, column: columnIndex),
            axis: .vertical
        )
        .textFieldStyle(.plain)
        .font(.system(size: 12.5, weight: rowIndex == 0 ? .semibold : .medium, design: .rounded))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: cellWidth, alignment: .topLeading)
        .frame(minHeight: rowIndex == 0 ? 52 : 46, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(rowIndex == 0 ? Color.accentCool.opacity(0.26) : Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var tableFooter: some View {
        HStack(alignment: .center, spacing: 12) {
            if let feedback {
                Text(feedback.message)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(feedback.tint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if let preset = currentPreset {
                tableReviewPrimaryButton(
                    title: "\(preset.title) ile Kopyala",
                    icon: "doc.on.doc",
                    tint: .accentNeutral
                ) {
                    copyReviewedTable(as: preset)
                }
            }

            tableReviewPrimaryButton(
                title: "Office Olarak Kopyala",
                icon: "tablecells",
                tint: .accentCool
            ) {
                copyReviewedTable(as: .office)
            }

            tableReviewPrimaryButton(
                title: "Kapat",
                icon: "xmark",
                tint: .accentRose
            ) {
                closeWindow()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "tablecells")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.secondary)

            Text("Duzeltilecek aktif bir tablo secili degil.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Text("Menu bar'dan son tabloyu ya da Gecmis sekmesindeki bir tablo kaydini acabilirsin.")
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            tableReviewPrimaryButton(
                title: "Kapat",
                icon: "xmark",
                tint: .accentNeutral
            ) {
                closeWindow()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func loadCurrentSession() {
        guard let session else {
            document = TableReviewDocument(rows: [[""]])
            feedback = nil
            return
        }

        document = TableReviewDocument(sourceText: session.sourceText)
        feedback = nil
    }

    private func cellBinding(row: Int, column: Int) -> Binding<String> {
        Binding(
            get: { document.cellValue(row: row, column: column) },
            set: { document.setCell(row: row, column: column, value: $0) }
        )
    }

    private func addRow() {
        document.appendRow()
        feedback = InlineFeedback(
            message: "Yeni satir eklendi.",
            tint: .accentCool
        )
    }

    private func addColumn() {
        document.appendColumn()
        feedback = InlineFeedback(
            message: "Yeni sutun eklendi.",
            tint: .accentCool
        )
    }

    private func removeLastRow() {
        document.removeLastRow()
        feedback = InlineFeedback(
            message: "Son satir kaldirildi.",
            tint: .accentNeutral
        )
    }

    private func removeLastColumn() {
        document.removeLastColumn()
        feedback = InlineFeedback(
            message: "Son sutun kaldirildi.",
            tint: .accentNeutral
        )
    }

    private func trimEmptyEdges() {
        document.trimEmptyEdges()
        feedback = InlineFeedback(
            message: "Bos kenarlar temizlendi.",
            tint: .accentWarm
        )
    }

    private func resetDocument() {
        guard let session else {
            return
        }

        document.reset(from: session.sourceText)
        feedback = InlineFeedback(
            message: "Tablo ilk yakalanan haline dondu.",
            tint: .accentNeutral
        )
    }

    private func copyReviewedTable(as preset: CaptureOutputPreset) {
        guard let session else {
            return
        }

        let reviewedText = document.tsvText
        guard !reviewedText.isEmpty else {
            feedback = InlineFeedback(
                message: "Kopyalanacak tablo verisi bos.",
                tint: .accentRose
            )
            return
        }

        guard let result = appState.coordinator?.copyCapturedText(
            rawText: reviewedText,
            captureMode: .table,
            contentKind: session.entry.contentKind,
            source: session.entry.source,
            outputPreset: preset
        ) else {
            feedback = InlineFeedback(
                message: "Kopyalama servisi su anda hazir degil.",
                tint: .accentRose
            )
            return
        }

        switch result {
        case .success:
            feedback = InlineFeedback(
                message: "\(preset.title) cikti panoya kopyalandi.",
                tint: .accentCool
            )
        case .failedWrite, .failedReadback:
            feedback = InlineFeedback(
                message: "Duzenlenen tablo panoya yazilamadi.",
                tint: .accentRose
            )
        }
    }

    private func closeWindow() {
        appState.clearTableReview()
        dismiss()
    }

    private func tableReviewBadge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule(style: .continuous))
    }

    private func tableReviewToolButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func tableReviewPrimaryButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.9))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct NoticeContent {
    let title: String
    let message: String
    let icon: String
    let tint: Color
}

private struct HotkeyFeedback {
    let message: String
    let tint: Color
}

private struct InlineFeedback {
    let message: String
    let tint: Color
}

private extension Color {
    static let surfaceTop = Color(red: 0.05, green: 0.11, blue: 0.15)
    static let surfaceBottom = Color(red: 0.09, green: 0.18, blue: 0.20)
    static let accentWarm = Color(red: 0.83, green: 0.57, blue: 0.36)
    static let accentWarmMuted = Color(red: 0.63, green: 0.38, blue: 0.27)
    static let accentAmber = Color(red: 0.90, green: 0.63, blue: 0.42)
    static let accentCoral = Color(red: 0.79, green: 0.39, blue: 0.32)
    static let accentCool = Color(red: 0.40, green: 0.72, blue: 0.76)
    static let accentMint = Color(red: 0.53, green: 0.83, blue: 0.76)
    static let accentNeutral = Color(red: 0.86, green: 0.90, blue: 0.91)
    static let accentRose = Color(red: 0.84, green: 0.43, blue: 0.39)
    static let cardFill = Color.white.opacity(0.074)
    static let cardStroke = Color.white.opacity(0.12)
}
