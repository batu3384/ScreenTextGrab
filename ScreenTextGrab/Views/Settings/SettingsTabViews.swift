import SwiftUI

struct SettingsGeneralTabView: View {
    let interfaceLanguageBinding: Binding<InterfaceLanguage>
    let interfaceLanguageDetail: String
    let languageFeedback: InlineFeedback?
    let captureModeDetail: String
    let captureModeFeedback: InlineFeedback?
    let outputPresetDetail: String
    let outputPresetFeedback: InlineFeedback?
    let isRecordingHotkey: Bool
    let hotkeyDisplayLabel: String
    let hotkeyFeedback: HotkeyFeedback?
    let launchAtLoginTitle: String
    let launchAtLoginDetail: String
    let launchAtLoginTint: Color
    let launchAtLoginBinding: Binding<Bool>
    let launchAtLoginRequiresApproval: Bool
    let launchAtLoginFeedback: InlineFeedback?
    let watchSummary: String
    let watchRegexDraft: Binding<String>
    let watchFeedback: InlineFeedback?
    let permissionSubtitle: String
    let permissionTitle: String
    let permissionTint: Color
    let permissionDescription: String
    let showRequestPermissionAction: Bool
    let appProfileSummary: String
    let appProfilePanelAutoSyncBinding: Binding<Bool>
    let profileFeedback: InlineFeedback?
    let emptyProfileMessage: String
    let captureModes: [CaptureMode]
    let outputPresets: [CaptureOutputPreset]
    let watchBehaviors: [WatchCopyBehavior]
    let profileTargets: [SettingsView.ProfileTarget]
    let appProfiles: [AppCaptureProfile]
    let renderCaptureModeButton: (CaptureMode) -> AnyView
    let renderOutputPresetButton: (CaptureOutputPreset) -> AnyView
    let renderWatchBehaviorButton: (WatchCopyBehavior) -> AnyView
    let renderProfileRow: (AppCaptureProfile) -> AnyView
    let renderLanguageFeedback: (InlineFeedback) -> AnyView
    let renderCaptureModeFeedback: (InlineFeedback) -> AnyView
    let renderOutputPresetFeedback: (InlineFeedback) -> AnyView
    let renderHotkeyFeedback: (HotkeyFeedback) -> AnyView
    let renderLaunchAtLoginFeedback: (InlineFeedback) -> AnyView
    let renderWatchFeedback: (InlineFeedback) -> AnyView
    let renderProfileFeedback: (InlineFeedback) -> AnyView
    let toggleHotkeyRecording: () -> Void
    let resetHotkey: () -> Void
    let openLoginItemsSettings: () -> Void
    let refreshLaunchAtLoginState: () -> Void
    let saveWatchRegex: () -> Void
    let clearWatchRegex: () -> Void
    let requestPermission: () -> Void
    let openSystemSettings: () -> Void
    let refreshPermission: () -> Void
    let openDiagnostics: () -> Void
    let saveProfile: (SettingsView.ProfileTarget) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                SettingsSectionCard(
                    title: L10n.pair("Arayüz Dili", "Interface Language"),
                    subtitle: interfaceLanguageDetail
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
                        renderLanguageFeedback(languageFeedback)
                    }
                }

                SettingsSectionCard(
                    title: L10n.pair("Yakalama Modu", "Capture Mode"),
                    subtitle: L10n.pair("Metin, altyazı, kod veya tablo odaklı yakalama arasında geçiş yap.", "Switch between text, subtitle, code, or table-focused capture.")
                ) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 148), spacing: 10)],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(captureModes) { mode in
                            renderCaptureModeButton(mode)
                        }
                    }

                    Text(captureModeDetail)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    if let captureModeFeedback {
                        renderCaptureModeFeedback(captureModeFeedback)
                    }
                }

                SettingsSectionCard(
                    title: L10n.pair("Çıktı Biçimi", "Output Format"),
                    subtitle: outputPresetDetail
                ) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 152), spacing: 12)],
                        alignment: .leading,
                        spacing: 12
                    ) {
                        ForEach(outputPresets) { preset in
                            renderOutputPresetButton(preset)
                        }
                    }

                    if let outputPresetFeedback {
                        renderOutputPresetFeedback(outputPresetFeedback)
                    }
                }

                SettingsSectionCard(
                    title: L10n.pair("Global Kısayol", "Global Shortcut"),
                    subtitle: isRecordingHotkey
                        ? L10n.pair("Yeni kombinasyonu gir. Esc ile iptal edebilirsin.", "Enter the new combination. Press Esc to cancel.")
                        : L10n.pair("Yakalamayı her yerden başlatmak için kullanılır.", "Use it to start capture from anywhere.")
                ) {
                    HStack(spacing: 10) {
                        Button(action: toggleHotkeyRecording) {
                            Text(isRecordingHotkey ? L10n.pair("Tuşa Bas...", "Press Keys...") : hotkeyDisplayLabel)
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

                        SettingsActionButton(
                            title: isRecordingHotkey ? L10n.actionCancel : L10n.actionChange,
                            icon: isRecordingHotkey ? "xmark" : "keyboard",
                            tint: isRecordingHotkey ? .accentRose : .accentCool,
                            action: toggleHotkeyRecording
                        )

                        SettingsActionButton(
                            title: L10n.actionDefault,
                            icon: "arrow.counterclockwise",
                            tint: .accentNeutral,
                            action: resetHotkey
                        )
                    }

                    if let hotkeyFeedback {
                        renderHotkeyFeedback(hotkeyFeedback)
                    }
                }

                SettingsSectionCard(
                    title: L10n.pair("Açılışta Başlat", "Launch at Login"),
                    subtitle: launchAtLoginDetail
                ) {
                    HStack(spacing: 12) {
                        SettingsStatusPill(text: launchAtLoginTitle, tint: launchAtLoginTint)
                        Spacer()
                        Toggle("", isOn: launchAtLoginBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityLabel(L10n.accessibilityLaunchAtLoginToggle)
                    }

                    HStack(spacing: 10) {
                        if launchAtLoginRequiresApproval {
                            SettingsActionButton(
                                title: L10n.actionLoginItems,
                                icon: "person.crop.circle.badge.gearshape",
                                tint: .accentWarm,
                                action: openLoginItemsSettings
                            )
                        }

                        SettingsActionButton(
                            title: L10n.actionRefresh,
                            icon: "arrow.clockwise",
                            tint: .accentNeutral,
                            action: refreshLaunchAtLoginState
                        )
                    }

                    if let launchAtLoginFeedback {
                        renderLaunchAtLoginFeedback(launchAtLoginFeedback)
                    }
                }

                SettingsSectionCard(
                    title: L10n.pair("İzleme Kuralları", "Watch Rules"),
                    subtitle: watchSummary
                ) {
                    HStack(spacing: 10) {
                        ForEach(watchBehaviors) { behavior in
                            renderWatchBehaviorButton(behavior)
                        }
                    }

                    TextField(L10n.pair("İsteğe bağlı regex filtresi", "Optional regex filter"), text: watchRegexDraft)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 10) {
                        SettingsActionButton(
                            title: L10n.pair("Regex'i Kaydet", "Save Regex"),
                            icon: "checkmark.circle",
                            tint: .accentCool,
                            action: saveWatchRegex
                        )

                        SettingsActionButton(
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
                        renderWatchFeedback(watchFeedback)
                    }
                }

                SettingsSectionCard(
                    title: L10n.pair("Ekran Kaydı İzni", "Screen Recording Permission"),
                    subtitle: permissionSubtitle
                ) {
                    HStack(spacing: 12) {
                        SettingsStatusPill(text: permissionTitle, tint: permissionTint)
                        Spacer()
                        Text(permissionDescription)
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack(spacing: 10) {
                        if showRequestPermissionAction {
                            SettingsActionButton(
                                title: L10n.actionRequestPermission,
                                icon: "lock.open.display",
                                tint: .accentWarm,
                                action: requestPermission
                            )
                        }

                        SettingsActionButton(
                            title: L10n.actionSystemSettings,
                            icon: "gearshape.2",
                            tint: .accentNeutral,
                            action: openSystemSettings
                        )

                        SettingsActionButton(
                            title: L10n.actionRefresh,
                            icon: "arrow.clockwise",
                            tint: .accentCool,
                            action: refreshPermission
                        )

                        SettingsActionButton(
                            title: L10n.actionDiagnostics,
                            icon: "stethoscope",
                            tint: .accentNeutral,
                            action: openDiagnostics
                        )
                    }
                }

                SettingsSectionCard(
                    title: L10n.pair("Uygulama Profilleri", "App Profiles"),
                    subtitle: appProfileSummary
                ) {
                    Menu {
                        ForEach(profileTargets) { target in
                            Button {
                                saveProfile(target)
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
                        renderProfileFeedback(profileFeedback)
                    }

                    if appProfiles.isEmpty {
                        Text(emptyProfileMessage)
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(appProfiles) { profile in
                                renderProfileRow(profile)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }
}

struct SettingsOCRTabView: View {
    let automaticDetectionBinding: Binding<Bool>
    let ocrSelectionSummary: String
    let automaticDetectionEnabled: Bool
    let supportedLanguages: [OCRLanguagePreference]
    let ocrFeedback: InlineFeedback?
    let renderLanguageToggle: (OCRLanguagePreference) -> AnyView
    let renderFeedback: (InlineFeedback) -> AnyView

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                SettingsSectionCard(
                    title: L10n.pair("Tanıma Modu", "Recognition Mode"),
                    subtitle: L10n.pair("Otomatik algılamayı açabilir veya tercih ettiğin dilleri sabitleyebilirsin.", "Turn on automatic detection or pin the languages you prefer.")
                ) {
                    Toggle(L10n.ocrAutomaticLanguage, isOn: automaticDetectionBinding)
                        .toggleStyle(.switch)
                        .accessibilityLabel(L10n.accessibilityAutomaticLanguage)

                    Text(automaticDetectionEnabled
                         ? L10n.pair("Vision dilini otomatik seçer. Çok dilli kullanım için uygundur.", "Vision chooses the language automatically. This is ideal for multilingual use.")
                         : L10n.pair("Aşağıdaki diller öncelikli olarak kullanılacak.", "The languages below will be prioritized."))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    if let ocrFeedback {
                        renderFeedback(ocrFeedback)
                    }
                }

                SettingsSectionCard(
                    title: L10n.pair("Desteklenen Diller", "Supported Languages"),
                    subtitle: ocrSelectionSummary
                ) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 94), spacing: 10)],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(supportedLanguages) { language in
                            renderLanguageToggle(language)
                        }
                    }
                    .opacity(automaticDetectionEnabled ? 0.56 : 1)
                    .disabled(automaticDetectionEnabled)
                }
            }
            .padding(.bottom, 8)
        }
    }
}

struct SettingsHistoryTabView: View {
    let savedRegionsSummary: String
    let savedRegionQuickStartBinding: Binding<Bool>
    let savedRegionFeedback: InlineFeedback?
    let savedRegions: [SavedCaptureRegion]
    let lastCaptureSelectionAvailable: Bool
    let snippetsSummary: String
    let savedSnippetCollectionAutoSyncBinding: Binding<Bool>
    let snippetSearchQuery: Binding<String>
    let selectedSnippetTag: String?
    let availableSnippetTags: [String]
    let savedSnippetCollections: [SavedSnippetCollection]
    let snippetFeedback: InlineFeedback?
    let filteredSavedSnippets: [SavedSnippet]
    let latestResultAvailable: Bool
    let isEditingSnippetCollection: Bool
    let snippetCollectionDraft: Binding<String>
    let hasActiveSnippetFilters: Bool
    let snippetEmptyStateMessage: String
    let historySummary: String
    let historySearchQuery: Binding<String>
    let showPinnedOnlyHistory: Binding<Bool>
    let filteredHistoryEntries: [ClipboardHistoryEntry]
    let orderedHistoryEntries: [ClipboardHistoryEntry]
    let pinnedHistoryCount: Int
    let historyFeedback: InlineFeedback?
    let copyHistory: [ClipboardHistoryEntry]
    let historyExportFormats: [ClipboardHistoryExportFormat]
    let renderSavedRegionRow: (SavedCaptureRegion) -> AnyView
    let renderSavedSnippetCollectionChip: (SavedSnippetCollection) -> AnyView
    let renderSnippetFilterChip: (String, Bool, @escaping () -> Void) -> AnyView
    let renderSavedSnippetRow: (SavedSnippet) -> AnyView
    let renderHistoryExportFormatButton: (ClipboardHistoryExportFormat) -> AnyView
    let renderHistoryRow: (ClipboardHistoryEntry) -> AnyView
    let renderSavedRegionFeedback: (InlineFeedback) -> AnyView
    let renderSnippetFeedback: (InlineFeedback) -> AnyView
    let renderHistoryFeedback: (InlineFeedback) -> AnyView
    let historyEmptyState: AnyView
    let historySearchEmptyState: AnyView
    let saveLastCaptureRegion: () -> Void
    let repeatLastCapture: () -> Void
    let saveLastCopiedSnippet: () -> Void
    let beginSnippetCollectionEditing: () -> Void
    let commitSnippetCollectionDraft: () -> Void
    let cancelSnippetCollectionEditing: () -> Void
    let selectAllSnippetTags: () -> Void
    let toggleSnippetTagSelection: (String) -> Void
    let clearHistory: () -> Void
    let exportHistory: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                SettingsSectionCard(
                    title: L10n.pair("Kayıtlı Bölgeler", "Saved Regions"),
                    subtitle: savedRegionsSummary
                ) {
                    HStack(spacing: 10) {
                        SettingsActionButton(
                            title: L10n.pair("Son Alanı Kaydet", "Save Last Region"),
                            icon: "rectangle.badge.plus",
                            tint: .accentMint,
                            action: saveLastCaptureRegion
                        )
                        .disabled(!lastCaptureSelectionAvailable)
                        .opacity(lastCaptureSelectionAvailable ? 1 : 0.55)

                        SettingsActionButton(
                            title: L10n.pair("Son Alanı Tekrar Yakala", "Repeat Last Region"),
                            icon: "arrow.clockwise",
                            tint: .accentCool,
                            action: repeatLastCapture
                        )
                        .disabled(!lastCaptureSelectionAvailable)
                        .opacity(lastCaptureSelectionAvailable ? 1 : 0.55)
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
                        renderSavedRegionFeedback(savedRegionFeedback)
                    }

                    if savedRegions.isEmpty {
                        Text(L10n.pair("Bir alan yakaladıktan sonra burada kalıcı bölge olarak saklayabilirsin.", "After capturing a region, you can keep it here as a permanent saved region."))
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(savedRegions) { region in
                                renderSavedRegionRow(region)
                            }
                        }
                    }
                }

                SettingsSectionCard(
                    title: L10n.pair("Kayıtlı Snippet'lar", "Saved Snippets"),
                    subtitle: snippetsSummary
                ) {
                    HStack(spacing: 10) {
                        SettingsActionButton(
                            title: L10n.pair("Son Sonucu Kaydet", "Save Latest Result"),
                            icon: "bookmark.badge.plus",
                            tint: .accentMint,
                            action: saveLastCopiedSnippet
                        )
                        .disabled(!latestResultAvailable)
                        .opacity(latestResultAvailable ? 1 : 0.55)
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

                    TextField(L10n.pair("Snippet ara", "Search snippets"), text: snippetSearchQuery)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 10) {
                        SettingsActionButton(
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
                            TextField(L10n.pair("Koleksiyon adı", "Collection name"), text: snippetCollectionDraft)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    commitSnippetCollectionDraft()
                                }

                            SettingsActionButton(
                                title: L10n.pair("Kaydet", "Save"),
                                icon: "checkmark",
                                tint: .accentMint,
                                action: commitSnippetCollectionDraft
                            )
                            .disabled(snippetCollectionDraft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasActiveSnippetFilters)
                            .opacity(
                                snippetCollectionDraft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasActiveSnippetFilters
                                    ? 0.55
                                    : 1
                            )

                            SettingsActionButton(
                                title: L10n.pair("Vazgec", "Cancel"),
                                icon: "xmark",
                                tint: .accentNeutral,
                                action: cancelSnippetCollectionEditing
                            )
                        }
                    }

                    if !savedSnippetCollections.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(savedSnippetCollections) { collection in
                                    renderSavedSnippetCollectionChip(collection)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    if !availableSnippetTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                renderSnippetFilterChip(L10n.pair("Tümü", "All"), selectedSnippetTag == nil, selectAllSnippetTags)

                                ForEach(availableSnippetTags, id: \.self) { tag in
                                    renderSnippetFilterChip(tag, selectedSnippetTag == tag) {
                                        toggleSnippetTagSelection(tag)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    if let snippetFeedback {
                        renderSnippetFeedback(snippetFeedback)
                    }

                    if filteredSavedSnippets.isEmpty {
                        Text(snippetEmptyStateMessage)
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(filteredSavedSnippets) { snippet in
                                renderSavedSnippetRow(snippet)
                            }
                        }
                    }
                }

                SettingsSectionCard(
                    title: L10n.pair("Yakalama Geçmişi", "Capture History"),
                    subtitle: historySummary
                ) {
                    TextField(L10n.pair("Geçmişte ara", "Search history"), text: historySearchQuery)
                        .textFieldStyle(.roundedBorder)

                    Toggle(L10n.pair("Yalnızca Sabitler", "Pinned Only"), isOn: showPinnedOnlyHistory)
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
                            ForEach(historyExportFormats) { format in
                                renderHistoryExportFormatButton(format)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        SettingsActionButton(
                            title: L10n.actionExport,
                            icon: "square.and.arrow.up",
                            tint: .accentCool,
                            action: exportHistory
                        )
                        .disabled(filteredHistoryEntries.isEmpty)
                        .opacity(filteredHistoryEntries.isEmpty ? 0.55 : 1)

                        SettingsActionButton(
                            title: L10n.actionClear,
                            icon: "trash",
                            tint: .accentRose,
                            action: clearHistory
                        )
                        .disabled(copyHistory.isEmpty)
                        .opacity(copyHistory.isEmpty ? 0.55 : 1)
                    }

                    if let historyFeedback {
                        renderHistoryFeedback(historyFeedback)
                    }

                    if copyHistory.isEmpty {
                        historyEmptyState
                    } else if filteredHistoryEntries.isEmpty {
                        historySearchEmptyState
                    } else {
                        VStack(spacing: 10) {
                            ForEach(filteredHistoryEntries) { entry in
                                renderHistoryRow(entry)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }
}

struct SettingsDiagnosticsTabView: View {
    let permissionDiagnostics: PermissionDiagnosticSnapshot?
    let permissionStateMessage: String
    let diagnosticsFeedback: InlineFeedback?
    let diagnosticsEntries: [DiagnosticEntry]
    let renderDiagnosticValueRow: (String, String) -> AnyView
    let renderDiagnosticEntryRow: (DiagnosticEntry) -> AnyView
    let renderDiagnosticsFeedback: (InlineFeedback) -> AnyView
    let refreshPermissionDiagnostics: () -> Void
    let copyPermissionDiagnostics: () -> Void
    let exportSupportBundle: () -> Void
    let openSystemSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                SettingsSectionCard(
                    title: L10n.pair("İzin Tanısı", "Permission Diagnostics"),
                    subtitle: permissionDiagnostics?.currentState.uiMessage ?? permissionStateMessage
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let permissionDiagnostics {
                            renderDiagnosticValueRow(L10n.pair("Durum", "Status"), permissionDiagnostics.currentState.uiMessage)
                            renderDiagnosticValueRow("Preflight", permissionDiagnostics.preflightLabel)
                            renderDiagnosticValueRow("Probe", permissionDiagnostics.probeState.uiMessage)
                            renderDiagnosticValueRow(
                                L10n.pair("Yeniden Açma", "Reopen"),
                                permissionDiagnostics.needsRestartAfterGrant
                                    ? L10n.pair("Gerekli", "Required")
                                    : L10n.pair("Gerekmiyor", "Not Needed")
                            )
                            renderDiagnosticValueRow("Bundle ID", permissionDiagnostics.bundleIdentifier)
                            renderDiagnosticValueRow(L10n.pair("Sürüm", "Version"), permissionDiagnostics.versionLabel)
                            renderDiagnosticValueRow(L10n.pair("Uygulama", "App"), permissionDiagnostics.appPath)

                            if let lastProbeAt = permissionDiagnostics.lastProbeAt {
                                renderDiagnosticValueRow(
                                    L10n.pair("Son Probe", "Last Probe"),
                                    lastProbeAt.formatted(.dateTime.day().month(.abbreviated).hour().minute().second())
                                )
                            }

                            if let lastConfirmedGrantAt = permissionDiagnostics.lastConfirmedGrantAt {
                                renderDiagnosticValueRow(
                                    L10n.pair("Son Grant Kanıtı", "Last Grant Evidence"),
                                    lastConfirmedGrantAt.formatted(.dateTime.day().month(.abbreviated).hour().minute().second())
                                )
                            }
                        } else {
                            Text(L10n.pair("Henüz tanı verisi yüklenmedi. Yenile ile tekrar dene.", "No diagnostics have been loaded yet. Try Refresh again."))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 10) {
                            SettingsActionButton(
                                title: L10n.actionRefresh,
                                icon: "arrow.clockwise",
                                tint: .accentCool,
                                action: refreshPermissionDiagnostics
                            )

                            SettingsActionButton(
                                title: L10n.actionCopyDiagnostics,
                                icon: "doc.on.doc",
                                tint: .accentNeutral,
                                action: copyPermissionDiagnostics
                            )
                        }

                        HStack(spacing: 10) {
                            SettingsActionButton(
                                title: L10n.actionSupportBundle,
                                icon: "square.and.arrow.up",
                                tint: .accentWarm,
                                action: exportSupportBundle
                            )

                            SettingsActionButton(
                                title: L10n.actionSystemSettings,
                                icon: "gearshape.2",
                                tint: .accentNeutral,
                                action: openSystemSettings
                            )
                        }

                        if let diagnosticsFeedback {
                            renderDiagnosticsFeedback(diagnosticsFeedback)
                        }
                    }
                }

                SettingsSectionCard(
                    title: L10n.pair("Uygulama Tanı Kayıtları", "App Diagnostic Logs"),
                    subtitle: diagnosticsEntries.isEmpty
                        ? L10n.pair("Henüz kayıt yok.", "No logs yet.")
                        : L10n.usesEnglish
                            ? "\(diagnosticsEntries.count) entries showing the latest warnings and errors."
                            : "\(diagnosticsEntries.count) kayıt son hata ve uyarıları gösteriyor."
                ) {
                    if diagnosticsEntries.isEmpty {
                        Text(L10n.pair("İzin, OCR, clipboard ve launch akışından gelen kayıtlar burada listelenecek.", "Entries from permission, OCR, clipboard, and launch flows will appear here."))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(diagnosticsEntries.reversed()) { entry in
                                renderDiagnosticEntryRow(entry)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }
}
