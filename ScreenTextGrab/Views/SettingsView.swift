import AppKit
import Carbon
import SwiftUI
import UniformTypeIdentifiers

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
    @State private var languageFeedback: InlineFeedback?
    @State private var historyFeedback: InlineFeedback?
    @State private var savedRegionFeedback: InlineFeedback?
    @State private var snippetFeedback: InlineFeedback?
    @State private var profileFeedback: InlineFeedback?
    @State private var diagnosticsFeedback: InlineFeedback?
    @State private var permissionDiagnostics: PermissionDiagnosticSnapshot?
    @State private var historySearchQuery = ""
    @State private var showPinnedOnlyHistory = false
    @State private var snippetSearchQuery = ""
    @State private var selectedSnippetTag: String?
    @State private var selectedSnippetCollectionID: UUID?
    @State private var isEditingSnippetCollection = false
    @State private var snippetCollectionDraft = ""
    @State private var editingSnippetTagSnippetID: UUID?
    @State private var snippetTagDraft = ""
    @State private var watchRegexDraft = ""
    @State private var hotkeyRecorderMonitor: Any?

    init(initialTab: SettingsTab = .general) {
        _selectedTab = State(initialValue: initialTab)
    }

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
            applyPendingSnippetCollectionSelectionIfNeeded()
            applyActiveSavedSnippetCollectionSuggestionIfNeeded(forceFeedback: false)
        }
        .onChange(of: appState.settingsPresentationToken) { _, _ in
            applyPendingSnippetCollectionSelectionIfNeeded()
        }
        .onChange(of: selectedTab) { _, newTab in
            guard newTab == .history else {
                return
            }

            applyActiveSavedSnippetCollectionSuggestionIfNeeded(forceFeedback: false)
        }
        .onChange(of: appState.activeSourceApp?.displayContextName) { _, _ in
            applyActiveSavedSnippetCollectionSuggestionIfNeeded(forceFeedback: true)
        }
        .onChange(of: appState.savedSnippetCollectionAutoSyncEnabled) { _, enabled in
            guard enabled else {
                return
            }

            applyActiveSavedSnippetCollectionSuggestionIfNeeded(forceFeedback: false)
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
                    title: L10n.pair("Arayüz Dili", "Interface Language"),
                    subtitle: appState.interfaceLanguage.detail
                ) {
                    Picker("", selection: interfaceLanguageBinding) {
                        ForEach(InterfaceLanguage.allCases) { language in
                            Text(language.title)
                                .tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(L10n.accessibilityInterfaceLanguage)

                    Text(L10n.pair("Menü paneli ve ayarlar için sistemden bağımsız bir dil seçebilirsin.", "Choose a language for the menu panel and settings independently from macOS."))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let languageFeedback {
                        feedbackLabel(languageFeedback.message, tint: languageFeedback.tint)
                    }
                }

                settingsCard(
                    title: L10n.pair("Yakalama Modu", "Capture Mode"),
                    subtitle: L10n.pair("Metin, altyazı, kod veya tablo odaklı yakalama arasında geçiş yap.", "Switch between text, subtitle, code, or table-focused capture.")
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
                    title: L10n.pair("Çıktı Biçimi", "Output Format"),
                    subtitle: appState.captureOutputPreset.detail
                ) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 152), spacing: 12)],
                        alignment: .leading,
                        spacing: 12
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
                    title: L10n.pair("Global Kısayol", "Global Shortcut"),
                    subtitle: isRecordingHotkey
                        ? L10n.pair("Yeni kombinasyonu gir. Esc ile iptal edebilirsin.", "Enter the new combination. Press Esc to cancel.")
                        : L10n.pair("Yakalamayı her yerden başlatmak için kullanılır.", "Use it to start capture from anywhere.")
                ) {
                    HStack(spacing: 10) {
                        Button(action: toggleHotkeyRecording) {
                            Text(isRecordingHotkey ? L10n.pair("Tuşa Bas...", "Press Keys...") : appState.hotkeyDisplayLabel)
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
                    title: L10n.pair("Açılışta Başlat", "Launch at Login"),
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
                    title: L10n.pair("İzleme Kuralları", "Watch Rules"),
                    subtitle: appState.watchConfiguration.summary
                ) {
                    HStack(spacing: 10) {
                        ForEach(WatchCopyBehavior.allCases) { behavior in
                            watchBehaviorButton(behavior)
                        }
                    }

                    TextField(L10n.pair("İsteğe bağlı regex filtresi", "Optional regex filter"), text: $watchRegexDraft)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 10) {
                        settingsActionButton(
                            title: L10n.pair("Regex'i Kaydet", "Save Regex"),
                            icon: "checkmark.circle",
                            tint: .accentCool,
                            action: saveWatchRegex
                        )

                        settingsActionButton(
                            title: L10n.pair("Temizle", "Clear"),
                            icon: "eraser",
                            tint: .accentNeutral,
                            action: clearWatchRegex
                        )
                    }

                    Text(L10n.pair("Regex doluysa izleme yalnızca eşleşen parçaları kopyalar.", "If the regex is filled in, watch mode copies only matching segments."))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    if let watchFeedback {
                        feedbackLabel(watchFeedback.message, tint: watchFeedback.tint)
                    }
                }

                settingsCard(
                    title: L10n.pair("Ekran Kaydı İzni", "Screen Recording Permission"),
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
                    title: L10n.pair("Uygulama Profilleri", "App Profiles"),
                    subtitle: appState.appProfiles.isEmpty
                        ? L10n.pair("Henüz kayıtlı bir uygulama profili yok.", "No app profile has been saved yet.")
                        : L10n.usesEnglish ? "\(appState.appProfiles.count) saved profiles." : "\(appState.appProfiles.count) profil kayıtlı."
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
                            Text(L10n.pair("Çalışan Uygulamadan Profil Oluştur", "Create Profile from Running App"))
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

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.pair("Akıllı Panel Senkronu", "Smart Panel Sync"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))

                            Text(L10n.pair("Aktif uygulama değiştiğinde kayıtlı profil varsa paneldeki mod, çıktı biçimi ve OCR dili onunla eşitlenir.", "When the active app changes, the panel syncs its mode, output format, and OCR language if a saved profile exists."))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Toggle("", isOn: appProfilePanelAutoSyncBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Text(L10n.pair("Profil seçilen uygulama için mod, çıktı biçimi ve OCR dili override eder.", "A profile overrides the mode, output format, and OCR language for the selected app."))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    if let profileFeedback {
                        feedbackLabel(profileFeedback.message, tint: profileFeedback.tint)
                    }

                    if appState.appProfiles.isEmpty {
                        Text(L10n.pair("Safari, Xcode veya terminal gibi uygulamalar için ayrı profiller kaydedebilirsin.", "You can save separate profiles for apps like Safari, Xcode, or Terminal."))
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
                    title: L10n.pair("Tanıma Modu", "Recognition Mode"),
                    subtitle: L10n.pair("Otomatik algılamayı açabilir veya tercih ettiğin dilleri sabitleyebilirsin.", "Turn on automatic detection or pin the languages you prefer.")
                ) {
                    Toggle(L10n.ocrAutomaticLanguage, isOn: automaticDetectionBinding)
                        .toggleStyle(.switch)
                        .accessibilityLabel(L10n.accessibilityAutomaticLanguage)

                    Text(appState.ocrLanguageSelection.automaticDetection
                         ? L10n.pair("Vision dilini otomatik seçer. Çok dilli kullanım için uygundur.", "Vision chooses the language automatically. This is ideal for multilingual use.")
                         : L10n.pair("Aşağıdaki diller öncelikli olarak kullanılacak.", "The languages below will be prioritized."))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    if let ocrFeedback {
                        feedbackLabel(ocrFeedback.message, tint: ocrFeedback.tint)
                    }
                }

                settingsCard(
                    title: L10n.pair("Desteklenen Diller", "Supported Languages"),
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
                    title: L10n.pair("Kayıtlı Bölgeler", "Saved Regions"),
                    subtitle: appState.savedCaptureRegions.isEmpty
                        ? L10n.pair("Son yakalanan alanları daha sonra tek tıkla tekrar kullanmak için kaydet.", "Save recently captured regions so you can reuse them with one click later.")
                        : L10n.usesEnglish ? "\(appState.savedCaptureRegions.count) saved regions." : "\(appState.savedCaptureRegions.count) bölge kayıtlı."
                ) {
                    HStack(spacing: 10) {
                        settingsActionButton(
                            title: L10n.pair("Son Alanı Kaydet", "Save Last Region"),
                            icon: "rectangle.badge.plus",
                            tint: .accentMint,
                            action: saveLastCaptureRegion
                        )
                        .disabled(appState.lastCaptureSelection == nil)
                        .opacity(appState.lastCaptureSelection == nil ? 0.55 : 1)

                        settingsActionButton(
                            title: L10n.pair("Son Alanı Tekrar Yakala", "Repeat Last Region"),
                            icon: "arrow.clockwise",
                            tint: .accentCool,
                            action: repeatLastCapture
                        )
                        .disabled(appState.lastCaptureSelection == nil)
                        .opacity(appState.lastCaptureSelection == nil ? 0.55 : 1)
                    }

                    Text(L10n.pair("Kayıtlı bir bölgeyi daha sonra tek tıkla yeniden yakalayabilir, istersen son seçiminle güncelleyebilirsin.", "You can recapture a saved region later with one click, or refresh it with your latest selection."))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.pair("Akıllı Başlangıç", "Smart Start"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))

                            Text(L10n.pair("Aktif uygulama veya pencereyle eşleşen kayıtlı bölge varsa ana yakalama düğmesi onu çalıştırır.", "If a saved region matches the active app or window, the main capture button runs it directly."))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Toggle("", isOn: savedRegionQuickStartBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    if let savedRegionFeedback {
                        feedbackLabel(savedRegionFeedback.message, tint: savedRegionFeedback.tint)
                    }

                    if appState.savedCaptureRegions.isEmpty {
                        Text(L10n.pair("Bir alan yakaladıktan sonra burada kalıcı bölge olarak saklayabilirsin.", "After capturing a region, you can keep it here as a permanent saved region."))
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(appState.savedCaptureRegions) { region in
                                savedCaptureRegionRow(region)
                            }
                        }
                    }
                }

                settingsCard(
                    title: L10n.pair("Kayıtlı Snippet'lar", "Saved Snippets"),
                    subtitle: appState.savedSnippets.isEmpty
                        ? L10n.pair("Tekrar kullanacağın sonuçları ayrı bir snippet koleksiyonunda sakla.", "Save reusable results in a separate snippet collection.")
                        : L10n.usesEnglish ? "\(appState.savedSnippets.count) saved snippets. Filter them like a collection with tags and search." : "\(appState.savedSnippets.count) snippet kayıtlı. Etiket ve aramayla koleksiyon gibi filtreleyebilirsin."
                ) {
                    HStack(spacing: 10) {
                        settingsActionButton(
                            title: L10n.pair("Son Sonucu Kaydet", "Save Latest Result"),
                            icon: "bookmark.badge.plus",
                            tint: .accentMint,
                            action: saveLastCopiedSnippet
                        )
                        .disabled(appState.lastCopiedEntry == nil)
                        .opacity(appState.lastCopiedEntry == nil ? 0.55 : 1)
                    }

                    Text(L10n.pair("Snippet'lar yakalama geçmişinden bağımsız olarak tek tıkla yeniden kopyalanır ve aynı çıktı biçimini korur.", "Snippets can be copied again with one click independently of capture history while preserving the same output format."))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.pair("Akıllı Koleksiyon Senkronu", "Smart Collection Sync"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))

                            Text(L10n.pair("Geçmiş sekmesi açıksa, aktif uygulamaya uyan kayıtlı snippet koleksiyonu otomatik uygulanır.", "If the History tab is open, the saved snippet collection matching the active app is applied automatically."))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Toggle("", isOn: savedSnippetCollectionAutoSyncBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    TextField(L10n.pair("Snippet ara", "Search snippets"), text: $snippetSearchQuery)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: snippetSearchQuery) { _, _ in
                            syncSelectedSnippetCollection()
                        }

                    HStack(spacing: 10) {
                        settingsActionButton(
                            title: L10n.pair("Filtreyi Kaydet", "Save Filter"),
                            icon: "square.stack.badge.plus",
                            tint: .accentAmber,
                            action: beginSnippetCollectionEditing
                        )
                        .disabled(!hasActiveSnippetFilters)
                        .opacity(hasActiveSnippetFilters ? 1 : 0.55)
                    }

                    if isEditingSnippetCollection {
                        HStack(spacing: 10) {
                            TextField(L10n.pair("Koleksiyon adı", "Collection name"), text: $snippetCollectionDraft)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    commitSnippetCollectionDraft()
                                }

                            settingsActionButton(
                                title: L10n.pair("Kaydet", "Save"),
                                icon: "checkmark",
                                tint: .accentMint,
                                action: commitSnippetCollectionDraft
                            )
                            .disabled(snippetCollectionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasActiveSnippetFilters)
                            .opacity(
                                snippetCollectionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasActiveSnippetFilters
                                    ? 0.55
                                    : 1
                            )

                            settingsActionButton(
                                title: L10n.pair("Vazgec", "Cancel"),
                                icon: "xmark",
                                tint: .accentNeutral,
                                action: cancelSnippetCollectionEditing
                            )
                        }
                    }

                    if !appState.savedSnippetCollections.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(appState.savedSnippetCollections) { collection in
                                    savedSnippetCollectionChip(collection)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    if !appState.availableSnippetTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                snippetFilterChip(title: L10n.pair("Tümü", "All"), isSelected: selectedSnippetTag == nil) {
                                    selectedSnippetTag = nil
                                    syncSelectedSnippetCollection()
                                }

                                ForEach(appState.availableSnippetTags, id: \.self) { tag in
                                    snippetFilterChip(title: tag, isSelected: selectedSnippetTag == tag) {
                                        selectedSnippetTag = selectedSnippetTag == tag ? nil : tag
                                        syncSelectedSnippetCollection()
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    if let snippetFeedback {
                        feedbackLabel(snippetFeedback.message, tint: snippetFeedback.tint)
                    }

                    if filteredSavedSnippets.isEmpty {
                        Text(snippetEmptyStateMessage)
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(filteredSavedSnippets) { snippet in
                                savedSnippetRow(snippet)
                            }
                        }
                    }
                }

                settingsCard(
                    title: L10n.pair("Yakalama Geçmişi", "Capture History"),
                    subtitle: appState.copyHistory.isEmpty
                        ? L10n.pair("Henüz kaydedilmiş bir metin yok.", "No captured text has been saved yet.")
                        : L10n.usesEnglish ? "Showing \(filteredHistoryEntries.count)/\(orderedHistoryEntries.count) items • \(appState.pinnedHistoryCount) pinned." : "\(filteredHistoryEntries.count)/\(orderedHistoryEntries.count) kayıt gösteriliyor • \(appState.pinnedHistoryCount) sabit."
                ) {
                    TextField(L10n.pair("Geçmişte ara", "Search history"), text: $historySearchQuery)
                        .textFieldStyle(.roundedBorder)

                    Toggle(L10n.pair("Yalnızca Sabitler", "Pinned Only"), isOn: $showPinnedOnlyHistory)
                        .toggleStyle(.switch)
                        .tint(.accentAmber)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.pair("Dışa Aktarma Biçimi", "Export Format"))
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
                    title: L10n.pair("İzin Tanısı", "Permission Diagnostics"),
                    subtitle: permissionDiagnostics?.currentState.uiMessage ?? appState.permissionState.uiMessage
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let permissionDiagnostics {
                            diagnosticValueRow(L10n.pair("Durum", "Status"), value: permissionDiagnostics.currentState.uiMessage)
                            diagnosticValueRow("Preflight", value: permissionDiagnostics.preflightLabel)
                            diagnosticValueRow("Probe", value: permissionDiagnostics.probeState.uiMessage)
                            diagnosticValueRow(
                                L10n.pair("Yeniden Açma", "Reopen"),
                                value: permissionDiagnostics.needsRestartAfterGrant ? L10n.pair("Gerekli", "Required") : L10n.pair("Gerekmiyor", "Not Needed")
                            )
                            diagnosticValueRow("Bundle ID", value: permissionDiagnostics.bundleIdentifier)
                            diagnosticValueRow(L10n.pair("Sürüm", "Version"), value: permissionDiagnostics.versionLabel)
                            diagnosticValueRow(L10n.pair("Uygulama", "App"), value: permissionDiagnostics.appPath)

                            if let lastProbeAt = permissionDiagnostics.lastProbeAt {
                                diagnosticValueRow(
                                    L10n.pair("Son Probe", "Last Probe"),
                                    value: lastProbeAt.formatted(.dateTime.day().month(.abbreviated).hour().minute().second())
                                )
                            }

                            if let lastConfirmedGrantAt = permissionDiagnostics.lastConfirmedGrantAt {
                                diagnosticValueRow(
                                    L10n.pair("Son Grant Kanıtı", "Last Grant Evidence"),
                                    value: lastConfirmedGrantAt.formatted(.dateTime.day().month(.abbreviated).hour().minute().second())
                                )
                            }
                        } else {
                            Text(L10n.pair("Henüz tanı verisi yüklenmedi. Yenile ile tekrar dene.", "No diagnostics have been loaded yet. Try Refresh again."))
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
                    title: L10n.pair("Uygulama Tanı Kayıtları", "App Diagnostic Logs"),
                    subtitle: appState.diagnostics.isEmpty
                        ? L10n.pair("Henüz kayıt yok.", "No logs yet.")
                        : L10n.usesEnglish ? "\(appState.diagnostics.count) entries showing the latest warnings and errors." : "\(appState.diagnostics.count) kayıt son hata ve uyarıları gösteriyor."
                ) {
                    if appState.diagnostics.isEmpty {
                        Text(L10n.pair("İzin, OCR, clipboard ve launch akışından gelen kayıtlar burada listelenecek.", "Entries from permission, OCR, clipboard, and launch flows will appear here."))
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

                    Text(L10n.pair("İlk yakalamadan sonra son metinler burada listelenecek.", "Your recent text captures will appear here after the first capture."))
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

                    Text(L10n.pair("Aramanla eşleşen bir geçmiş kaydı bulunamadı.", "No history entry matched your search."))
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

                Button(action: { togglePinnedHistoryEntry(entry) }) {
                    Image(systemName: entry.isPinned ? "star.fill" : "star")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(entry.isPinned ? Color.accentAmber : Color.secondary.opacity(0.8))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill((entry.isPinned ? Color.accentAmber : Color.white).opacity(entry.isPinned ? 0.18 : 0.08))
                        )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                if entry.isPinned {
                    historyMetaBadge(L10n.pair("Sabit", "Pinned"), tint: .accentAmber)
                }
                historyMetaBadge(entry.captureMode.title, tint: .accentWarm)
                historyMetaBadge(entry.outputPreset.title, tint: .accentMint)
                historyMetaBadge(entry.contentKind.title, tint: .accentCool)

                if let indicator = entry.confidenceIndicator {
                    historyMetaBadge(indicator.shortTitle, tint: historyConfidenceTint(for: indicator))
                }

                if let source = entry.source?.displayName {
                    historyMetaBadge(source, tint: .accentNeutral)
                }
            }

            HStack(spacing: 10) {
                if entry.captureMode == .table, entry.contentKind == .text {
                    settingsActionButton(
                        title: L10n.pair("Duzenle", "Edit"),
                        icon: "tablecells.badge.ellipsis",
                        tint: .accentMint,
                        action: { openTableReview(entry) }
                    )
                }

                settingsActionButton(
                    title: entry.isPinned ? L10n.pair("Sabiti Kaldır", "Unpin") : L10n.pair("Sabitle", "Pin"),
                    icon: entry.isPinned ? "star.slash" : "star",
                    tint: .accentAmber,
                    action: { togglePinnedHistoryEntry(entry) }
                )

                settingsActionButton(
                    title: L10n.pair("Snippet Yap", "Create Snippet"),
                    icon: "bookmark.badge.plus",
                    tint: .accentMint,
                    action: { saveSnippet(from: entry) }
                )

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
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(entry.isPinned ? Color.accentAmber.opacity(0.42) : Color.clear, lineWidth: 1)
        )
    }

    private func savedCaptureRegionRow(_ region: SavedCaptureRegion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(region.name)
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))

                    Text(region.summary)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(region.updatedAt, format: .dateTime.day().month(.abbreviated).hour().minute())
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.8))
                }

                Spacer()

                statusPill(region.sessionConfiguration.captureMode.shortTitle, tint: .accentWarm)
            }

            HStack(spacing: 8) {
                historyMetaBadge(region.sessionConfiguration.outputPreset.title, tint: .accentMint)

                if let sourceName = region.source?.displayName {
                    historyMetaBadge(sourceName, tint: .accentNeutral)
                }

                if let windowTitle = region.source?.windowTitle {
                    historyMetaBadge(windowTitle, tint: .accentCool)
                }
            }

            HStack(spacing: 10) {
                settingsActionButton(
                    title: L10n.pair("Yakala", "Capture"),
                    icon: "viewfinder",
                    tint: .accentCool,
                    action: { captureSavedRegion(region) }
                )

                settingsActionButton(
                    title: L10n.pair("Güncelle", "Update"),
                    icon: "arrow.triangle.2.circlepath",
                    tint: .accentAmber,
                    action: { refreshSavedCaptureRegion(region) }
                )
                .disabled(appState.lastCaptureSelection == nil)
                .opacity(appState.lastCaptureSelection == nil ? 0.55 : 1)

                settingsActionButton(
                    title: L10n.actionDelete,
                    icon: "trash",
                    tint: .accentRose,
                    action: { removeSavedCaptureRegion(region) }
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

    private func savedSnippetRow(_ snippet: SavedSnippet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snippet.name)
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))

                    Text(snippet.previewText)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(snippet.updatedAt, format: .dateTime.day().month(.abbreviated).hour().minute())
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.8))
                }

                Spacer()

                statusPill(snippet.captureMode.shortTitle, tint: .accentWarm)
            }

            HStack(spacing: 8) {
                historyMetaBadge(snippet.outputPreset.title, tint: .accentMint)
                historyMetaBadge(snippet.contentKind.title, tint: .accentCool)

                if let indicator = snippet.confidenceIndicator {
                    historyMetaBadge(indicator.shortTitle, tint: historyConfidenceTint(for: indicator))
                }

                if let sourceName = snippet.source?.displayName {
                    historyMetaBadge(sourceName, tint: .accentNeutral)
                }
            }

            if !snippet.tags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(snippet.tags.prefix(4)), id: \.self) { tag in
                        historyMetaBadge("#\(tag)", tint: .accentAmber)
                    }
                }
            }

            HStack(spacing: 10) {
                snippetTagMenu(snippet)

                settingsActionButton(
                    title: L10n.actionCopy,
                    icon: "doc.on.doc",
                    tint: .accentCool,
                    action: { copySavedSnippet(snippet) }
                )

                settingsActionButton(
                    title: L10n.actionDelete,
                    icon: "trash",
                    tint: .accentRose,
                    action: { removeSavedSnippet(snippet) }
                )
            }

            if editingSnippetTagSnippetID == snippet.id {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        TextField(L10n.pair("Yeni etiket", "New tag"), text: $snippetTagDraft)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                commitSnippetTagDraft(for: snippet)
                            }

                        settingsActionButton(
                            title: L10n.pair("Ekle", "Add"),
                            icon: "plus",
                            tint: .accentAmber,
                            action: { commitSnippetTagDraft(for: snippet) }
                        )
                        .disabled(snippetTagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(snippetTagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)

                        settingsActionButton(
                            title: L10n.pair("Vazgec", "Cancel"),
                            icon: "xmark",
                            tint: .accentNeutral,
                            action: cancelSnippetTagEditing
                        )
                    }

                    let quickTags = appState.availableSnippetTags.filter { candidate in
                        !snippet.tags.contains(where: {
                            $0.compare(candidate, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                        })
                    }

                    if !quickTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(quickTags.prefix(6)), id: \.self) { tag in
                                    snippetFilterChip(title: "+\(tag)", isSelected: false) {
                                        addSnippetTag(tag, to: snippet)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private func snippetTagMenu(_ snippet: SavedSnippet) -> some View {
        Menu {
            let suggestedTags = appState.suggestedTags(for: snippet)
            let availableTags = mergeSnippetTagCandidates(appState.availableSnippetTags, with: suggestedTags)

            if availableTags.isEmpty {
                Button(L10n.pair("Etiket yok", "No tags")) {}
                    .disabled(true)
            } else {
                ForEach(availableTags, id: \.self) { tag in
                    Button {
                        toggleSnippetTag(tag, for: snippet)
                    } label: {
                        if snippet.tags.contains(where: {
                            $0.compare(tag, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                        }) {
                            Label(tag, systemImage: "checkmark")
                        } else {
                            Text(tag)
                        }
                    }
                }
            }

            Divider()

            Button(L10n.pair("Yeni Etiket Ekle", "Add New Tag")) {
                beginSnippetTagEditing(for: snippet)
            }

            if !snippet.tags.isEmpty {
                Divider()

                Button(L10n.pair("Etiketleri Temizle", "Clear Tags"), role: .destructive) {
                    appState.updateSavedSnippetTags([], for: snippet)
                    snippetFeedback = InlineFeedback(
                        message: L10n.usesEnglish ? "Tags were cleared for \(snippet.name)." : "\(snippet.name) için etiketler temizlendi.",
                        tint: .accentNeutral
                    )
                    if let selectedSnippetTag,
                       !appState.availableSnippetTags.contains(where: {
                           $0.compare(selectedSnippetTag, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                       }) {
                        self.selectedSnippetTag = nil
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "tag")
                Text(L10n.pair("Etiketler", "Tags"))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.accentAmber)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.accentAmber.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var filteredHistoryEntries: [ClipboardHistoryEntry] {
        orderedHistoryEntries.filter { entry in
            entry.matches(query: historySearchQuery) &&
            (!showPinnedOnlyHistory || entry.isPinned)
        }
    }

    private var filteredSavedSnippets: [SavedSnippet] {
        appState.savedSnippets.filter { snippet in
            let matchesTag: Bool
            if let selectedSnippetTag {
                matchesTag = snippet.tags.contains {
                    $0.compare(selectedSnippetTag, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                }
            } else {
                matchesTag = true
            }

            let normalizedQuery = snippetSearchQuery
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let matchesQuery: Bool
            if normalizedQuery.isEmpty {
                matchesQuery = true
            } else {
                let haystacks = [snippet.name, snippet.text, snippet.source?.displayName ?? ""] + snippet.tags
                matchesQuery = haystacks.contains { candidate in
                    candidate
                        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                        .contains(normalizedQuery)
                }
            }

            return matchesTag && matchesQuery
        }
    }

    private var hasActiveSnippetFilters: Bool {
        selectedSnippetTag != nil || !snippetSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var snippetEmptyStateMessage: String {
        let hasQuery = !snippetSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if let selectedSnippetTag, hasQuery {
            return L10n.usesEnglish
                ? "No snippets matched “\(snippetSearchQuery)” inside the \(selectedSnippetTag) tag."
                : "\"\(snippetSearchQuery)\" aramasıyla \(selectedSnippetTag) etiketinde eşleşen snippet bulunamadı."
        }

        if let selectedSnippetTag {
            return L10n.usesEnglish
                ? "No snippets matched the \(selectedSnippetTag) tag."
                : "\(selectedSnippetTag) etiketiyle eşleşen snippet bulunamadı."
        }

        if hasQuery {
            return L10n.usesEnglish
                ? "No snippets matched “\(snippetSearchQuery)”."
                : "\"\(snippetSearchQuery)\" aramasıyla eşleşen snippet bulunamadı."
        }

        return L10n.pair("Bir geçmiş kaydını veya son sonucu snippet olarak kaydettiğinde burada listelenecek.", "Saved snippets from a history entry or the latest result will appear here.")
    }

    private var orderedHistoryEntries: [ClipboardHistoryEntry] {
        ClipboardHistoryStore.orderedForDisplay(appState.copyHistory)
    }

    private func historyConfidenceTint(for indicator: ClipboardHistoryEntry.ConfidenceIndicator) -> Color {
        switch indicator {
        case .low:
            return .accentRose
        case .medium:
            return .accentAmber
        case .high:
            return .accentMint
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appState.launchAtLoginState.toggleIsOn },
            set: { setLaunchAtLogin($0) }
        )
    }

    private var savedRegionQuickStartBinding: Binding<Bool> {
        Binding(
            get: { appState.savedCaptureRegionQuickStartEnabled },
            set: { enabled in
                appState.setSavedCaptureRegionQuickStartEnabled(enabled)
                savedRegionFeedback = InlineFeedback(
                    message: enabled
                        ? L10n.pair("Ana yakalama düğmesi eşleşen kayıtlı bölgeyi otomatik kullanacak.", "The main capture button will use the matching saved region automatically.")
                        : L10n.pair("Ana yakalama düğmesi tekrar manuel alan seçimiyle çalışacak.", "The main capture button will switch back to manual region selection."),
                    tint: enabled ? .accentCool : .accentNeutral
                )
            }
        )
    }

    private var appProfilePanelAutoSyncBinding: Binding<Bool> {
        Binding(
            get: { appState.appProfilePanelAutoSyncEnabled },
            set: { enabled in
                let activeProfileName = appState.activeAppProfileSuggestion?.source.displayName
                appState.setAppProfilePanelAutoSyncEnabled(enabled)
                profileFeedback = InlineFeedback(
                    message: enabled
                        ? (activeProfileName.map {
                            L10n.usesEnglish
                                ? "\($0) profile will be applied to the panel automatically."
                                : "\($0) profili panelde otomatik uygulanacak."
                        }
                            ?? L10n.pair("Aktif uygulama değiştiğinde uygun profil panelde otomatik uygulanacak.", "The matching profile will be applied automatically when the active app changes."))
                        : L10n.pair("Panel artık yalnızca manuel eşitlemeyle veya elle değiştirdiğinde güncellenecek.", "The panel now updates only when you sync it manually or change it yourself."),
                    tint: enabled ? .accentCool : .accentNeutral
                )
            }
        )
    }

    private var savedSnippetCollectionAutoSyncBinding: Binding<Bool> {
        Binding(
            get: { appState.savedSnippetCollectionAutoSyncEnabled },
            set: { enabled in
                appState.setSavedSnippetCollectionAutoSyncEnabled(enabled)
                snippetFeedback = InlineFeedback(
                    message: enabled
                        ? L10n.pair("Geçmiş sekmesi aktif uygulamaya göre uygun snippet koleksiyonunu otomatik yükleyecek.", "The History tab will automatically load the matching snippet collection for the active app.")
                        : L10n.pair("Snippet koleksiyonları artık yalnızca manuel seçildiğinde uygulanacak.", "Snippet collections will now apply only when selected manually."),
                    tint: enabled ? .accentCool : .accentNeutral
                )
            }
        )
    }

    private var automaticDetectionBinding: Binding<Bool> {
        Binding(
            get: { appState.ocrLanguageSelection.automaticDetection },
            set: { enabled in
                appState.setOCRAutomaticDetection(enabled)
                ocrFeedback = InlineFeedback(
                    message: enabled
                        ? L10n.pair("OCR artık dili otomatik algılayacak.", "OCR will now detect the language automatically.")
                        : L10n.pair("OCR seçtiğin dillere öncelik verecek.", "OCR will prioritize the languages you selected."),
                    tint: .accentCool
                )
            }
        )
    }

    private var interfaceLanguageBinding: Binding<InterfaceLanguage> {
        Binding(
            get: { appState.interfaceLanguage },
            set: { language in
                appState.setInterfaceLanguage(language)
                languageFeedback = InlineFeedback(
                    message: language == .system
                        ? L10n.pair("Arayüz artık macOS dilini takip edecek.", "The interface will now follow your macOS language.")
                        : L10n.usesEnglish
                            ? "The interface switched to \(language.title)."
                            : "Arayüz \(language.title) olarak değiştirildi.",
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
            return L10n.pair("Hazır", "Ready")
        case .requiresRestart:
            return L10n.pair("Yeniden Aç", "Reopen")
        case .denied:
            return L10n.pair("Kapalı", "Off")
        case .unknown:
            return L10n.pair("Belirsiz", "Unknown")
        case .requestInProgress:
            return L10n.pair("Bekliyor", "Pending")
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
            return L10n.pair("Uygulama ekran yakalamaya hazır.", "The app is ready to capture the screen.")
        case .requiresRestart:
            return L10n.pair("Yetki verildi. Uygulamayı yeniden aç.", "Access was granted. Reopen the app.")
        case .denied:
            return L10n.pair("macOS izin vermedi veya henüz onaylanmadı.", "macOS did not grant permission yet or it has not been approved.")
        case .unknown:
            return L10n.pair("Durum doğrulanamadı, tekrar yenile.", "The status could not be verified. Refresh and try again.")
        case .requestInProgress:
            return L10n.pair("Sistem onayı bekleniyor.", "Waiting for system approval.")
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

    private func snippetFilterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.surfaceTop : Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? Color.accentMint.opacity(0.62) : Color.black.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func savedSnippetCollectionChip(_ collection: SavedSnippetCollection) -> some View {
        let isSelected = selectedSnippetCollectionID == collection.id

        return snippetFilterChip(title: collection.name, isSelected: isSelected) {
            applySnippetCollection(collection)
        }
        .contextMenu {
            Button("Koleksiyonu Uygula") {
                applySnippetCollection(collection)
            }

            Button("Koleksiyonu Sil", role: .destructive) {
                removeSavedSnippetCollection(collection)
            }
        }
        .help(collection.summary)
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
            VStack(alignment: .leading, spacing: 5) {
                Text(preset.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)

                Text(preset.summary)
                    .font(.system(size: 10.3, weight: .medium, design: .rounded))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
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
            return L10n.pair("Genel OCR", "General OCR")
        case .subtitle:
            return L10n.pair("Video ve canlı altyazı", "Video and live subtitles")
        case .code:
            return L10n.pair("Kod ve terminal", "Code and terminal")
        case .table:
            return L10n.pair("Tablo ve liste", "Tables and lists")
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
        let effectiveOutputPreset = appState.preferredRepasteOutputPreset(defaultingTo: entry.outputPreset)
        guard let result = appState.coordinator?.copyCapturedText(
            rawText: entry.effectiveRawText,
            captureMode: entry.captureMode,
            contentKind: entry.contentKind,
            source: entry.source,
            outputPreset: effectiveOutputPreset,
            targetBundleIdentifier: appState.activeTargetBundleIdentifier
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
                message: effectiveOutputPreset == entry.outputPreset
                    ? "Seçilen geçmiş metni yeniden panoya kopyalandı."
                    : "\(effectiveOutputPreset.title) olarak yeniden panoya kopyalandı.",
                tint: .accentCool
            )
        case .failedWrite, .failedReadback:
            historyFeedback = InlineFeedback(
                message: "Geçmiş metni panoya yazılamadı.",
                tint: .accentRose
            )
        }
    }

    private func saveLastCopiedSnippet() {
        guard let snippet = appState.saveLastCopiedEntryAsSnippet() else {
            snippetFeedback = InlineFeedback(
                message: "Önce bir sonuç üret, sonra snippet olarak kaydet.",
                tint: .accentWarm
            )
            return
        }

        snippetFeedback = InlineFeedback(
            message: "\(snippet.name) snippet listesine eklendi.",
            tint: .accentCool
        )
    }

    private func saveSnippet(from entry: ClipboardHistoryEntry) {
        let snippet = appState.saveHistoryEntryAsSnippet(entry)
        snippetFeedback = InlineFeedback(
            message: "\(snippet.name) snippet olarak kaydedildi.",
            tint: .accentCool
        )
    }

    private func copySavedSnippet(_ snippet: SavedSnippet) {
        guard let result = appState.coordinator?.copySavedSnippet(snippet) else {
            snippetFeedback = InlineFeedback(
                message: "Kopyalama servisi şu anda hazır değil.",
                tint: .accentRose
            )
            return
        }

        switch result {
        case .success:
            snippetFeedback = InlineFeedback(
                message: "\(snippet.name) panoya kopyalandı.",
                tint: .accentCool
            )
        case .failedWrite, .failedReadback:
            snippetFeedback = InlineFeedback(
                message: "Snippet panoya yazılamadı.",
                tint: .accentRose
            )
        }
    }

    private func toggleSnippetTag(_ tag: String, for snippet: SavedSnippet) {
        let updatedTags: [String]
        if snippet.tags.contains(where: {
            $0.compare(tag, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            updatedTags = snippet.tags.filter {
                $0.compare(tag, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame
            }
        } else {
            updatedTags = snippet.tags + [tag]
        }

        appState.updateSavedSnippetTags(updatedTags, for: snippet)
        snippetFeedback = InlineFeedback(
            message: updatedTags.contains(where: {
                $0.compare(tag, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            })
                ? "\(snippet.name) için \(tag) etiketi eklendi."
                : "\(snippet.name) için \(tag) etiketi kaldırıldı.",
            tint: .accentCool
        )

        if let selectedSnippetTag,
           !appState.availableSnippetTags.contains(where: {
               $0.compare(selectedSnippetTag, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
           }) {
            self.selectedSnippetTag = nil
        }

        syncSelectedSnippetCollection()
    }

    private func beginSnippetCollectionEditing() {
        isEditingSnippetCollection = true
        if let selectedSnippetTag {
            let query = snippetSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            snippetCollectionDraft = query.isEmpty ? selectedSnippetTag : "\(selectedSnippetTag) • \(query)"
        } else {
            let query = snippetSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            snippetCollectionDraft = query.isEmpty ? "Yeni koleksiyon" : query
        }
    }

    private func cancelSnippetCollectionEditing() {
        isEditingSnippetCollection = false
        snippetCollectionDraft = ""
    }

    private func commitSnippetCollectionDraft() {
        guard let collection = appState.saveSnippetCollection(
            named: snippetCollectionDraft,
            selectedTag: selectedSnippetTag,
            searchQuery: snippetSearchQuery
        ) else {
            snippetFeedback = InlineFeedback(
                message: "Kaydedilecek bir snippet filtresi seç.",
                tint: .accentWarm
            )
            return
        }

        selectedSnippetCollectionID = collection.id
        snippetFeedback = InlineFeedback(
            message: "\(collection.name) koleksiyonu kaydedildi.",
            tint: .accentMint
        )
        cancelSnippetCollectionEditing()
    }

    private func applySnippetCollection(_ collection: SavedSnippetCollection) {
        selectedSnippetTag = collection.selectedTag
        snippetSearchQuery = collection.searchQuery
        selectedSnippetCollectionID = collection.id
        isEditingSnippetCollection = false
        snippetCollectionDraft = ""
        snippetFeedback = InlineFeedback(
            message: "\(collection.name) koleksiyonu uygulandı.",
            tint: .accentCool
        )
    }

    private func beginSnippetTagEditing(for snippet: SavedSnippet) {
        editingSnippetTagSnippetID = snippet.id
        snippetTagDraft = ""
    }

    private func cancelSnippetTagEditing() {
        editingSnippetTagSnippetID = nil
        snippetTagDraft = ""
    }

    private func commitSnippetTagDraft(for snippet: SavedSnippet) {
        let trimmed = snippetTagDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        addSnippetTag(trimmed, to: snippet)
    }

    private func addSnippetTag(_ tag: String, to snippet: SavedSnippet) {
        var updatedTags = snippet.tags

        guard !updatedTags.contains(where: {
            $0.compare(tag, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else {
            snippetFeedback = InlineFeedback(
                message: "\(tag) etiketi zaten \(snippet.name) için mevcut.",
                tint: .accentNeutral
            )
            cancelSnippetTagEditing()
            return
        }

        updatedTags.append(tag)
        appState.updateSavedSnippetTags(updatedTags, for: snippet)
        snippetFeedback = InlineFeedback(
            message: "\(snippet.name) için #\(tag) etiketi eklendi.",
            tint: .accentAmber
        )
        cancelSnippetTagEditing()
        syncSelectedSnippetCollection()
    }

    private func removeSavedSnippet(_ snippet: SavedSnippet) {
        appState.removeSavedSnippet(snippet)
        if editingSnippetTagSnippetID == snippet.id {
            cancelSnippetTagEditing()
        }
        if let selectedSnippetTag,
           !appState.availableSnippetTags.contains(where: {
               $0.compare(selectedSnippetTag, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
           }) {
            self.selectedSnippetTag = nil
        }
        snippetFeedback = InlineFeedback(
            message: "\(snippet.name) kaldırıldı.",
            tint: .accentNeutral
        )
    }

    private func removeSavedSnippetCollection(_ collection: SavedSnippetCollection) {
        appState.removeSavedSnippetCollection(collection)
        if selectedSnippetCollectionID == collection.id {
            selectedSnippetCollectionID = nil
        }
        snippetFeedback = InlineFeedback(
            message: "\(collection.name) koleksiyonu kaldırıldı.",
            tint: .accentNeutral
        )
    }

    private func mergeSnippetTagCandidates(_ primary: [String], with secondary: [String]) -> [String] {
        var merged: [String] = []

        for tag in primary + secondary where !merged.contains(where: {
            $0.compare(tag, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            merged.append(tag)
        }

        return merged.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func syncSelectedSnippetCollection() {
        let normalizedTag = selectedSnippetTag?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveTag = (normalizedTag?.isEmpty == false) ? normalizedTag : nil
        let normalizedQuery = snippetSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        selectedSnippetCollectionID = appState.savedSnippetCollections.first(where: { collection in
            collection.searchQuery.compare(normalizedQuery, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame &&
            equalSnippetFilterTag(collection.selectedTag, effectiveTag)
        })?.id
    }

    private func applyPendingSnippetCollectionSelectionIfNeeded() {
        guard let collection = appState.consumePendingSnippetCollectionSelection() else {
            return
        }

        selectedTab = .history
        selectedSnippetTag = collection.selectedTag
        snippetSearchQuery = collection.searchQuery
        selectedSnippetCollectionID = collection.id
        isEditingSnippetCollection = false
        snippetCollectionDraft = ""
        snippetFeedback = InlineFeedback(
            message: L10n.usesEnglish ? "\(collection.name) collection was opened." : "\(collection.name) koleksiyonu açıldı.",
            tint: .accentCool
        )
    }

    private func applyActiveSavedSnippetCollectionSuggestionIfNeeded(forceFeedback: Bool) {
        guard selectedTab == .history else {
            return
        }

        let previousSelectionID = selectedSnippetCollectionID
        guard let collection = appState.preferredActiveSavedSnippetCollectionSelection(
            currentSelectionID: previousSelectionID
        ) else {
            return
        }

        applySnippetCollection(collection)

        if forceFeedback || previousSelectionID != collection.id {
            let sourceName = appState.activeSavedSnippetCollectionSuggestion?.source.displayName ?? "Aktif uygulama"
            snippetFeedback = InlineFeedback(
                message: "\(sourceName) için \(collection.name) koleksiyonu otomatik yüklendi.",
                tint: .accentCool
            )
        }
    }

    private func equalSnippetFilterTag(_ lhs: String?, _ rhs: String?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (left?, right?):
            return left.compare(right, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        default:
            return false
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

    private func togglePinnedHistoryEntry(_ entry: ClipboardHistoryEntry) {
        appState.togglePinnedHistoryEntry(entry)
        historyFeedback = InlineFeedback(
            message: entry.isPinned
                ? "Kayıt sabitlerden çıkarıldı."
                : "Kayıt sabitlendi ve üstte tutulacak.",
            tint: .accentAmber
        )
    }

    private func clearHistory() {
        appState.clearHistory()
        historyFeedback = InlineFeedback(
            message: "Tüm geçmiş temizlendi.",
            tint: .accentNeutral
        )
    }

    private func saveLastCaptureRegion() {
        guard let region = appState.saveLastCaptureSelection() else {
            savedRegionFeedback = InlineFeedback(
                message: "Önce bir alan yakala, sonra kaydet.",
                tint: .accentWarm
            )
            return
        }

        savedRegionFeedback = InlineFeedback(
            message: L10n.usesEnglish ? "\(region.name) was added to saved regions." : "\(region.name) kayıtlı bölgelere eklendi.",
            tint: .accentCool
        )
    }

    private func repeatLastCapture() {
        guard appState.lastCaptureSelection != nil else {
            savedRegionFeedback = InlineFeedback(
                message: "Önce bir alan yakala, sonra tekrar kullan.",
                tint: .accentWarm
            )
            return
        }

        appState.coordinator?.repeatLastCapture(sessionOverrides: nil)
        savedRegionFeedback = InlineFeedback(
            message: L10n.pair("Son alan tekrar çalıştırılıyor.", "The last region is being captured again."),
            tint: .accentCool
        )
    }

    private func captureSavedRegion(_ region: SavedCaptureRegion) {
        appState.coordinator?.captureSavedRegion(region, sessionOverrides: nil)
        savedRegionFeedback = InlineFeedback(
            message: L10n.usesEnglish ? "Capturing \(region.name)." : "\(region.name) yakalanıyor.",
            tint: .accentCool
        )
    }

    private func refreshSavedCaptureRegion(_ region: SavedCaptureRegion) {
        guard let updated = appState.refreshSavedCaptureRegion(region) else {
            savedRegionFeedback = InlineFeedback(
                message: "Güncellemek için önce yeni bir alan yakala.",
                tint: .accentWarm
            )
            return
        }

        savedRegionFeedback = InlineFeedback(
            message: "\(updated.name) son seçimle güncellendi.",
            tint: .accentCool
        )
    }

    private func removeSavedCaptureRegion(_ region: SavedCaptureRegion) {
        appState.removeSavedCaptureRegion(region)
        savedRegionFeedback = InlineFeedback(
            message: "\(region.name) kaldırıldı.",
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
                message: L10n.pair("Tanı verisi güncellendi.", "Diagnostic data was refreshed."),
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
