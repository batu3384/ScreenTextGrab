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
    @State private var isImportDropTargeted = false
    @State private var hotkeyRecorderMonitor: Any?

    var body: some View {
        ZStack {
            background
            panelContent
                .padding(panelPadding)

            if isImportDropTargeted {
                importDropOverlay
                    .padding(panelPadding)
            }
        }
        .frame(width: panelWidth)
        .frame(maxHeight: panelMaxHeight)
        .onDrop(of: [UTType.fileURL], isTargeted: $isImportDropTargeted, perform: handleImportDrop(providers:))
        .onChange(of: appState.settingsPresentationToken) { _, token in
            guard token != nil else { return }
            openWindow(id: ScreenTextGrabApp.settingsWindowID)
        }
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

             if let activeSavedSnippetQuickPickPanel {
                 activeSavedSnippetQuickPickPanel
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

                    if let confidenceBadge {
                        statusBadge(text: confidenceBadge.text, tint: confidenceBadge.tint)
                    }

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
                Image(systemName: primaryActionIcon)
                    .font(.system(size: isCompactPanel ? 15 : 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: isCompactPanel ? 32 : 36, height: isCompactPanel ? 32 : 36)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: isCompactPanel ? 10 : 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryActionTitle)
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
            VStack(alignment: .leading, spacing: 10) {
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

                if let actionTitle = notice.actionTitle,
                   let action = notice.action {
                    compactInlineButton(
                        title: actionTitle,
                        icon: "sparkles",
                        tint: notice.tint,
                        action: action
                    )
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if appState.permissionState == .denied || appState.permissionState == .unknown {
                    secondaryButton(title: L10n.actionAllow, icon: "lock.open.display", tint: .accentAmber, action: requestPermission)
                } else if appState.permissionState == .requiresRestart {
                    secondaryButton(title: L10n.actionSystemSettings, icon: "gearshape.2", tint: .accentNeutral, action: openSystemSettings)
                }

                secondaryButton(title: L10n.actionSettings, icon: "slider.horizontal.3", tint: .accentNeutral, action: openSettingsWindow)
                secondaryButton(title: L10n.actionRefresh, icon: "arrow.clockwise", tint: .accentMint, action: refreshPermission)
            }

            HStack(spacing: 8) {
                secondaryButton(
                    title: L10n.actionClipboardImage,
                    icon: "photo.on.rectangle",
                    tint: .accentCool,
                    action: startClipboardImageCapture
                )

                secondaryButton(
                    title: L10n.actionImageFile,
                    icon: "photo",
                    tint: .accentNeutral,
                    action: startImageFileCapture
                )
            }

            HStack(spacing: 8) {
                secondaryButton(
                    title: L10n.actionPDFFile,
                    icon: "doc.text.viewfinder",
                    tint: .accentWarm,
                    action: startPDFFileCapture
                )

                secondaryButton(
                    title: L10n.actionSearchablePDF,
                    icon: "doc.badge.gearshape",
                    tint: .accentMint,
                    action: exportSearchablePDF
                )
            }
        }
    }

    private var importDropOverlay: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.black.opacity(0.54))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.accentMint.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            )
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.accentMint)

                    Text("Görsel veya PDF bırak")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Görsel dosyası OCR’a gider, PDF dosyası doğrudan içe alınır.")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 220)
                }
                .padding(18)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
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

    private var primaryQuickStartRegion: SavedCaptureRegion? {
        guard canStartCapture else {
            return nil
        }

        return appState.primaryQuickStartRegion
    }

    private var primaryActionTitle: String {
        if primaryQuickStartRegion != nil {
            return "Kayıtlı Bölgeyi Yakala"
        }

        return canStartCapture ? "Metni Yakala" : "Yakalama Hazır Değil"
    }

    private var primaryActionIcon: String {
        primaryQuickStartRegion == nil ? "viewfinder" : "scope"
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
            if let region = primaryQuickStartRegion {
                switch appState.activeSavedCaptureRegionSuggestion?.matchKind {
                case .windowTitle(let windowTitle):
                    return "\"\(windowTitle)\" için \(region.name) otomatik seçildi."
                case .application, .none:
                    return "\(region.name) hızlı başlangıç için otomatik seçildi."
                }
            }
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

        if let activeAppProfileNotice {
            return activeAppProfileNotice
        }

        if let activeSavedRegionNotice {
            return activeSavedRegionNotice
        }

        if let activeSavedSnippetNotice {
            return activeSavedSnippetNotice
        }

        if let activeSavedSnippetCollectionNotice {
            return activeSavedSnippetCollectionNotice
        }

        if let lowConfidenceNotice {
            return lowConfidenceNotice
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

    private var activeAppProfileNotice: NoticeContent? {
        guard let suggestion = appState.activeAppProfileSuggestion else {
            return nil
        }

        let sourceName = suggestion.source.displayName
        return NoticeContent(
            title: "\(sourceName) profili hazır",
            message: "Bu uygulama için \(suggestion.profile.summary) yakalaması kayıtlı. Yakalama bu profili zaten kullanır; panelde de aynı ayarları görmek istersen eşitle.",
            icon: "sparkles.rectangle.stack",
            tint: .accentMint,
            actionTitle: "Paneli Eşitle",
            action: {
                applyActiveAppProfileSuggestion(suggestion)
            }
        )
    }

    private var activeSavedRegionNotice: NoticeContent? {
        guard let suggestion = appState.activeSavedCaptureRegionSuggestion,
              appState.watchState == .inactive,
              appState.permissionState == .granted,
              !appState.captureState.isBusy else {
            return nil
        }

        let message: String
        switch suggestion.matchKind {
        case .application:
            if suggestion.regionCount == 1 {
                message = "\(suggestion.primaryRegion.name) bu uygulama için kayıtlı. Aynı bölgeyi tek tıkla yeniden yakalayabilirsin."
            } else {
                message = "\(suggestion.regionCount) kayıtlı bölgeden en güncel olanı \(suggestion.primaryRegion.name). İstersen hemen bu bölgeyi çalıştır."
            }
        case .windowTitle(let windowTitle):
            if suggestion.regionCount == 1 {
                message = "\"\(windowTitle)\" penceresiyle eşleşen kayıtlı bölge \(suggestion.primaryRegion.name). Aynı görünümü tek tıkla yeniden yakalayabilirsin."
            } else {
                message = "\"\(windowTitle)\" penceresi için \(suggestion.regionCount) eşleşen bölge bulundu. En güncel olan \(suggestion.primaryRegion.name)."
            }
        }

        let title: String
        switch suggestion.matchKind {
        case .application:
            title = "\(suggestion.source.displayName) için kayıtlı bölge bulundu"
        case .windowTitle:
            title = "\(suggestion.source.displayName) için pencere eşleşmesi bulundu"
        }

        return NoticeContent(
            title: title,
            message: message,
            icon: "rectangle.on.rectangle.circle",
            tint: .accentCool,
            actionTitle: "Bölgeyi Çalıştır",
            action: {
                runActiveSavedCaptureRegionSuggestion(suggestion)
            }
        )
    }

    private var activeSavedSnippetCollectionNotice: NoticeContent? {
        guard let suggestion = appState.activeSavedSnippetCollectionSuggestion,
              appState.activeSavedSnippetSuggestion == nil,
              !appState.captureState.isBusy else {
            return nil
        }

        let message: String
        switch suggestion.matchKind {
        case .application:
            if suggestion.snippetCount == 1 {
                message = "\(suggestion.collection.name) koleksiyonunda \(suggestion.source.displayName) kaynaklı bir snippet hazır. Ayarlar > Geçmiş içinden doğrudan açabilirsin."
            } else {
                message = "\(suggestion.collection.name) koleksiyonunda \(suggestion.source.displayName) kaynaklı \(suggestion.snippetCount) snippet var. İlgili görünümü tek tıkla açabilirsin."
            }
        case .windowTitle(let windowTitle):
            if suggestion.snippetCount == 1 {
                message = "\"\(windowTitle)\" penceresiyle eşleşen \(suggestion.collection.name) koleksiyonunda 1 snippet var. Aynı filtreyle hızlıca açabilirsin."
            } else {
                message = "\"\(windowTitle)\" penceresiyle eşleşen \(suggestion.collection.name) koleksiyonunda \(suggestion.snippetCount) snippet var."
            }
        }

        let title: String
        switch suggestion.matchKind {
        case .application:
            title = "\(suggestion.source.displayName) snippet koleksiyonu hazır"
        case .windowTitle:
            title = "\(suggestion.source.displayName) için snippet eşleşmesi bulundu"
        }

        return NoticeContent(
            title: title,
            message: message,
            icon: "square.stack.3d.up.fill",
            tint: .accentAmber,
            actionTitle: "Koleksiyonu Aç",
            action: {
                openSavedSnippetCollectionSuggestion(suggestion)
            }
        )
    }

    private var activeSavedSnippetNotice: NoticeContent? {
        guard let suggestion = appState.activeSavedSnippetSuggestion,
              !appState.captureState.isBusy else {
            return nil
        }

        let message: String
        switch (suggestion.matchKind, suggestion.selectionKind) {
        case (.application, .onlyMatch):
            message = "\"\(suggestion.snippet.name)\" \(suggestion.collection.name) koleksiyonundan bu uygulama için hazır. Tek tıkla aynı biçimde panoya kopyalayabilirsin."
        case (.application, .learnedPreference):
            message = "\"\(suggestion.snippet.name)\" bu uygulamada daha önce kullandığın snippet olarak öne çıkarıldı. İstersen tek tıkla yeniden panoya kopyala."
        case let (.windowTitle(windowTitle), .onlyMatch):
            message = "\"\(windowTitle)\" penceresiyle eşleşen \"\(suggestion.snippet.name)\" snippet'i hazır. İstersen doğrudan panoya kopyala."
        case let (.windowTitle(windowTitle), .learnedPreference):
            message = "\"\(windowTitle)\" penceresinde daha önce kullandığın \"\(suggestion.snippet.name)\" snippet'i öne çıkarıldı."
        }

        let title: String
        switch (suggestion.matchKind, suggestion.selectionKind) {
        case (.application, .onlyMatch):
            title = "\(suggestion.source.displayName) için hazır snippet"
        case (.application, .learnedPreference):
            title = "\(suggestion.source.displayName) için öncelikli snippet"
        case (.windowTitle, .onlyMatch):
            title = "\(suggestion.source.displayName) için pencere snippet'i hazır"
        case (.windowTitle, .learnedPreference):
            title = "\(suggestion.source.displayName) için öğrenilen snippet hazır"
        }

        return NoticeContent(
            title: title,
            message: message,
            icon: "text.badge.star",
            tint: .accentAmber,
            actionTitle: "Snippet'i Kopyala",
            action: {
                copyActiveSavedSnippetSuggestion(suggestion)
            }
        )
    }

    private var activeSavedSnippetQuickPickPanel: AnyView? {
        guard let suggestion = appState.activeSavedSnippetCollectionSuggestion,
              !appState.captureState.isBusy else {
            return nil
        }

        let quickPicks = appState.activeSavedSnippetQuickPicks
        guard !quickPicks.isEmpty else {
            return nil
        }

        let hiddenCount = max(0, suggestion.snippetCount - quickPicks.count)

        return AnyView(
            card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: isCompactPanel ? 12 : 13, weight: .bold))
                            .foregroundStyle(Color.accentAmber)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hazır snippet'ler")
                                .font(.system(size: isCompactPanel ? 11 : 11.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)

                            Text(activeSavedSnippetQuickPickSummary(for: suggestion, hiddenCount: hiddenCount))
                                .font(.system(size: isCompactPanel ? 10 : 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.66))
                                .lineLimit(isCompactPanel ? 2 : 3)
                        }

                        Spacer()
                    }

                    VStack(spacing: 8) {
                        ForEach(quickPicks, id: \.id) { snippet in
                            savedSnippetQuickPickButton(snippet)
                        }
                    }
                }
            }
        )
    }

    private var confidenceBadge: (text: String, tint: Color)? {
        guard let indicator = appState.lastCopiedEntry?.confidenceIndicator else {
            return nil
        }

        switch indicator {
        case .low:
            return (indicator.shortTitle, .accentRose)
        case .medium:
            return (indicator.shortTitle, .accentAmber)
        case .high:
            return (indicator.shortTitle, .accentMint)
        }
    }

    private var lowConfidenceNotice: NoticeContent? {
        guard let entry = appState.lastCopiedEntry,
              entry.confidenceIndicator == .low,
              !appState.captureState.isBusy else {
            return nil
        }

        let message: String
        if entry.captureMode == .table {
            message = "Son tablo yakalaması düşük güvenle çıktı. Yapıştırmadan önce Tablo Düzenleyici ile satır ve sütunları kontrol etmen iyi olur."
        } else if entry.captureMode == .code {
            message = "Son kod yakalaması düşük güvenle çıktı. Özellikle girinti, noktalama ve benzer karakterleri kontrol et."
        } else {
            message = entry.confidenceIndicator?.detail ?? "Son OCR çıktısını gözden geçirmek iyi olur."
        }

        return NoticeContent(
            title: "Son OCR çıktısını kontrol et",
            message: message,
            icon: "exclamationmark.triangle.fill",
            tint: .accentRose
        )
    }

    private func startCapture() {
        if let region = primaryQuickStartRegion {
            appState.coordinator?.captureSavedRegion(region, sessionOverrides: nil)
            return
        }

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

    private func applyActiveAppProfileSuggestion(_ suggestion: ActiveAppProfileSuggestion) {
        appState.applyCaptureProfile(suggestion.profile)
        captureModeFeedback = InlineFeedback(
            message: "\(suggestion.source.displayName) profili panele uygulandı.",
            tint: .accentCool
        )
        outputPresetFeedback = nil
        ocrFeedback = nil
    }

    private func runActiveSavedCaptureRegionSuggestion(_ suggestion: ActiveSavedCaptureRegionSuggestion) {
        appState.coordinator?.captureSavedRegion(suggestion.primaryRegion, sessionOverrides: nil)
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

    private func startClipboardImageCapture() {
        appState.coordinator?.captureClipboardImage(sessionOverrides: nil)
    }

    private func startImageFileCapture() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        appState.coordinator?.captureImageFile(at: url, sessionOverrides: nil)
    }

    private func handleImportDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else {
            return false
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
            guard let data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }

            Task { @MainActor in
                routeDroppedImport(url)
            }
        }

        return true
    }

    private func routeDroppedImport(_ url: URL) {
        switch ImportedDocumentRouter.resolve(url) {
        case .image(let imageURL):
            appState.coordinator?.captureImageFile(at: imageURL, sessionOverrides: nil)
        case .pdf(let pdfURL):
            appState.coordinator?.capturePDFFile(at: pdfURL, sessionOverrides: nil)
        case nil:
            smartActionFeedback = InlineFeedback(
                message: "Yalnızca görsel veya PDF dosyaları desteklenir.",
                tint: .accentWarm
            )
        }
    }

    private func startPDFFileCapture() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        appState.coordinator?.capturePDFFile(at: url, sessionOverrides: nil)
    }

    private func exportSearchablePDF() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.pdf]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true

        guard openPanel.runModal() == .OK, let sourceURL = openPanel.url else {
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = PDFProcessingService.suggestedSearchableOutputURL(for: sourceURL).lastPathComponent

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else {
            return
        }

        appState.coordinator?.exportSearchablePDF(
            at: sourceURL,
            destinationURL: destinationURL,
            sessionOverrides: nil
        )
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
                outputPreset: preset,
                targetBundleIdentifier: appState.activeTargetBundleIdentifier
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

    private func openSavedSnippetCollectionSuggestion(_ suggestion: ActiveSavedSnippetCollectionSuggestion) {
        NSApp.activate(ignoringOtherApps: true)
        if !appState.presentSettingsForSavedSnippetCollection(named: suggestion.collection.name) {
            appState.statusMessage = "⚠️ Snippet koleksiyonu bulunamadı: \(suggestion.collection.name)"
        }
    }

    private func copyActiveSavedSnippetSuggestion(_ suggestion: ActiveSavedSnippetSuggestion) {
        guard let result = appState.coordinator?.copySavedSnippet(suggestion.snippet) else {
            smartActionFeedback = InlineFeedback(
                message: "Snippet servisi şu anda hazır değil.",
                tint: .accentRose
            )
            return
        }

        switch result {
        case .success:
            smartActionFeedback = InlineFeedback(
                message: "\(suggestion.snippet.name) panoya kopyalandı.",
                tint: .accentCool
            )
        case .failedWrite, .failedReadback:
            smartActionFeedback = InlineFeedback(
                message: "Snippet panoya yazılamadı.",
                tint: .accentRose
            )
        }
    }

    private func activeSavedSnippetQuickPickSummary(
        for suggestion: ActiveSavedSnippetCollectionSuggestion,
        hiddenCount: Int
    ) -> String {
        let base: String
        switch suggestion.matchKind {
        case .application:
            base = "\(suggestion.source.displayName) için \(suggestion.collection.name) koleksiyonundaki en uygun snippet'ler listelendi."
        case .windowTitle(let windowTitle):
            base = "\"\(windowTitle)\" penceresine uyan snippet'ler \(suggestion.collection.name) koleksiyonundan getirildi."
        }

        guard hiddenCount > 0 else {
            return base
        }

        return "\(base) +\(hiddenCount) ek eşleşme daha var."
    }

    private func savedSnippetQuickPickButton(_ snippet: SavedSnippet) -> some View {
        Button(action: { copyQuickPickSnippet(snippet) }) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(snippet.name)
                        .font(.system(size: isCompactPanel ? 11 : 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(snippet.previewText)
                        .font(.system(size: isCompactPanel ? 9.5 : 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.68))
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 6) {
                    quickPickBadge(snippet.captureMode.shortTitle, tint: Color.accentWarm)
                    quickPickBadge(snippet.outputPreset.title, tint: Color.accentMint)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(snippet.name) snippet'ini kopyala")
    }

    private func copyQuickPickSnippet(_ snippet: SavedSnippet) {
        guard let result = appState.coordinator?.copySavedSnippet(snippet) else {
            smartActionFeedback = InlineFeedback(
                message: "Snippet servisi şu anda hazır değil.",
                tint: .accentRose
            )
            return
        }

        switch result {
        case .success:
            smartActionFeedback = InlineFeedback(
                message: "\(snippet.name) panoya kopyalandı.",
                tint: .accentCool
            )
        case .failedWrite, .failedReadback:
            smartActionFeedback = InlineFeedback(
                message: "Snippet panoya yazılamadı.",
                tint: .accentRose
            )
        }
    }

    private func quickPickBadge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: isCompactPanel ? 8.5 : 9, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.14))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

enum SettingsTab: String, Hashable {
    case general
    case ocr
    case diagnostics
    case history
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
            outputPreset: preset,
            targetBundleIdentifier: appState.activeTargetBundleIdentifier
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
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
}

struct HotkeyFeedback {
    let message: String
    let tint: Color
}

struct InlineFeedback {
    let message: String
    let tint: Color
}

extension Color {
    static let surfaceTop = Color(red: 0.05, green: 0.11, blue: 0.15)
    static let surfaceBottom = Color(red: 0.09, green: 0.18, blue: 0.20)
    static let accentWarm = Color(red: 0.83, green: 0.57, blue: 0.36)
    static let accentAmber = Color(red: 0.90, green: 0.63, blue: 0.42)
    static let accentCoral = Color(red: 0.79, green: 0.39, blue: 0.32)
    static let accentCool = Color(red: 0.40, green: 0.72, blue: 0.76)
    static let accentMint = Color(red: 0.53, green: 0.83, blue: 0.76)
    static let accentNeutral = Color(red: 0.86, green: 0.90, blue: 0.91)
    static let accentRose = Color(red: 0.84, green: 0.43, blue: 0.39)
    static let cardFill = Color.white.opacity(0.074)
    static let cardStroke = Color.white.opacity(0.12)
}
