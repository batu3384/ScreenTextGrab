import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var appState: AppState
    @State private var captureModeFeedback: InlineFeedback?
    @State private var outputPresetFeedback: InlineFeedback?
    @State private var ocrFeedback: InlineFeedback?
    @State private var smartActionFeedback: InlineFeedback?
    @State private var isImportDropTargeted = false

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
        isCompactPanel ? 348 : 374
    }

    private var panelPadding: CGFloat {
        isCompactPanel ? 11 : 13
    }

    private var sectionSpacing: CGFloat {
        isCompactPanel ? 9 : 11
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

                quickSettingRow(
                    title: L10n.pair("Çıktı Biçimi", "Output Format"),
                    detail: L10n.pair("Panoya kopyalanacak biçimi belirle.", "Choose the format copied to the clipboard.")
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
                                .foregroundStyle(.white.opacity(0.9))

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
                        .padding(.vertical, 7)
                        .frame(minWidth: isCompactPanel ? 146 : 160, alignment: .leading)
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

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                watchRow

                if let captureModeFeedback {
                    feedbackText(captureModeFeedback.message, tint: captureModeFeedback.tint)
                }

                if let outputPresetFeedback {
                    feedbackText(outputPresetFeedback.message, tint: outputPresetFeedback.tint)
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
                                compactInlineButton(
                                    title: action.title,
                                    icon: action.icon,
                                    tint: .accentNeutral,
                                    action: { performSmartAction(action) }
                                )
                            }

                            if canOfferSpeechAction {
                                compactInlineButton(
                                    title: appState.speechState == .speaking ? L10n.pair("Durdur", "Stop") : L10n.pair("Sesli Oku", "Read Aloud"),
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
                .fill(Color.accentCool.opacity(0.16))
                .frame(width: 168, height: 168)
                .blur(radius: 36)
                .offset(x: 54, y: -52)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color.accentWarm.opacity(0.12))
                .frame(width: 184, height: 184)
                .blur(radius: 42)
                .offset(x: -56, y: 70)
        }
        .overlay {
            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.clear, Color.black.opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
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
                    .font(.system(size: isCompactPanel ? 15 : 16.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(headerLine)
                    .font(.system(size: isCompactPanel ? 10 : 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            HStack(spacing: 7) {
                updateActionButton

                iconActionButton(
                    systemName: "power",
                    tint: .accentRose,
                    accessibilityLabel: L10n.accessibilityQuitApp,
                    action: quitApp
                )
            }
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
                    colors: canStartCapture ? [.accentAmber, .accentCoral] : [Color.controlFillStrong, Color.controlFill],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(canStartCapture ? Color.white.opacity(0.14) : Color.controlStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: canStartCapture ? Color.black.opacity(0.18) : .clear, radius: 12, y: 8)
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
            if shouldShowPermissionActions {
                HStack(spacing: 8) {
                    if appState.permissionState == .denied || appState.permissionState == .unknown {
                        secondaryButton(title: L10n.actionAllow, icon: "lock.open.display", tint: .accentAmber, action: requestPermission)
                    } else if appState.permissionState == .requiresRestart {
                        secondaryButton(title: L10n.actionSystemSettings, icon: "gearshape.2", tint: .accentNeutral, action: openSystemSettings)
                    }

                    secondaryButton(title: L10n.actionRefresh, icon: "arrow.clockwise", tint: .accentMint, action: refreshPermission)
                }
            }

            HStack(spacing: 8) {
                importMenuButton
                secondaryButton(title: L10n.actionSettings, icon: "slider.horizontal.3", tint: .accentNeutral, action: openSettingsWindow)
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

                    Text(L10n.pair("Görsel veya PDF bırak", "Drop an Image or PDF"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(L10n.pair("Görsel dosyası OCR’a gider, PDF dosyası doğrudan içe alınır.", "Image files go through OCR, and PDF files are imported directly."))
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
                statusBadge(text: watchStatusTitle, tint: watchTint)
                smallActionButton(
                    title: watchActionTitle,
                    icon: watchActionIcon,
                    tint: watchTint,
                    action: toggleWatching
                )
            }
        }
        .padding(.vertical, 1)
    }

    private var importMenuButton: some View {
        Menu {
            Button(action: startClipboardImageCapture) {
                Label(L10n.actionClipboardImage, systemImage: "photo.on.rectangle")
            }

            Button(action: startImageFileCapture) {
                Label(L10n.actionImageFile, systemImage: "photo")
            }

            Button(action: startPDFFileCapture) {
                Label(L10n.actionPDFFile, systemImage: "doc.text.viewfinder")
            }

            Button(action: exportSearchablePDF) {
                Label(L10n.actionSearchablePDF, systemImage: "doc.badge.gearshape")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down")
                    .frame(width: isCompactPanel ? 11 : 12)

                Text(L10n.pair("İçe Aktar", "Import"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.64))
            }
            .font(.system(size: isCompactPanel ? 9.6 : 10.2, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, isCompactPanel ? 10 : 11)
            .padding(.vertical, isCompactPanel ? 7 : 8)
            .frame(maxWidth: .infinity, minHeight: isCompactPanel ? 40 : 42)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.controlFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.accentCool.opacity(0.13))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.controlStrokeStrong, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel(L10n.pair("İçe Aktar", "Import"))
    }

    private func smallActionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .frame(width: isCompactPanel ? 10 : 11)
                Text(title)
            }
            .font(.system(size: isCompactPanel ? 9.5 : 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, isCompactPanel ? 10 : 11)
            .padding(.vertical, isCompactPanel ? 6.5 : 7.5)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.controlFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tint.opacity(0.14))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.controlStrokeStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var shouldShowPermissionActions: Bool {
        appState.permissionState == .denied ||
        appState.permissionState == .unknown ||
        appState.permissionState == .requiresRestart
    }

    private var watchStatusTitle: String {
        switch appState.watchState {
        case .active:
            return L10n.pair("Açık", "On")
        case .selecting:
            return L10n.pair("Seçim", "Selecting")
        case .inactive:
            return L10n.pair("Kapalı", "Off")
        }
    }

    private var watchSummary: String {
        switch appState.watchState {
        case .active:
            return L10n.pair("Seçilen alan arka planda izleniyor.", "The selected region is being watched in the background.")
        case .selecting:
            return L10n.pair("İzlenecek alanı seçmen bekleniyor.", "Waiting for you to pick a region to watch.")
        case .inactive:
            return L10n.pair("Tekrar eden içerikleri otomatik izle.", "Automatically monitor repeating content.")
        }
    }

    private var watchActionTitle: String {
        appState.watchState == .active || appState.watchState == .selecting
            ? L10n.pair("Durdur", "Stop")
            : L10n.pair("Başlat", "Start")
    }

    private var watchActionIcon: String {
        appState.watchState == .active || appState.watchState == .selecting ? "stop.fill" : "dot.scope"
    }

    private func compactInlineButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .frame(width: isCompactPanel ? 11 : 12)
                Text(title)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: isCompactPanel ? 9.6 : 10.1, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, isCompactPanel ? 9 : 10)
            .padding(.vertical, isCompactPanel ? 6.5 : 7.5)
            .frame(maxWidth: .infinity, minHeight: isCompactPanel ? 34 : 36)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.controlFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tint.opacity(0.13))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.controlStrokeStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .padding(isCompactPanel ? 11 : 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.04), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
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
                    .font(.system(size: isCompactPanel ? 11.5 : 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.system(size: isCompactPanel ? 10 : 10.3, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            control()
        }
    }

    private func statusBadge(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: isCompactPanel ? 10 : 10.5, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.controlFill)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(tint.opacity(0.13))
                    )
            )
    }

    private func secondaryButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .frame(width: isCompactPanel ? 11 : 12)
                Text(title)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: isCompactPanel ? 9.6 : 10.2, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, isCompactPanel ? 10 : 11)
            .padding(.vertical, isCompactPanel ? 7 : 8)
            .frame(maxWidth: .infinity, minHeight: isCompactPanel ? 40 : 42)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.controlFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(tint.opacity(0.12))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.controlStrokeStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var updateActionButton: some View {
        Button(action: performUpdateAction) {
            HStack(spacing: 6) {
                Image(systemName: appState.updateState.buttonIcon)
                    .font(.system(size: isCompactPanel ? 9 : 10, weight: .bold))

                Text(updateButtonTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
            }
            .font(.system(size: isCompactPanel ? 8.9 : 9.8, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, isCompactPanel ? 10 : 11)
            .padding(.vertical, isCompactPanel ? 6 : 7)
            .frame(width: updateButtonWidth, height: isCompactPanel ? 32 : 34)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.controlFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(updateButtonTint.opacity(updateButtonBackgroundOpacity))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(updateButtonTint.opacity(0.48), lineWidth: 1)
            )
            .shadow(color: updateButtonTint.opacity(appState.updateManager == nil ? 0 : 0.16), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(appState.updateState.isBusy || appState.updateManager == nil)
        .opacity(appState.updateManager == nil ? 0.62 : 1)
        .help(appState.updateState.helpText)
        .accessibilityLabel(appState.updateState.accessibilityLabel)
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
                .frame(width: isCompactPanel ? 30 : 32, height: isCompactPanel ? 30 : 32)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.controlFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(tint.opacity(0.12))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.controlStrokeStrong, lineWidth: 1)
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
        let tint = captureModeTint(for: mode)

        return Button(action: { setCaptureMode(mode) }) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: captureModeIcon(for: mode))
                        .font(.system(size: isCompactPanel ? 9.5 : 10.5, weight: .bold))
                        .foregroundStyle(isSelected ? .white : tint)
                        .frame(width: isCompactPanel ? 22 : 24, height: isCompactPanel ? 22 : 24)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? Color.white.opacity(0.14) : tint.opacity(0.12))
                        )
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

    private func captureModeTint(for mode: CaptureMode) -> Color {
        switch mode {
        case .standard:
            return .accentCool
        case .subtitle:
            return .accentMint
        case .code:
            return .accentNeutral
        case .table:
            return .accentWarm
        }
    }

    private var updateButtonTitle: String {
        switch appState.updateState {
        case .idle:
            return L10n.pair("Kontrol Et", "Check")
        case .checking:
            return L10n.pair("Kontrol...", "Checking...")
        case .downloading(_, let progressPercent):
            guard let progressPercent else {
                return L10n.pair("İndiriliyor", "Downloading")
            }
            return "\(progressPercent)%"
        case .readyToInstall:
            return L10n.pair("Yeniden Başlat", "Restart & Update")
        case .upToDate:
            return L10n.pair("Güncel", "Up to Date")
        case .failed:
            return L10n.pair("Tekrar Dene", "Retry")
        }
    }

    private var updateButtonWidth: CGFloat {
        switch appState.updateState {
        case .idle, .upToDate:
            return isCompactPanel ? 92 : 100
        case .checking:
            return isCompactPanel ? 106 : 118
        case .downloading:
            return isCompactPanel ? 88 : 96
        case .readyToInstall:
            return isCompactPanel ? 118 : 138
        case .failed:
            return isCompactPanel ? 102 : 112
        }
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
            return L10n.pair("Genel OCR", "General OCR")
        case .subtitle:
            return L10n.pair("Video ve altyazı", "Video and subtitles")
        case .code:
            return L10n.pair("Kod ve terminal", "Code and terminal")
        case .table:
            return L10n.pair("Tablo ve liste", "Tables and lists")
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
            return L10n.pair("Kayıtlı Bölgeyi Yakala", "Capture Saved Region")
        }

        return canStartCapture ? L10n.pair("Metni Yakala", "Capture Text") : L10n.pair("Yakalama Hazır Değil", "Capture Unavailable")
    }

    private var primaryActionIcon: String {
        primaryQuickStartRegion == nil ? "viewfinder" : "scope"
    }

    private var headerLine: String {
        if appState.captureMode == .subtitle {
            return appState.isHotkeyAvailable
                ? L10n.format("%@ ile video ve canlı altyazı yakala.", "Capture video and live subtitles with %@.", appState.hotkeyDisplayLabel)
                : L10n.pair("Video ve canlı altyazılar için optimize.", "Optimized for video and live subtitles.")
        }

        if appState.captureMode == .code {
            return appState.isHotkeyAvailable
                ? L10n.format("%@ ile kod blokları ve terminal çıktıları yakala.", "Capture code blocks and terminal output with %@.", appState.hotkeyDisplayLabel)
                : L10n.pair("Kod blokları ve terminal çıktıları için optimize.", "Optimized for code blocks and terminal output.")
        }

        if appState.captureMode == .table {
            return appState.isHotkeyAvailable
                ? L10n.format("%@ ile tablo ve çok sütunlu listeleri yakala.", "Capture tables and multi-column lists with %@.", appState.hotkeyDisplayLabel)
                : L10n.pair("Tablo ve çok sütunlu içerikler için optimize.", "Optimized for tables and multi-column content.")
        }

        if appState.isHotkeyAvailable {
            return L10n.format("%@ ile veya panelden başlat.", "Start with %@ or from the panel.", appState.hotkeyDisplayLabel)
        }

        return L10n.pair("Ekrandaki metni tek adımda yakala.", "Capture on-screen text in one step.")
    }

    private var statusTitle: String {
        if appState.watchState == .active {
            return L10n.pair("İzleme Aktif", "Watch Active")
        }

        if appState.watchState == .selecting {
            return L10n.pair("İzleme Seçimi", "Watch Selection")
        }

        switch appState.captureState {
        case .idle:
            return appState.permissionState == .granted ? L10n.pair("Hazır", "Ready") : L10n.pair("Kurulum Gerekli", "Setup Required")
        case .preparing:
            return L10n.pair("Hazırlanıyor", "Preparing")
        case .selecting:
            return L10n.pair("Alan Seçiliyor", "Selecting Region")
        case .capturing:
            return L10n.pair("Görüntü Alınıyor", "Capturing Image")
        case .recognizing:
            return L10n.pair("Metin Tanınıyor", "Recognizing Text")
        case .copying:
            return L10n.pair("Panoya Yazılıyor", "Writing to Clipboard")
        case .completed:
            return L10n.pair("Kopyalandı", "Copied")
        case .completedEmpty:
            return L10n.pair("Metin Bulunamadı", "No Text Found")
        case .failed:
            return L10n.pair("İşlem Başarısız", "Action Failed")
        case .cancelled:
            return L10n.pair("İptal Edildi", "Cancelled")
        }
    }

    private var statusDescription: String {
        if appState.watchState == .active {
            return L10n.pair("Seçilen alan arka planda izleniyor. Yeni içerik algılanırsa pano otomatik güncellenir.", "The selected region is being watched in the background. The clipboard updates automatically when new content appears.")
        }

        if appState.watchState == .selecting {
            return L10n.pair("İzlenecek alanı seçmen bekleniyor. ESC ile iptal edebilirsin.", "Waiting for you to select a region to watch. Press ESC to cancel.")
        }

        switch appState.permissionState {
        case .granted:
            if appState.captureState == .idle || appState.captureState == .completed || appState.captureState == .cancelled {
                if let region = primaryQuickStartRegion {
                    switch appState.activeSavedCaptureRegionSuggestion?.matchKind {
                    case .windowTitle(let windowTitle):
                        return L10n.usesEnglish
                            ? "\(region.name) is ready for “\(windowTitle)”. The main button runs this saved region directly."
                            : "\"\(windowTitle)\" için \(region.name) hazır. Ana düğme bu kayıtlı bölgeyi doğrudan çalıştırır."
                    case .application, .none:
                        return L10n.format(
                            "%@ hızlı başlangıç için hazır. Ana düğme bu kayıtlı bölgeyi doğrudan çalıştırır.",
                            "%@ is ready for quick start. The main button runs this saved region directly.",
                            region.name
                        )
                    }
                }

                return appState.isHotkeyAvailable
                    ? (
                        L10n.usesEnglish
                            ? "Screen recording access is active. Start \(appState.captureMode.title.lowercased()) capture with \(appState.hotkeyDisplayLabel) or use the button below."
                            : "Ekran kaydı izni aktif. \(appState.hotkeyDisplayLabel) ile veya aşağıdaki butonla \(appState.captureMode.title.lowercased()) yakalamayı başlatabilirsin."
                    )
                    : (
                        L10n.usesEnglish
                            ? "Screen recording access is active. You can start capture directly in \(appState.captureMode.title) mode."
                            : "Ekran kaydı izni aktif. \(appState.captureMode.title) modunda doğrudan yakalama başlatabilirsin."
                    )
            }
            return appState.statusMessage
        case .requiresRestart:
            return L10n.pair("İzin verildi ancak yeni yetkiyi almak için uygulamayı yeniden açman gerekiyor.", "Access was granted, but you need to reopen the app to pick up the new permission.")
        case .denied:
            return L10n.pair("Ekran kaydı izni kapalı görünüyor. İzin verdiysen Yenile'ye bas.", "Screen recording access appears to be off. Press Refresh if you already granted it.")
        case .unknown:
            return L10n.pair("İzin durumu şu anda doğrulanamadı. Sistem Ayarları veya Yenile ile tekrar kontrol et.", "The permission status could not be verified right now. Check again from System Settings or Refresh.")
        case .requestInProgress:
            return L10n.pair("İzin penceresi açık. Onay verdikten sonra durum otomatik güncellenecek.", "The permission prompt is open. Status updates automatically after you approve it.")
        }
    }

    private var primarySubtitle: String {
        if appState.watchState == .active {
            return L10n.pair("İzleme aktifken normal yakalama devre dışı.", "Normal capture is disabled while watch mode is active.")
        }

        if appState.watchState == .selecting {
            return L10n.pair("Önce izlenecek alanı seç.", "Select the watched region first.")
        }

        switch appState.permissionState {
        case .granted:
            if let region = primaryQuickStartRegion {
                switch appState.activeSavedCaptureRegionSuggestion?.matchKind {
                case .windowTitle(let windowTitle):
                    return L10n.format("\"%@\" için %@ kullanılacak.", "Using %@ for \"%@\".", region.name, windowTitle)
                case .application, .none:
                    return L10n.format("%@ hızlı başlangıç için otomatik seçildi.", "%@ was auto-selected for quick start.", region.name)
                }
            }
            return appState.captureMode.readyDescription
        case .requiresRestart:
            return L10n.pair("Önce uygulamayı yeniden aç.", "Reopen the app first.")
        case .denied:
            return L10n.pair("Önce ekran kaydı iznini etkinleştir.", "Enable screen recording permission first.")
        case .unknown:
            return L10n.pair("Önce izin durumunu doğrula.", "Verify the permission status first.")
        case .requestInProgress:
            return L10n.pair("İzin işlemi tamamlanınca yakalama açılacak.", "Capture will be available once the permission flow finishes.")
        }
    }

    private var permissionBadge: String {
        switch appState.permissionState {
        case .granted: return L10n.pair("Açık", "On")
        case .requiresRestart: return L10n.pair("Yeniden Aç", "Reopen")
        case .denied: return L10n.pair("Kapalı", "Off")
        case .unknown: return L10n.pair("Belirsiz", "Unknown")
        case .requestInProgress: return L10n.pair("Bekliyor", "Pending")
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
                title: L10n.pair("İzleme açık", "Watch is on"),
                message: L10n.pair("Seçilen bölgede metin değişirse yeni içerik otomatik olarak panoya kopyalanır.", "If text changes inside the selected region, the new content is copied automatically."),
                icon: "dot.radiowaves.left.and.right",
                tint: .accentMint
            )
        }

        if appState.permissionState == .requiresRestart {
            return NoticeContent(
                title: L10n.pair("Yeniden başlatma gerekiyor", "Restart required"),
                message: L10n.pair("macOS yeni ekran kaydı iznini bir sonraki açılışta uyguluyor.", "macOS applies the new screen recording permission on the next launch."),
                icon: "power.circle",
                tint: .accentAmber
            )
        }

        if !appState.isHotkeyAvailable {
            return NoticeContent(
                title: L10n.pair("Global kısayol etkin değil", "Global shortcut unavailable"),
                message: L10n.pair("Seçili kombinasyon başka bir uygulamayla çakışıyor veya sistem hotkey kaydı tamamlanamadı. Farklı bir kombinasyon deneyebilirsin.", "The selected combination conflicts with another app or the system hotkey registration could not finish. Try a different shortcut."),
                icon: "bolt.horizontal.circle",
                tint: .accentNeutral
            )
        }

        if appState.launchAtLoginState == .requiresApproval {
            return NoticeContent(
                title: L10n.pair("Açılış ayarı onay bekliyor", "Launch setting needs approval"),
                message: L10n.pair("macOS giriş öğesi değişikliğini hemen uygulamamış olabilir. Ayarlar penceresinden Giriş Öğeleri'ni açabilirsin.", "macOS may not have applied the login item change yet. You can open Login Items from Settings."),
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
                title: L10n.pair("Son hata", "Latest error"),
                message: lastError.errorDescription ?? L10n.pair("Beklenmeyen bir hata oluştu.", "An unexpected error occurred."),
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
            title: L10n.format("%@ profili hazır", "%@ profile is ready", sourceName),
            message: L10n.format("Bu uygulama için %@ yakalaması kayıtlı. Yakalama bu profili zaten kullanır; panelde de aynı ayarları görmek istersen eşitle.", "A %@ capture profile is saved for this app. Capture already uses it; sync the panel if you want to see the same settings there.", suggestion.profile.summary),
            icon: "sparkles.rectangle.stack",
            tint: .accentMint,
            actionTitle: L10n.pair("Paneli Eşitle", "Sync Panel"),
            action: {
                applyActiveAppProfileSuggestion(suggestion)
            }
        )
    }

    private var activeSavedRegionNotice: NoticeContent? {
        guard let suggestion = appState.activeSavedCaptureRegionSuggestion,
              primaryQuickStartRegion == nil,
              appState.watchState == .inactive,
              appState.permissionState == .granted,
              !appState.captureState.isBusy else {
            return nil
        }

        let message: String
        switch suggestion.matchKind {
        case .application:
            if suggestion.regionCount == 1 {
                message = L10n.format("%@ bu uygulama için kayıtlı. Aynı bölgeyi tek tıkla yeniden yakalayabilirsin.", "%@ is saved for this app. You can recapture the same region with one click.", suggestion.primaryRegion.name)
            } else {
                message = L10n.usesEnglish
                    ? "\(suggestion.primaryRegion.name) is the newest of \(suggestion.regionCount) saved regions for this app. Run it right away if you want."
                    : "\(suggestion.regionCount) kayıtlı bölgeden en güncel olanı \(suggestion.primaryRegion.name). İstersen hemen bu bölgeyi çalıştır."
            }
        case .windowTitle(let windowTitle):
            if suggestion.regionCount == 1 {
                message = L10n.usesEnglish
                    ? "The saved region \(suggestion.primaryRegion.name) matches the “\(windowTitle)” window. You can recapture the same view with one click."
                    : "\"\(windowTitle)\" penceresiyle eşleşen kayıtlı bölge \(suggestion.primaryRegion.name). Aynı görünümü tek tıkla yeniden yakalayabilirsin."
            } else {
                message = L10n.usesEnglish
                    ? "\(suggestion.regionCount) matching regions were found for the “\(windowTitle)” window. The newest one is \(suggestion.primaryRegion.name)."
                    : "\"\(windowTitle)\" penceresi için \(suggestion.regionCount) eşleşen bölge bulundu. En güncel olan \(suggestion.primaryRegion.name)."
            }
        }

        let title: String
        switch suggestion.matchKind {
        case .application:
            title = L10n.format("%@ için kayıtlı bölge bulundu", "Saved region found for %@", suggestion.source.displayName)
        case .windowTitle:
            title = L10n.format("%@ için eşleşen pencere bölgesi hazır", "Window-ready region for %@", suggestion.source.displayName)
        }

        return NoticeContent(
            title: title,
            message: message,
            icon: "rectangle.on.rectangle.circle",
            tint: .accentCool,
            actionTitle: L10n.pair("Bölgeyi Çalıştır", "Run Region"),
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
                message = L10n.usesEnglish
                    ? "One snippet from \(suggestion.source.displayName) is ready in the \(suggestion.collection.name) collection. You can open it directly from Settings > History."
                    : "\(suggestion.collection.name) koleksiyonunda \(suggestion.source.displayName) kaynaklı bir snippet hazır. Ayarlar > Geçmiş içinden doğrudan açabilirsin."
            } else {
                message = L10n.usesEnglish
                    ? "There are \(suggestion.snippetCount) snippets from \(suggestion.source.displayName) in the \(suggestion.collection.name) collection. Open the filtered view with one click."
                    : "\(suggestion.collection.name) koleksiyonunda \(suggestion.source.displayName) kaynaklı \(suggestion.snippetCount) snippet var. İlgili görünümü tek tıkla açabilirsin."
            }
        case .windowTitle(let windowTitle):
            if suggestion.snippetCount == 1 {
                message = L10n.usesEnglish
                    ? "There is 1 snippet in the \(suggestion.collection.name) collection that matches the “\(windowTitle)” window. Open it quickly with the same filter."
                    : "\"\(windowTitle)\" penceresiyle eşleşen \(suggestion.collection.name) koleksiyonunda 1 snippet var. Aynı filtreyle hızlıca açabilirsin."
            } else {
                message = L10n.usesEnglish
                    ? "There are \(suggestion.snippetCount) snippets in the \(suggestion.collection.name) collection that match the “\(windowTitle)” window."
                    : "\"\(windowTitle)\" penceresiyle eşleşen \(suggestion.collection.name) koleksiyonunda \(suggestion.snippetCount) snippet var."
            }
        }

        let title: String
        switch suggestion.matchKind {
        case .application:
            title = L10n.format("%@ snippet koleksiyonu hazır", "%@ snippet collection is ready", suggestion.source.displayName)
        case .windowTitle:
            title = L10n.format("%@ için eşleşen snippet koleksiyonu hazır", "Snippet collection ready for %@", suggestion.source.displayName)
        }

        return NoticeContent(
            title: title,
            message: message,
            icon: "square.stack.3d.up.fill",
            tint: .accentAmber,
            actionTitle: L10n.pair("Koleksiyonu Aç", "Open Collection"),
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
            message = L10n.usesEnglish
                ? "\"\(suggestion.snippet.name)\" from the \(suggestion.collection.name) collection is ready for this app. Copy it to the clipboard in one click."
                : "\"\(suggestion.snippet.name)\" \(suggestion.collection.name) koleksiyonundan bu uygulama için hazır. Tek tıkla aynı biçimde panoya kopyalayabilirsin."
        case (.application, .learnedPreference):
            message = L10n.usesEnglish
                ? "\"\(suggestion.snippet.name)\" was promoted because you used it in this app before. Copy it back to the clipboard in one click if you want."
                : "\"\(suggestion.snippet.name)\" bu uygulamada daha önce kullandığın snippet olarak öne çıkarıldı. İstersen tek tıkla yeniden panoya kopyala."
        case let (.windowTitle(windowTitle), .onlyMatch):
            message = L10n.usesEnglish
                ? "\"\(suggestion.snippet.name)\" is ready for the “\(windowTitle)” window. Copy it directly to the clipboard if you want."
                : "\"\(windowTitle)\" penceresiyle eşleşen \"\(suggestion.snippet.name)\" snippet'i hazır. İstersen doğrudan panoya kopyala."
        case let (.windowTitle(windowTitle), .learnedPreference):
            message = L10n.usesEnglish
                ? "\"\(suggestion.snippet.name)\" was promoted because you used it before in the “\(windowTitle)” window."
                : "\"\(windowTitle)\" penceresinde daha önce kullandığın \"\(suggestion.snippet.name)\" snippet'i öne çıkarıldı."
        }

        let title: String
        switch (suggestion.matchKind, suggestion.selectionKind) {
        case (.application, .onlyMatch):
            title = L10n.format("%@ için hazır snippet", "Ready snippet for %@", suggestion.source.displayName)
        case (.application, .learnedPreference):
            title = L10n.format("%@ için öncelikli snippet", "Preferred snippet for %@", suggestion.source.displayName)
        case (.windowTitle, .onlyMatch):
            title = L10n.format("%@ için pencere snippet'i hazır", "Window snippet ready for %@", suggestion.source.displayName)
        case (.windowTitle, .learnedPreference):
            title = L10n.format("%@ için öğrenilen snippet hazır", "Learned snippet ready for %@", suggestion.source.displayName)
        }

        return NoticeContent(
            title: title,
            message: message,
            icon: "text.badge.star",
            tint: .accentAmber,
            actionTitle: L10n.pair("Snippet'i Kopyala", "Copy Snippet"),
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
                            Text(L10n.pair("Hazır snippet'ler", "Ready snippets"))
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
            message = L10n.pair("Son tablo yakalaması düşük güvenle çıktı. Yapıştırmadan önce Tablo Düzenleyici ile satır ve sütunları kontrol etmen iyi olur.", "The last table capture was produced with low confidence. Review rows and columns in the Table Editor before pasting.")
        } else if entry.captureMode == .code {
            message = L10n.pair("Son kod yakalaması düşük güvenle çıktı. Özellikle girinti, noktalama ve benzer karakterleri kontrol et.", "The last code capture was produced with low confidence. Check indentation, punctuation, and similar characters carefully.")
        } else {
            message = entry.confidenceIndicator?.detail ?? L10n.pair("Son OCR çıktısını gözden geçirmek iyi olur.", "It is a good idea to review the latest OCR output.")
        }

        return NoticeContent(
            title: L10n.pair("Son OCR çıktısını kontrol et", "Review the latest OCR result"),
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

    private var updateButtonTint: Color {
        switch appState.updateState {
        case .idle:
            return .accentMint
        case .checking:
            return .accentCool
        case .downloading:
            return .accentAmber
        case .readyToInstall:
            return .accentCool
        case .upToDate:
            return .accentMint
        case .failed:
            return .accentRose
        }
    }

    private var updateButtonBackgroundOpacity: Double {
        switch appState.updateState {
        case .idle:
            return 0.22
        case .checking:
            return 0.18
        case .downloading:
            return 0.2
        case .readyToInstall:
            return 0.24
        case .upToDate:
            return 0.16
        case .failed:
            return 0.2
        }
    }

    private func performUpdateAction() {
        appState.updateManager?.performPrimaryUpdateAction()
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
                Text(L10n.pair("Tablo Duzenleyici", "Table Editor"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(L10n.pair("OCR ile cikan tabloyu hucre bazinda duzelt, sonra Office uyumlu sekilde yeniden kopyala.", "Fix the OCR table cell by cell, then copy it again in an Office-friendly format."))
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
                tableReviewBadge(L10n.usesEnglish ? "\(document.rowCount) Rows" : "\(document.rowCount) Satir", tint: .accentCool)
                tableReviewBadge(L10n.usesEnglish ? "\(document.columnCount) Columns" : "\(document.columnCount) Sutun", tint: .accentMint)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    tableReviewToolButton(title: L10n.pair("Satir Ekle", "Add Row"), icon: "plus", tint: .accentCool, action: addRow)
                    tableReviewToolButton(title: L10n.pair("Sutun Ekle", "Add Column"), icon: "rectangle.split.3x1", tint: .accentCool, action: addColumn)
                    tableReviewToolButton(title: L10n.pair("Son Satiri Sil", "Remove Last Row"), icon: "minus", tint: .accentRose, action: removeLastRow)
                }

                HStack(spacing: 10) {
                    tableReviewToolButton(title: L10n.pair("Son Sutunu Sil", "Remove Last Column"), icon: "rectangle.split.3x1.fill", tint: .accentRose, action: removeLastColumn)
                    tableReviewToolButton(title: L10n.pair("Bos Kenarlari Temizle", "Trim Empty Edges"), icon: "wand.and.stars", tint: .accentWarm, action: trimEmptyEdges)
                    tableReviewToolButton(title: L10n.pair("Sifirla", "Reset"), icon: "arrow.counterclockwise", tint: .accentNeutral, action: resetDocument)
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
            rowIndex == 0 ? L10n.pair("Baslik", "Header") : L10n.pair("Hucre", "Cell"),
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
                    title: L10n.usesEnglish ? "Copy as \(preset.title)" : "\(preset.title) ile Kopyala",
                    icon: "doc.on.doc",
                    tint: .accentNeutral
                ) {
                    copyReviewedTable(as: preset)
                }
            }

            tableReviewPrimaryButton(
                title: L10n.pair("Office Olarak Kopyala", "Copy as Office"),
                icon: "tablecells",
                tint: .accentCool
            ) {
                copyReviewedTable(as: .office)
            }

            tableReviewPrimaryButton(
                title: L10n.pair("Kapat", "Close"),
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

            Text(L10n.pair("Duzeltilecek aktif bir tablo secili degil.", "No active table is selected for review."))
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Text(L10n.pair("Menu bar'dan son tabloyu ya da Gecmis sekmesindeki bir tablo kaydini acabilirsin.", "Open the latest table from the menu bar or a table entry from the History tab."))
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            tableReviewPrimaryButton(
                title: L10n.pair("Kapat", "Close"),
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
            message: L10n.pair("Yeni satir eklendi.", "A new row was added."),
            tint: .accentCool
        )
    }

    private func addColumn() {
        document.appendColumn()
        feedback = InlineFeedback(
            message: L10n.pair("Yeni sutun eklendi.", "A new column was added."),
            tint: .accentCool
        )
    }

    private func removeLastRow() {
        document.removeLastRow()
        feedback = InlineFeedback(
            message: L10n.pair("Son satir kaldirildi.", "The last row was removed."),
            tint: .accentNeutral
        )
    }

    private func removeLastColumn() {
        document.removeLastColumn()
        feedback = InlineFeedback(
            message: L10n.pair("Son sutun kaldirildi.", "The last column was removed."),
            tint: .accentNeutral
        )
    }

    private func trimEmptyEdges() {
        document.trimEmptyEdges()
        feedback = InlineFeedback(
            message: L10n.pair("Bos kenarlar temizlendi.", "Empty edges were trimmed."),
            tint: .accentWarm
        )
    }

    private func resetDocument() {
        guard let session else {
            return
        }

        document.reset(from: session.sourceText)
        feedback = InlineFeedback(
            message: L10n.pair("Tablo ilk yakalanan haline dondu.", "The table was reset to its original captured state."),
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
                message: L10n.pair("Kopyalanacak tablo verisi bos.", "There is no table data to copy."),
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
                message: L10n.pair("Kopyalama servisi su anda hazir degil.", "The copy service is not ready right now."),
                tint: .accentRose
            )
            return
        }

        switch result {
        case .success:
            feedback = InlineFeedback(
                message: L10n.usesEnglish ? "\(preset.title) output was copied to the clipboard." : "\(preset.title) cikti panoya kopyalandi.",
                tint: .accentCool
            )
        case .failedWrite, .failedReadback:
            feedback = InlineFeedback(
                message: L10n.pair("Duzenlenen tablo panoya yazilamadi.", "The reviewed table could not be written to the clipboard."),
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
    static let surfaceTop = Color(red: 0.03, green: 0.07, blue: 0.11)
    static let surfaceBottom = Color(red: 0.07, green: 0.12, blue: 0.18)
    static let accentWarm = Color(red: 0.57, green: 0.73, blue: 0.86)
    static let accentAmber = Color(red: 0.70, green: 0.85, blue: 0.95)
    static let accentCoral = Color(red: 0.47, green: 0.76, blue: 0.90)
    static let accentCool = Color(red: 0.52, green: 0.82, blue: 0.96)
    static let accentMint = Color(red: 0.63, green: 0.90, blue: 0.93)
    static let accentNeutral = Color(red: 0.86, green: 0.93, blue: 0.97)
    static let accentRose = Color(red: 0.51, green: 0.66, blue: 0.80)
    static let cardFill = Color(red: 0.10, green: 0.15, blue: 0.20).opacity(0.90)
    static let cardStroke = Color.white.opacity(0.08)
    static let controlFill = Color(red: 0.96, green: 0.99, blue: 1.0).opacity(0.055)
    static let controlFillStrong = Color(red: 0.96, green: 0.99, blue: 1.0).opacity(0.082)
    static let controlStroke = Color(red: 0.80, green: 0.90, blue: 0.98).opacity(0.12)
    static let controlStrokeStrong = Color(red: 0.80, green: 0.90, blue: 0.98).opacity(0.18)
}
