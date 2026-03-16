import ApplicationServices
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

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

final class AppState: ObservableObject {
    @Published var lastCopiedText: String
    @Published var copyHistory: [ClipboardHistoryEntry]
    @Published var permissionState: ScreenPermissionState
    @Published var captureState: CaptureState
    @Published var statusMessage: String
    @Published var lastError: CapturePipelineError?
    @Published var diagnostics: [DiagnosticEntry]
    @Published var isHotkeyAvailable: Bool
    @Published var hotkeyDisplayLabel: String
    @Published var launchAtLoginState: LaunchAtLoginState
    @Published var captureMode: CaptureMode
    @Published var watchState: WatchState
    @Published var speechState: SpeechPlaybackState
    @Published var ocrLanguageSelection: OCRLanguageSelection
    @Published var captureOutputPreset: CaptureOutputPreset
    @Published var interfaceLanguage: InterfaceLanguage
    @Published var watchConfiguration: WatchConfiguration
    @Published var appProfiles: [AppCaptureProfile]
    @Published var appProfilePanelAutoSyncEnabled: Bool
    @Published var savedCaptureRegions: [SavedCaptureRegion]
    @Published var savedCaptureRegionQuickStartEnabled: Bool
    @Published var savedSnippets: [SavedSnippet]
    @Published var savedSnippetCollections: [SavedSnippetCollection]
    @Published var savedSnippetCollectionAutoSyncEnabled: Bool
    @Published var historyExportFormat: ClipboardHistoryExportFormat
    @Published var updateState: AppUpdateState
    @Published var settingsPresentationToken: UUID?
    @Published var pendingSnippetCollectionSelectionName: String?
    @Published var activeTableReview: TableReviewSession?
    @Published var activeSourceApp: ClipboardHistoryEntry.SourceContext?
    private(set) var lastCaptureSelection: RecentCaptureSelection?

    weak var coordinator: CaptureCoordinating?
    weak var hotkeyManager: HotkeyManaging?
    weak var launchAtLoginManager: LaunchAtLoginManaging?
    weak var speechManager: SpeechManaging?
    weak var updateManager: AppUpdateManaging?
    weak var permissionDiagnosticsProvider: ScreenPermissionProviding?

    private let defaults: UserDefaults
    private let persistsUserPreferences: Bool

    init(
        defaults: UserDefaults = .standard,
        persistsUserPreferences: Bool = AppState.shouldPersistUserPreferences
    ) {
        self.defaults = defaults
        self.persistsUserPreferences = persistsUserPreferences

        let restoredHistory = persistsUserPreferences ? ClipboardHistoryStore.load(defaults: defaults) : []

        self.lastCopiedText = restoredHistory.first?.text ?? ""
        self.copyHistory = restoredHistory
        self.permissionState = .unknown
        self.captureState = .idle
        self.statusMessage = L10n.pair("✅ Hazır — menüden yakala", "✅ Ready — capture from the menu")
        self.lastError = nil
        self.diagnostics = []
        self.isHotkeyAvailable = false
        self.hotkeyDisplayLabel = HotkeyConfiguration.defaultValue.displayLabel
        self.launchAtLoginState = .disabled
        self.captureMode = persistsUserPreferences
            ? CaptureModeStore.load(defaults: defaults)
            : .standard
        self.watchState = .inactive
        self.speechState = .idle
        self.ocrLanguageSelection = persistsUserPreferences
            ? OCRLanguageSelectionStore.load(defaults: defaults)
            : .defaultValue
        self.captureOutputPreset = persistsUserPreferences
            ? CaptureOutputPresetStore.load(defaults: defaults)
            : .smart
        self.interfaceLanguage = persistsUserPreferences
            ? InterfaceLanguageStore.load(defaults: defaults)
            : .system
        self.watchConfiguration = persistsUserPreferences
            ? WatchConfigurationStore.load(defaults: defaults)
            : .defaultValue
        self.appProfiles = persistsUserPreferences
            ? AppCaptureProfileStore.load(defaults: defaults)
            : []
        self.appProfilePanelAutoSyncEnabled = persistsUserPreferences
            ? AppProfilePanelAutoSyncStore.load(defaults: defaults)
            : false
        self.savedCaptureRegions = persistsUserPreferences
            ? SavedCaptureRegionStore.load(defaults: defaults)
            : []
        self.savedCaptureRegionQuickStartEnabled = persistsUserPreferences
            ? SavedCaptureRegionQuickStartStore.load(defaults: defaults)
            : true
        self.savedSnippets = persistsUserPreferences
            ? AppState.migratedSavedSnippets(SavedSnippetStore.load(defaults: defaults))
            : []
        self.savedSnippetCollections = persistsUserPreferences
            ? SavedSnippetCollectionStore.load(defaults: defaults)
            : []
        self.savedSnippetCollectionAutoSyncEnabled = persistsUserPreferences
            ? SavedSnippetCollectionAutoSyncStore.load(defaults: defaults)
            : true
        self.historyExportFormat = persistsUserPreferences
            ? ClipboardHistoryExportFormatStore.load(defaults: defaults)
            : .markdown
        self.updateState = .idle
        self.settingsPresentationToken = nil
        self.pendingSnippetCollectionSelectionName = nil
        self.activeTableReview = nil
        self.activeSourceApp = nil
        self.lastCaptureSelection = nil
    }

    var lastCopiedEntry: ClipboardHistoryEntry? {
        copyHistory.first
    }

    var pinnedHistoryCount: Int {
        copyHistory.filter { $0.isPinned }.count
    }

    var readyStatusMessage: String {
        isHotkeyAvailable
            ? L10n.format("✅ Hazır — %@ ile yakala", "✅ Ready — capture with %@", hotkeyDisplayLabel)
            : L10n.pair("✅ Hazır — menüden yakala", "✅ Ready — capture from the menu")
    }

    var availableSnippetTags: [String] {
        var seen = Set<String>()
        let tags = savedSnippets
            .flatMap(\.tags)
            .filter { tag in
                let key = tag.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                if seen.contains(key) {
                    return false
                }

                seen.insert(key)
                return true
            }

        return tags.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    @discardableResult
    func saveSnippetCollection(named name: String, selectedTag: String?, searchQuery: String) -> SavedSnippetCollection? {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTag = selectedTag?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveTag = (normalizedTag?.isEmpty == false) ? normalizedTag : nil
        let normalizedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedName.isEmpty,
              effectiveTag != nil || !normalizedQuery.isEmpty else {
            return nil
        }

        let updatedAt = Date()

        if let index = savedSnippetCollections.firstIndex(where: {
            $0.name.compare(normalizedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            let existing = savedSnippetCollections[index]
            savedSnippetCollections[index] = SavedSnippetCollection(
                id: existing.id,
                name: normalizedName,
                selectedTag: effectiveTag,
                searchQuery: normalizedQuery,
                updatedAt: updatedAt
            )
            sortSavedSnippetCollections()
            persistSavedSnippetCollectionsIfNeeded()
            return savedSnippetCollections.first(where: { $0.id == existing.id }) ?? savedSnippetCollections[index]
        }

        let collection = SavedSnippetCollection(
            name: normalizedName,
            selectedTag: effectiveTag,
            searchQuery: normalizedQuery,
            updatedAt: updatedAt
        )
        savedSnippetCollections.insert(collection, at: 0)
        if savedSnippetCollections.count > SavedSnippetCollectionStore.maximumEntries {
            savedSnippetCollections.removeLast(savedSnippetCollections.count - SavedSnippetCollectionStore.maximumEntries)
        }
        sortSavedSnippetCollections()
        persistSavedSnippetCollectionsIfNeeded()
        return savedSnippetCollections.first(where: { $0.id == collection.id }) ?? collection
    }

    func removeSavedSnippetCollection(_ collection: SavedSnippetCollection) {
        savedSnippetCollections.removeAll { $0.id == collection.id }
        persistSavedSnippetCollectionsIfNeeded()
    }

    func appendDiagnostic(category: String, message: String, domain: String?, code: Int?, severity: DiagnosticSeverity = .error) {
        diagnostics.append(
            DiagnosticEntry(
                timestamp: Date(),
                category: category,
                message: message,
                domain: domain,
                code: code,
                severity: severity
            )
        )

        if diagnostics.count > 10 {
            diagnostics.removeFirst(diagnostics.count - 10)
        }
    }

    func updateHotkeyAvailability(isAvailable: Bool, label: String) {
        isHotkeyAvailable = isAvailable
        hotkeyDisplayLabel = label

        if permissionState == .granted,
           captureState == .idle || captureState == .completed || captureState == .cancelled {
            statusMessage = readyStatusMessage
        }
    }

    func recordCopiedText(
        _ text: String,
        at date: Date = Date(),
        captureMode: CaptureMode = .standard,
        outputPreset: CaptureOutputPreset = .smart,
        contentKind: ClipboardHistoryEntry.ContentKind = .text,
        rawText: String? = nil,
        ocrConfidence: Float? = nil,
        source: ClipboardHistoryEntry.SourceContext? = nil
    ) {
        lastCopiedText = text
        let inheritedPinnedState = copyHistory.contains {
            $0.text == text &&
            $0.captureMode == captureMode &&
            $0.outputPreset == outputPreset &&
            $0.contentKind == contentKind &&
            $0.rawText == rawText &&
            $0.ocrConfidence == ocrConfidence &&
            $0.source == source &&
            $0.isPinned
        }
        copyHistory.removeAll {
            $0.text == text &&
            $0.captureMode == captureMode &&
            $0.outputPreset == outputPreset &&
            $0.contentKind == contentKind &&
            $0.rawText == rawText &&
            $0.ocrConfidence == ocrConfidence &&
            $0.source == source
        }
        copyHistory.insert(
            ClipboardHistoryEntry(
                text: text,
                date: date,
                captureMode: captureMode,
                outputPreset: outputPreset,
                contentKind: contentKind,
                rawText: rawText,
                ocrConfidence: ocrConfidence,
                source: source,
                isPinned: inheritedPinnedState
            ),
            at: 0
        )

        if copyHistory.count > ClipboardHistoryStore.maximumEntries {
            copyHistory.removeLast(copyHistory.count - ClipboardHistoryStore.maximumEntries)
        }

        persistHistoryIfNeeded()
    }

    func updateLaunchAtLoginState(_ state: LaunchAtLoginState) {
        launchAtLoginState = state
    }

    func setCaptureMode(_ mode: CaptureMode) {
        captureMode = mode
        persistCaptureModeIfNeeded()
    }

    func setCaptureOutputPreset(_ preset: CaptureOutputPreset) {
        captureOutputPreset = preset
        persistCaptureOutputPresetIfNeeded()
    }

    func setInterfaceLanguage(_ language: InterfaceLanguage) {
        interfaceLanguage = language
        persistInterfaceLanguageIfNeeded()

        guard watchState != .active,
              watchState != .selecting,
              captureState == .idle || captureState == .completed || captureState == .cancelled else {
            return
        }

        statusMessage = readyStatusMessage
    }

    func updateUpdateState(_ state: AppUpdateState) {
        updateState = state
    }

    func setWatchCopyBehavior(_ behavior: WatchCopyBehavior) {
        watchConfiguration.copyBehavior = behavior
        persistWatchConfigurationIfNeeded()
    }

    @discardableResult
    func setWatchRegexFilter(_ pattern: String) -> Bool {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            watchConfiguration.regexFilter = ""
            persistWatchConfigurationIfNeeded()
            return true
        }

        guard (try? NSRegularExpression(pattern: trimmed)) != nil else {
            return false
        }

        watchConfiguration.regexFilter = trimmed
        persistWatchConfigurationIfNeeded()
        return true
    }

    func upsertAppProfile(bundleIdentifier: String, appName: String) {
        let profile = AppCaptureProfile(
            bundleIdentifier: bundleIdentifier,
            appName: appName,
            captureMode: captureMode,
            outputPreset: captureOutputPreset,
            ocrLanguageSelection: ocrLanguageSelection
        )

        appProfiles.removeAll { $0.bundleIdentifier == bundleIdentifier }
        appProfiles.append(profile)
        appProfiles.sort { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
        persistAppProfilesIfNeeded()
        _ = syncActiveAppProfileIfNeeded()
    }

    func removeAppProfile(_ profile: AppCaptureProfile) {
        appProfiles.removeAll { $0.bundleIdentifier == profile.bundleIdentifier }
        persistAppProfilesIfNeeded()
    }

    func appProfile(for bundleIdentifier: String?) -> AppCaptureProfile? {
        guard let bundleIdentifier else {
            return nil
        }

        return appProfiles.first { $0.bundleIdentifier == bundleIdentifier }
    }

    var activeTargetBundleIdentifier: String? {
        activeSourceApp?.bundleIdentifier
    }

    func preferredRepasteOutputPreset(defaultingTo preset: CaptureOutputPreset) -> CaptureOutputPreset {
        appProfile(for: activeTargetBundleIdentifier)?.outputPreset ?? preset
    }

    func setHistoryExportFormat(_ format: ClipboardHistoryExportFormat) {
        historyExportFormat = format
        persistHistoryExportFormatIfNeeded()
    }

    func updateWatchState(_ state: WatchState) {
        watchState = state
    }

    func updateSpeechState(_ state: SpeechPlaybackState) {
        speechState = state
    }

    func updateActiveSourceApp(_ source: ClipboardHistoryEntry.SourceContext?) {
        activeSourceApp = source
        _ = syncActiveAppProfileIfNeeded(for: source)
    }

    func removeHistoryEntry(_ entry: ClipboardHistoryEntry) {
        copyHistory.removeAll { $0.id == entry.id }
        lastCopiedText = copyHistory.first?.text ?? ""
        persistHistoryIfNeeded()
    }

    func togglePinnedHistoryEntry(_ entry: ClipboardHistoryEntry) {
        guard let index = copyHistory.firstIndex(where: { $0.id == entry.id }) else {
            return
        }

        let existing = copyHistory[index]
        copyHistory[index] = ClipboardHistoryEntry(
            id: existing.id,
            text: existing.text,
            date: existing.date,
            captureMode: existing.captureMode,
            outputPreset: existing.outputPreset,
            contentKind: existing.contentKind,
            rawText: existing.rawText,
            ocrConfidence: existing.ocrConfidence,
            source: existing.source,
            isPinned: !existing.isPinned
        )
        persistHistoryIfNeeded()
    }

    func clearHistory() {
        copyHistory = []
        lastCopiedText = ""
        persistHistoryIfNeeded()
    }

    func presentTableReview(for entry: ClipboardHistoryEntry) {
        guard entry.captureMode == .table,
              entry.contentKind == .text else {
            return
        }

        activeTableReview = TableReviewSession(
            entry: entry,
            sourceText: entry.preferredTableSourceText
        )
    }

    func rememberCaptureSelection(_ selection: RecentCaptureSelection) {
        lastCaptureSelection = selection
    }

    @discardableResult
    func saveLastCaptureSelection() -> SavedCaptureRegion? {
        guard let selection = lastCaptureSelection else {
            return nil
        }

        let region = SavedCaptureRegion(
            name: nextSavedCaptureRegionName(for: selection),
            screenRect: selection.screenRect,
            preferredDisplayID: selection.preferredDisplayID,
            source: selection.source,
            sessionConfiguration: selection.sessionConfiguration
        )

        savedCaptureRegions.insert(region, at: 0)

        if savedCaptureRegions.count > SavedCaptureRegionStore.maximumEntries {
            savedCaptureRegions.removeLast(savedCaptureRegions.count - SavedCaptureRegionStore.maximumEntries)
        }

        persistSavedCaptureRegionsIfNeeded()
        return region
    }

    @discardableResult
    func refreshSavedCaptureRegion(_ region: SavedCaptureRegion) -> SavedCaptureRegion? {
        guard let selection = lastCaptureSelection,
              let index = savedCaptureRegions.firstIndex(where: { $0.id == region.id }) else {
            return nil
        }

        savedCaptureRegions[index] = SavedCaptureRegion(
            id: region.id,
            name: region.name,
            screenRect: selection.screenRect,
            preferredDisplayID: selection.preferredDisplayID,
            source: selection.source,
            sessionConfiguration: selection.sessionConfiguration,
            updatedAt: Date()
        )

        persistSavedCaptureRegionsIfNeeded()
        return savedCaptureRegions[index]
    }

    func removeSavedCaptureRegion(_ region: SavedCaptureRegion) {
        savedCaptureRegions.removeAll { $0.id == region.id }
        persistSavedCaptureRegionsIfNeeded()
    }

    func setSavedCaptureRegionQuickStartEnabled(_ isEnabled: Bool) {
        savedCaptureRegionQuickStartEnabled = isEnabled
        persistSavedCaptureRegionQuickStartIfNeeded()
    }

    func setAppProfilePanelAutoSyncEnabled(_ isEnabled: Bool) {
        appProfilePanelAutoSyncEnabled = isEnabled
        persistAppProfilePanelAutoSyncIfNeeded()

        guard isEnabled else {
            return
        }

        _ = syncActiveAppProfileIfNeeded()
    }

    func setSavedSnippetCollectionAutoSyncEnabled(_ isEnabled: Bool) {
        savedSnippetCollectionAutoSyncEnabled = isEnabled
        persistSavedSnippetCollectionAutoSyncIfNeeded()
    }

    @discardableResult
    func saveLastCopiedEntryAsSnippet() -> SavedSnippet? {
        guard let entry = lastCopiedEntry else {
            return nil
        }

        return saveHistoryEntryAsSnippet(entry)
    }

    @discardableResult
    func saveHistoryEntryAsSnippet(_ entry: ClipboardHistoryEntry) -> SavedSnippet {
        let updatedAt = Date()
        let defaultTags = Self.defaultSnippetTags(
            captureMode: entry.captureMode,
            outputPreset: entry.outputPreset,
            contentKind: entry.contentKind,
            source: entry.source
        )

        if let index = savedSnippets.firstIndex(where: {
            $0.text == entry.text &&
            $0.rawText == entry.rawText &&
            $0.captureMode == entry.captureMode &&
            $0.outputPreset == entry.outputPreset &&
            $0.contentKind == entry.contentKind &&
            $0.source == entry.source
        }) {
            let existing = savedSnippets[index]
            savedSnippets[index] = SavedSnippet(
                id: existing.id,
                name: existing.name,
                text: entry.text,
                rawText: entry.rawText,
                captureMode: entry.captureMode,
                outputPreset: entry.outputPreset,
                contentKind: entry.contentKind,
                ocrConfidence: entry.ocrConfidence,
                source: entry.source,
                tags: mergeSnippetTags(existing.tags, with: defaultTags),
                updatedAt: updatedAt,
                lastUsedAt: existing.lastUsedAt
            )
            sortSavedSnippets()
            persistSavedSnippetsIfNeeded()
            return savedSnippets.first(where: { $0.id == existing.id }) ?? savedSnippets[index]
        }

        let snippet = SavedSnippet(
            entry: entry,
            name: nextSavedSnippetName(for: entry),
            tags: defaultTags,
            updatedAt: updatedAt
        )

        savedSnippets.insert(snippet, at: 0)

        if savedSnippets.count > SavedSnippetStore.maximumEntries {
            savedSnippets.removeLast(savedSnippets.count - SavedSnippetStore.maximumEntries)
        }

        sortSavedSnippets()
        persistSavedSnippetsIfNeeded()
        return savedSnippets.first(where: { $0.id == snippet.id }) ?? snippet
    }

    func removeSavedSnippet(_ snippet: SavedSnippet) {
        savedSnippets.removeAll { $0.id == snippet.id }
        persistSavedSnippetsIfNeeded()
    }

    func updateSavedSnippetTags(_ tags: [String], for snippet: SavedSnippet) {
        guard let index = savedSnippets.firstIndex(where: { $0.id == snippet.id }) else {
            return
        }

        let existing = savedSnippets[index]
        savedSnippets[index] = SavedSnippet(
            id: existing.id,
            name: existing.name,
            text: existing.text,
            rawText: existing.rawText,
            captureMode: existing.captureMode,
            outputPreset: existing.outputPreset,
            contentKind: existing.contentKind,
            ocrConfidence: existing.ocrConfidence,
            source: existing.source,
            tags: tags,
            updatedAt: existing.updatedAt,
            lastUsedAt: existing.lastUsedAt
        )
        sortSavedSnippets()
        persistSavedSnippetsIfNeeded()
    }

    @discardableResult
    func noteSavedSnippetUsed(_ snippet: SavedSnippet, usedAt: Date = Date()) -> SavedSnippet? {
        guard let index = savedSnippets.firstIndex(where: { $0.id == snippet.id }) else {
            return nil
        }

        let existing = savedSnippets[index]
        let updated = SavedSnippet(
            id: existing.id,
            name: existing.name,
            text: existing.text,
            rawText: existing.rawText,
            captureMode: existing.captureMode,
            outputPreset: existing.outputPreset,
            contentKind: existing.contentKind,
            ocrConfidence: existing.ocrConfidence,
            source: existing.source,
            tags: existing.tags,
            updatedAt: existing.updatedAt,
            lastUsedAt: usedAt
        )
        savedSnippets[index] = updated
        persistSavedSnippetsIfNeeded()
        return updated
    }

    func suggestedTags(for snippet: SavedSnippet) -> [String] {
        let defaults = Self.defaultSnippetTags(
            captureMode: snippet.captureMode,
            outputPreset: snippet.outputPreset,
            contentKind: snippet.contentKind,
            source: snippet.source
        )
        return mergeSnippetTags(snippet.tags, with: defaults)
    }

    func savedSnippet(named name: String) -> SavedSnippet? {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }

        return savedSnippets.first {
            $0.name.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    func savedSnippetCollection(named name: String) -> SavedSnippetCollection? {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }

        return savedSnippetCollections.first {
            $0.name.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    @discardableResult
    func presentSettingsForSavedSnippetCollection(named name: String) -> Bool {
        guard let collection = savedSnippetCollection(named: name) else {
            return false
        }

        pendingSnippetCollectionSelectionName = collection.name
        settingsPresentationToken = UUID()
        return true
    }

    func consumePendingSnippetCollectionSelection() -> SavedSnippetCollection? {
        guard let pendingSnippetCollectionSelectionName else {
            return nil
        }

        self.pendingSnippetCollectionSelectionName = nil
        return savedSnippetCollection(named: pendingSnippetCollectionSelectionName)
    }

    func savedCaptureRegion(named name: String) -> SavedCaptureRegion? {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }

        return savedCaptureRegions.first {
            $0.name.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    func clearTableReview() {
        activeTableReview = nil
    }

    func buildSupportBundleReport(permissionSnapshot: PermissionDiagnosticSnapshot?) -> String {
        let formatter = ISO8601DateFormatter()
        let bundle = Bundle.main
        let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "ScreenTextGrab"
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "n/a"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "n/a"
        let bundleIdentifier = bundle.bundleIdentifier ?? "n/a"
        let appPath = bundle.bundleURL.path

        var lines = [
            "\(appName) Support Paketi",
            "Oluşturulma: \(formatter.string(from: Date()))",
            "Sürüm: \(version) (\(build))",
            "Bundle ID: \(bundleIdentifier)",
            "Uygulama Yolu: \(appPath)",
            "",
            "Çalışma Durumu",
            "İzin: \(permissionState.uiMessage)",
            "Launch at Login: \(launchAtLoginState.title)",
            "Kısayol: \(hotkeyDisplayLabel)",
            "\(L10n.pair("Yakalama Modu", "Capture Mode")): \(captureMode.title)",
            "Çıktı Biçimi: \(captureOutputPreset.title)",
            "İzleme: \(watchState.title)",
            "İzleme Kuralı: \(watchConfiguration.summary)",
            "Sesli Okuma: \(speechState.title)",
            "OCR: \(ocrLanguageSelection.summary)",
            "\(L10n.pair("Geçmiş Sayısı", "History Count")): \(copyHistory.count)",
            "Uygulama Profilleri: \(appProfiles.count)",
            "Kayıtlı Bölgeler: \(savedCaptureRegions.count)",
            "Kayıtlı Snippet'lar: \(savedSnippets.count)"
        ]

        if let permissionSnapshot {
            lines.append("")
            lines.append(permissionSnapshot.reportText)
        }

        lines.append("")
        lines.append("Tanı Kayıtları")

        if diagnostics.isEmpty {
            lines.append("Kayıt yok")
        } else {
            for entry in diagnostics {
                lines.append("\(formatter.string(from: entry.timestamp)) \(entry.summary)")
            }
        }

        return lines.joined(separator: "\n")
    }

    @discardableResult
    func setOCRLanguage(_ language: OCRLanguagePreference, enabled: Bool) -> Bool {
        guard let updated = ocrLanguageSelection.updating(language, enabled: enabled) else {
            return false
        }

        ocrLanguageSelection = updated
        persistOCRLanguagesIfNeeded()
        return true
    }

    func setOCRAutomaticDetection(_ enabled: Bool) {
        ocrLanguageSelection = ocrLanguageSelection.settingAutomaticDetection(enabled)
        persistOCRLanguagesIfNeeded()
    }

    func applyCaptureProfile(_ profile: AppCaptureProfile) {
        captureMode = profile.captureMode
        captureOutputPreset = profile.outputPreset
        ocrLanguageSelection = profile.ocrLanguageSelection
        persistCaptureModeIfNeeded()
        persistCaptureOutputPresetIfNeeded()
        persistOCRLanguagesIfNeeded()
    }

    private func persistHistoryIfNeeded() {
        guard persistsUserPreferences else { return }
        ClipboardHistoryStore.save(copyHistory, defaults: defaults)
    }

    private func persistOCRLanguagesIfNeeded() {
        guard persistsUserPreferences else { return }
        OCRLanguageSelectionStore.save(ocrLanguageSelection, defaults: defaults)
    }

    private func persistCaptureModeIfNeeded() {
        guard persistsUserPreferences else { return }
        CaptureModeStore.save(captureMode, defaults: defaults)
    }

    private func persistCaptureOutputPresetIfNeeded() {
        guard persistsUserPreferences else { return }
        CaptureOutputPresetStore.save(captureOutputPreset, defaults: defaults)
    }

    private func persistInterfaceLanguageIfNeeded() {
        guard persistsUserPreferences else { return }
        InterfaceLanguageStore.save(interfaceLanguage, defaults: defaults)
    }

    private func persistWatchConfigurationIfNeeded() {
        guard persistsUserPreferences else { return }
        WatchConfigurationStore.save(watchConfiguration, defaults: defaults)
    }

    private func persistAppProfilePanelAutoSyncIfNeeded() {
        guard persistsUserPreferences else { return }
        AppProfilePanelAutoSyncStore.save(appProfilePanelAutoSyncEnabled, defaults: defaults)
    }

    private func persistAppProfilesIfNeeded() {
        guard persistsUserPreferences else { return }
        AppCaptureProfileStore.save(appProfiles, defaults: defaults)
    }

    private func persistSavedCaptureRegionsIfNeeded() {
        guard persistsUserPreferences else { return }
        SavedCaptureRegionStore.save(savedCaptureRegions, defaults: defaults)
    }

    private func persistSavedCaptureRegionQuickStartIfNeeded() {
        guard persistsUserPreferences else { return }
        SavedCaptureRegionQuickStartStore.save(savedCaptureRegionQuickStartEnabled, defaults: defaults)
    }

    private func persistSavedSnippetCollectionAutoSyncIfNeeded() {
        guard persistsUserPreferences else { return }
        SavedSnippetCollectionAutoSyncStore.save(savedSnippetCollectionAutoSyncEnabled, defaults: defaults)
    }

    private func persistSavedSnippetsIfNeeded() {
        guard persistsUserPreferences else { return }
        SavedSnippetStore.save(savedSnippets, defaults: defaults)
    }

    private func persistSavedSnippetCollectionsIfNeeded() {
        guard persistsUserPreferences else { return }
        SavedSnippetCollectionStore.save(savedSnippetCollections, defaults: defaults)
    }

    private func sortSavedSnippets() {
        savedSnippets.sort { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func sortSavedSnippetCollections() {
        savedSnippetCollections.sort { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func persistHistoryExportFormatIfNeeded() {
        guard persistsUserPreferences else { return }
        ClipboardHistoryExportFormatStore.save(historyExportFormat, defaults: defaults)
    }

    private func nextSavedCaptureRegionName(for selection: RecentCaptureSelection) -> String {
        let sourceName = selection.source?.appName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName: String

        if let sourceName, !sourceName.isEmpty {
            baseName = "\(sourceName) • \(selection.sessionConfiguration.captureMode.title)"
        } else {
            baseName = "Alan • \(selection.sessionConfiguration.captureMode.title)"
        }

        guard savedCaptureRegions.contains(where: {
            $0.name.compare(baseName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else {
            return baseName
        }

        var suffix = 2
        while savedCaptureRegions.contains(where: {
            $0.name.compare("\(baseName) \(suffix)", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            suffix += 1
        }

        return "\(baseName) \(suffix)"
    }

    private func nextSavedSnippetName(for entry: ClipboardHistoryEntry) -> String {
        let previewBase = entry.previewText
        let baseName: String

        if !previewBase.isEmpty {
            baseName = String(previewBase.prefix(34))
        } else if let sourceName = entry.source?.appName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !sourceName.isEmpty {
            baseName = "\(sourceName) • \(entry.captureMode.title)"
        } else {
            baseName = "Snippet • \(entry.captureMode.title)"
        }

        guard savedSnippets.contains(where: {
            $0.name.compare(baseName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) == false else {
            var suffix = 2
            while savedSnippets.contains(where: {
                $0.name.compare("\(baseName) \(suffix)", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }) {
                suffix += 1
            }

            return "\(baseName) \(suffix)"
        }

        return baseName
    }

    private func mergeSnippetTags(_ existing: [String], with additions: [String]) -> [String] {
        var merged = existing

        for tag in additions where !merged.contains(where: {
            $0.compare(tag, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            merged.append(tag)
        }

        return merged
    }

    private static func defaultSnippetTags(
        captureMode: CaptureMode,
        outputPreset: CaptureOutputPreset,
        contentKind: ClipboardHistoryEntry.ContentKind,
        source: ClipboardHistoryEntry.SourceContext?
    ) -> [String] {
        var tags: [String] = [captureMode.title]

        if let sourceName = source?.displayName, !sourceName.isEmpty {
            tags.append(sourceName)
        }

        if contentKind != .text {
            tags.append(contentKind.title)
        }

        if outputPreset != .smart {
            tags.append(outputPreset.title)
        }

        return tags
    }

    private static func migratedSavedSnippets(_ snippets: [SavedSnippet]) -> [SavedSnippet] {
        snippets.map { snippet in
            guard snippet.tags.isEmpty else {
                return snippet
            }

            return SavedSnippet(
                id: snippet.id,
                name: snippet.name,
                text: snippet.text,
                rawText: snippet.rawText,
                captureMode: snippet.captureMode,
                outputPreset: snippet.outputPreset,
                contentKind: snippet.contentKind,
                ocrConfidence: snippet.ocrConfidence,
                source: snippet.source,
                tags: defaultSnippetTags(
                    captureMode: snippet.captureMode,
                    outputPreset: snippet.outputPreset,
                    contentKind: snippet.contentKind,
                    source: snippet.source
                ),
                updatedAt: snippet.updatedAt,
                lastUsedAt: snippet.lastUsedAt
            )
        }
    }

    private static var shouldPersistUserPreferences: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }
}

struct ActiveAppProfileSuggestion: Equatable, Sendable {
    let source: ClipboardHistoryEntry.SourceContext
    let profile: AppCaptureProfile
}

struct ActiveSavedCaptureRegionSuggestion: Equatable, Sendable {
    enum MatchKind: Equatable, Sendable {
        case application
        case windowTitle(String)
    }

    let source: ClipboardHistoryEntry.SourceContext
    let primaryRegion: SavedCaptureRegion
    let matchingRegions: [SavedCaptureRegion]
    let totalAppMatchingRegions: Int
    let matchKind: MatchKind

    var regionCount: Int {
        matchingRegions.count
    }
}

struct ActiveSavedSnippetCollectionSuggestion: Equatable, Sendable {
    enum MatchKind: Equatable, Sendable {
        case application
        case windowTitle(String)
    }

    let source: ClipboardHistoryEntry.SourceContext
    let collection: SavedSnippetCollection
    let matchingSnippets: [SavedSnippet]
    let totalAppMatchingSnippets: Int
    let matchKind: MatchKind

    var snippetCount: Int {
        matchingSnippets.count
    }

    var prefersWindowMatch: Bool {
        if case .windowTitle = matchKind {
            return true
        }

        return false
    }
}

struct ActiveSavedSnippetSuggestion: Equatable, Sendable {
    enum SelectionKind: Equatable, Sendable {
        case onlyMatch
        case learnedPreference
    }

    let source: ClipboardHistoryEntry.SourceContext
    let collection: SavedSnippetCollection
    let snippet: SavedSnippet
    let totalAppMatchingSnippets: Int
    let matchKind: ActiveSavedSnippetCollectionSuggestion.MatchKind
    let selectionKind: SelectionKind
}

private enum ScreenshotLaunchMode {
    case menuPanel
    case settingsGeneral
    case settingsOCR
    case settingsDiagnostics
    case settingsHistory
    case tableReview

    init?(arguments: [String]) {
        if arguments.contains("--screenshot-menu-panel") {
            self = .menuPanel
            return
        }

        if arguments.contains("--screenshot-settings-general") || arguments.contains("--screenshot-settings") {
            self = .settingsGeneral
            return
        }

        if arguments.contains("--screenshot-settings-ocr") {
            self = .settingsOCR
            return
        }

        if arguments.contains("--screenshot-settings-diagnostics") {
            self = .settingsDiagnostics
            return
        }

        if arguments.contains("--screenshot-settings-history") {
            self = .settingsHistory
            return
        }

        if arguments.contains("--screenshot-table-review") {
            self = .tableReview
            return
        }

        return nil
    }
}

@MainActor
private final class PreviewLaunchAtLoginManager: LaunchAtLoginManaging {
    private(set) var launchAtLoginState: LaunchAtLoginState

    init(state: LaunchAtLoginState) {
        self.launchAtLoginState = state
    }

    func refreshLaunchAtLoginState() -> LaunchAtLoginState {
        launchAtLoginState
    }

    func setLaunchAtLogin(enabled: Bool) async throws -> LaunchAtLoginState {
        launchAtLoginState = enabled ? .enabled : .disabled
        return launchAtLoginState
    }

    func openLoginItemsSettings() {}
}

@MainActor
private final class PreviewPermissionProvider: ScreenPermissionProviding {
    var needsRestartAfterGrant: Bool { false }

    private let snapshot: PermissionDiagnosticSnapshot

    init(snapshot: PermissionDiagnosticSnapshot) {
        self.snapshot = snapshot
    }

    func refreshPreflight() -> ScreenPermissionState {
        snapshot.currentState
    }

    func resolveState() async -> ScreenPermissionState {
        snapshot.currentState
    }

    func requestIfNeeded() async -> ScreenPermissionState {
        snapshot.currentState
    }

    func diagnosticSnapshot() async -> PermissionDiagnosticSnapshot {
        snapshot
    }

    func openSystemSettings() {}
}

enum InstalledAppLocator {
    static func isInstalledAppURL(
        _ url: URL,
        searchRoots: [URL] = defaultSearchRoots()
    ) -> Bool {
        let currentPath = standardizedPath(for: url)
        return searchRoots.contains { root in
            currentPath.hasPrefix(standardizedPath(for: root) + "/")
        }
    }

    static func preferredInstalledCopy(
        currentURL: URL,
        bundleIdentifier: String?,
        searchRoots: [URL] = defaultSearchRoots(),
        fileManager: FileManager = .default
    ) -> URL? {
        guard let targetBundleIdentifier = bundleIdentifier else {
            return nil
        }

        let currentPath = standardizedPath(for: currentURL)
        let currentBuildVersion = buildVersion(for: currentURL)
        let appName = currentURL.lastPathComponent
        let bundledCandidates = searchRoots.flatMap { root in
            appBundleCandidates(in: root, fileManager: fileManager)
        }
        let directNameCandidates = searchRoots.map {
            $0.appendingPathComponent(appName, isDirectory: true)
        }

        let candidates = uniqueURLs(from: directNameCandidates + bundledCandidates)
            .filter { standardizedPath(for: $0) != currentPath }
            .filter { appBundleIdentifier(for: $0) == targetBundleIdentifier }
            .sorted { lhs, rhs in
                ranking(for: lhs, preferredAppName: appName) < ranking(for: rhs, preferredAppName: appName)
            }

        guard let candidate = candidates.first else {
            return nil
        }

        if let currentBuildVersion, let candidateBuildVersion = buildVersion(for: candidate),
           candidateBuildVersion.compare(currentBuildVersion, options: .numeric) == .orderedAscending {
            return nil
        }

        return candidate
    }

    static func preferredInstallDestination(
        currentURL: URL,
        bundleIdentifier: String?,
        searchRoots: [URL] = defaultSearchRoots(),
        fileManager: FileManager = .default
    ) -> URL? {
        let appName = currentURL.lastPathComponent
        let bundledCandidates = searchRoots.flatMap { root in
            appBundleCandidates(in: root, fileManager: fileManager)
        }
        let directNameCandidates = searchRoots.map {
            $0.appendingPathComponent(appName, isDirectory: true)
        }

        let existingCandidates = uniqueURLs(from: directNameCandidates + bundledCandidates)
            .filter { candidate in
                guard let bundleIdentifier else {
                    return candidate.lastPathComponent == appName
                }

                return appBundleIdentifier(for: candidate) == bundleIdentifier
            }
            .sorted { lhs, rhs in
                ranking(for: lhs, preferredAppName: appName) < ranking(for: rhs, preferredAppName: appName)
            }

        if let existingCandidate = existingCandidates.first {
            return existingCandidate
        }

        for root in searchRoots {
            if ensureInstallRootExistsAndIsWritable(root, fileManager: fileManager) {
                return root.appendingPathComponent(appName, isDirectory: true)
            }
        }

        return nil
    }

    static func defaultSearchRoots(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            homeDirectory.appendingPathComponent("Applications", isDirectory: true)
        ]
    }

    private static func appBundleCandidates(in root: URL, fileManager: FileManager) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter { $0.pathExtension.lowercased() == "app" }
    }

    private static func appBundleIdentifier(for url: URL) -> String? {
        Bundle(url: url)?.bundleIdentifier
    }

    private static func buildVersion(for url: URL) -> String? {
        Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    private static func uniqueURLs(from urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { url in
            let path = standardizedPath(for: url)
            return seen.insert(path).inserted
        }
    }

    private static func ranking(for url: URL, preferredAppName: String) -> (Int, Int, String) {
        let path = standardizedPath(for: url)
        let applicationsRank = path.hasPrefix("/Applications/") ? 0 : 1
        let nameRank = url.lastPathComponent == preferredAppName ? 0 : 1
        return (applicationsRank, nameRank, path)
    }

    private static func standardizedPath(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private static func ensureInstallRootExistsAndIsWritable(_ root: URL, fileManager: FileManager) -> Bool {
        let path = standardizedPath(for: root)
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            return isDirectory.boolValue && fileManager.isWritableFile(atPath: path)
        }

        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            return fileManager.isWritableFile(atPath: path)
        } catch {
            return false
        }
    }
}

enum InstalledAppRelocatorError: LocalizedError {
    case noInstallDestination
    case copyFailed(String)

    var errorDescription: String? {
        switch self {
        case .noInstallDestination:
            return L10n.installRootUnavailable
        case .copyFailed(let message):
            return "\(L10n.installCopyFailedPrefix) \(message)"
        }
    }
}

enum InstalledAppRelocator {
    static func installCurrentCopy(
        from currentURL: URL,
        bundleIdentifier: String?,
        searchRoots: [URL] = InstalledAppLocator.defaultSearchRoots(),
        fileManager: FileManager = .default
    ) throws -> URL {
        guard let destinationURL = InstalledAppLocator.preferredInstallDestination(
            currentURL: currentURL,
            bundleIdentifier: bundleIdentifier,
            searchRoots: searchRoots,
            fileManager: fileManager
        ) else {
            throw InstalledAppRelocatorError.noInstallDestination
        }

        let sourceURL = currentURL.resolvingSymlinksInPath().standardizedFileURL
        let targetURL = destinationURL.resolvingSymlinksInPath().standardizedFileURL

        if sourceURL.path == targetURL.path {
            return targetURL
        }

        do {
            try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }

            try fileManager.copyItem(at: sourceURL, to: targetURL)
            return targetURL
        } catch {
            throw InstalledAppRelocatorError.copyFailed(error.localizedDescription)
        }
    }
}

enum SourceContextResolver {
    static func currentFrontmostExternalSourceContext() -> ClipboardHistoryEntry.SourceContext? {
        externalSourceContext(for: NSWorkspace.shared.frontmostApplication)
    }

    static func externalSourceContext(
        for application: NSRunningApplication?
    ) -> ClipboardHistoryEntry.SourceContext? {
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let bundleIdentifier = application?.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)

        if bundleIdentifier == ownBundleIdentifier {
            return nil
        }

        let appName = application?.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (appName?.isEmpty == false) || (bundleIdentifier?.isEmpty == false) else {
            return nil
        }

        return ClipboardHistoryEntry.SourceContext(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            windowTitle: focusedWindowTitle(for: application)
        )
    }

    private static func focusedWindowTitle(for application: NSRunningApplication?) -> String? {
        guard AXIsProcessTrusted(),
              let application else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        if let title = windowTitle(attribute: kAXFocusedWindowAttribute as CFString, for: appElement) {
            return title
        }

        return windowTitle(attribute: kAXMainWindowAttribute as CFString, for: appElement)
    }

    private static func windowTitle(attribute: CFString, for appElement: AXUIElement) -> String? {
        var rawWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, attribute, &rawWindow) == .success,
              let rawWindow else {
            return nil
        }

        guard CFGetTypeID(rawWindow) == AXUIElementGetTypeID() else {
            return nil
        }

        let windowElement = unsafeBitCast(rawWindow, to: AXUIElement.self)
        var rawTitle: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &rawTitle) == .success,
              let title = rawTitle as? String else {
            return nil
        }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    private var hotkeyService: HotkeyService?
    private var launchAtLoginService: LaunchAtLoginService?
    private var permissionService: ScreenPermissionService?
    private var captureCoordinator: CaptureCoordinator?
    private var speechService: SpeechService?
    private var appUpdateService: AppUpdateService?
    private var previewWindowController: NSWindowController?
    private var previewLaunchAtLoginManager: PreviewLaunchAtLoginManager?
    private var previewPermissionProvider: PreviewPermissionProvider?
    private var finderImportServiceProvider: FinderImportServiceProvider?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var workspaceActivationObserver: NSObjectProtocol?
    private var pendingAutomationCommands: [AutomationCommand] = []
    private var screenshotLaunchMode: ScreenshotLaunchMode? {
        ScreenshotLaunchMode(arguments: ProcessInfo.processInfo.arguments)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let screenshotLaunchMode {
            NSApp.setActivationPolicy(.regular)
            configurePreviewState()
            showPreview(for: screenshotLaunchMode)
            return
        }

        let launchAtLoginService = LaunchAtLoginService()
        self.launchAtLoginService = launchAtLoginService

        if handleLaunchAtLoginCommandIfNeeded(using: launchAtLoginService) {
            return
        }

        if let automationCommand = AutomationCommand(arguments: ProcessInfo.processInfo.arguments) {
            pendingAutomationCommands.append(automationCommand)
        }

        NSApp.setActivationPolicy(.accessory)

        guard enforceCanonicalInstallLocation() else {
            return
        }

        let permissionService = ScreenPermissionService()
        let screenCaptureService = ScreenCaptureService()
        let ocrService = OCRService()
        let clipboardService = ClipboardManager()

        let coordinator = CaptureCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: ocrService,
            clipboardService: clipboardService
        )

        self.permissionService = permissionService
        self.captureCoordinator = coordinator
        appState.coordinator = coordinator
        appState.permissionDiagnosticsProvider = permissionService

        let hotkeyService = HotkeyService { [weak coordinator] in
            coordinator?.startCapture(trigger: .hotkey)
        }
        let speechService = SpeechService { [weak appState] state in
            appState?.updateSpeechState(state)
        }
        self.hotkeyService = hotkeyService
        self.speechService = speechService
        self.appUpdateService = AppUpdateService(appState: appState)
        appState.hotkeyManager = self
        appState.launchAtLoginManager = self
        appState.speechManager = self
        appState.updateManager = appUpdateService
        appState.updateLaunchAtLoginState(launchAtLoginService.refreshState())
        appState.updateSpeechState(speechService.state)
        Task { @MainActor [weak self] in
            let state = await launchAtLoginService.bootstrapState()
            self?.appState.updateLaunchAtLoginState(state)
        }

        do {
            try hotkeyService.registerHotkey()
            appState.updateHotkeyAvailability(isAvailable: true, label: hotkeyService.hotkeyDisplayLabel)
        } catch {
            let nsError = error as NSError
            appState.updateHotkeyAvailability(isAvailable: false, label: hotkeyService.hotkeyDisplayLabel)
            appState.appendDiagnostic(
                category: "hotkey",
                message: error.localizedDescription,
                domain: nsError.domain,
                code: nsError.code,
                severity: .warning
            )
            STGLog.capture.error("Hotkey registration failed: \(error.localizedDescription, privacy: .public)")
        }

        beginActiveAppTracking()

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak coordinator] _ in
            Task { @MainActor in
                coordinator?.refreshPermission()
                if let state = self?.launchAtLoginService?.refreshState() {
                    self?.appState.updateLaunchAtLoginState(state)
                }
            }
        }

        if #available(macOS 14.0, *) {
            ScreenTextGrabShortcutsProvider.updateAppShortcutParameters()
        }

        configureFinderImportServices()
        flushPendingAutomationCommands()

        beginStartupExperience(using: coordinator, permissionService: permissionService)
    }

    func applicationWillTerminate(_ notification: Notification) {
        captureCoordinator?.stopWatching()
        speechService?.stopSpeaking()
        hotkeyService?.unregisterHotkey()
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
        if let workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceActivationObserver)
        }
    }

    private func enforceCanonicalInstallLocation() -> Bool {
        let currentURL = Bundle.main.bundleURL.resolvingSymlinksInPath()

        #if DEBUG
        // Debug builds may run from any location (e.g. Xcode DerivedData) for development.
        // To avoid Spotlight clutter, unregister this transient copy from Launch Services.
        unregisterNonCanonicalCopyFromLaunchServicesIfNeeded(currentURL)
        return true
        #else
        let currentPath = currentURL.path

        if isRunningUnderTests {
            return true
        }

        if InstalledAppLocator.isInstalledAppURL(currentURL) {
            STGLog.lifecycle.info("Running from supported app location: \(currentPath, privacy: .public)")
            return true
        }

        guard let installedCopyURL = InstalledAppLocator.preferredInstalledCopy(
            currentURL: currentURL,
            bundleIdentifier: Bundle.main.bundleIdentifier
        ) else {
            do {
                let relocatedURL = try InstalledAppRelocator.installCurrentCopy(
                    from: currentURL,
                    bundleIdentifier: Bundle.main.bundleIdentifier
                )

                STGLog.lifecycle.info("Relocated app to canonical path: \(relocatedURL.path, privacy: .public)")
                appState.captureState = .idle
                appState.permissionState = .unknown
                appState.statusMessage = L10n.installRelocatingStatus

                unregisterNonCanonicalCopyFromLaunchServicesIfNeeded(currentURL)
                NSWorkspace.shared.open(relocatedURL)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    NSApplication.shared.terminate(nil)
                }

                return false
            } catch {
                STGLog.lifecycle.warning("Canonical install relocation failed: \(error.localizedDescription, privacy: .public)")
                appState.statusMessage = L10n.installOpenFromApplicationsStatus
                presentInstallLocationAlert(for: currentURL, error: error)
                return true
            }
        }

        STGLog.lifecycle.error("Unsupported app path: \(currentPath, privacy: .public)")
        appState.captureState = .failed
        appState.permissionState = .unknown
        appState.statusMessage = L10n.installOpeningInstalledCopyStatus

        unregisterNonCanonicalCopyFromLaunchServicesIfNeeded(currentURL)

        NSWorkspace.shared.open(installedCopyURL)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            NSApplication.shared.terminate(nil)
        }

        return false
        #endif
    }

    private func presentInstallLocationAlert(for appURL: URL, error: Error) {
        guard !isRunningUnderTests else {
            return
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.installAlertTitle
        alert.informativeText = [
            L10n.installAlertBody,
            error.localizedDescription
        ].joined(separator: "\n\n")
        alert.addButton(withTitle: L10n.actionOpenApplicationsFolder)
        alert.addButton(withTitle: L10n.actionContinue)

        if alert.runModal() == .alertFirstButtonReturn {
            let destinationFolder = InstalledAppLocator.defaultSearchRoots().first ?? appURL.deletingLastPathComponent()
            NSWorkspace.shared.open(destinationFolder)
        }
    }

    private func unregisterNonCanonicalCopyFromLaunchServicesIfNeeded(_ appURL: URL) {
        guard !InstalledAppLocator.isInstalledAppURL(appURL) else {
            return
        }

        guard let lsregisterPath = launchServicesRegisterExecutablePath() else {
            STGLog.lifecycle.warning("Launch Services executable not found; skipping unregister")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: lsregisterPath)
        process.arguments = ["-u", appURL.path]

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                STGLog.lifecycle.info("Unregistered non-canonical copy from Launch Services: \(appURL.path, privacy: .public)")
            } else {
                STGLog.lifecycle.warning("Launch Services unregister returned status=\(process.terminationStatus, privacy: .public)")
            }
        } catch {
            STGLog.lifecycle.warning("Launch Services unregister failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func launchServicesRegisterExecutablePath() -> String? {
        let candidates = [
            "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister",
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        ]

        return candidates.first(where: { FileManager.default.fileExists(atPath: $0) })
    }

    private var isRunningUnderTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil
    }

    private func beginActiveAppTracking() {
        updateActiveSourceApp(SourceContextResolver.currentFrontmostExternalSourceContext())

        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.updateActiveSourceApp(SourceContextResolver.externalSourceContext(for: application))
        }
    }

    private func updateActiveSourceApp(_ source: ClipboardHistoryEntry.SourceContext?) {
        guard let source else {
            return
        }

        appState.updateActiveSourceApp(source)
    }

    @MainActor
    private func configurePreviewState() {
        let previewLaunchManager = PreviewLaunchAtLoginManager(state: .enabled)
        let bundle = Bundle.main
        let sourceExcel = ClipboardHistoryEntry.SourceContext(
            appName: "Microsoft Excel",
            bundleIdentifier: "com.microsoft.Excel",
            windowTitle: L10n.pair("Q2 Gelir Tablosu", "Q2 Revenue Table")
        )
        let sourceWord = ClipboardHistoryEntry.SourceContext(
            appName: "Microsoft Word",
            bundleIdentifier: "com.microsoft.Word",
            windowTitle: "Teklif Taslagi"
        )
        let sourceSafari = ClipboardHistoryEntry.SourceContext(
            appName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            windowTitle: "Satis Paneli"
        )
        let sourceXcode = ClipboardHistoryEntry.SourceContext(
            appName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            windowTitle: "OCRService.swift"
        )
        let previewPermissionService = PreviewPermissionProvider(
            snapshot: PermissionDiagnosticSnapshot(
                timestamp: Date(),
                currentState: .granted,
                preflightGranted: true,
                probeState: .granted,
                needsRestartAfterGrant: false,
                lastConfirmedGrantAt: Date(),
                lastProbeAt: Date(),
                bundleIdentifier: bundle.bundleIdentifier ?? "dev.screentextgrab.app",
                appPath: "/Applications/ScreenTextGrab.app",
                marketingVersion: (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0.3",
                buildVersion: (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "4"
            )
        )

        previewLaunchAtLoginManager = previewLaunchManager
        previewPermissionProvider = previewPermissionService

        appState.permissionState = .granted
        appState.captureState = .idle
        appState.statusMessage = "Hazır"
        appState.isHotkeyAvailable = true
        appState.hotkeyDisplayLabel = HotkeyConfiguration.defaultValue.displayLabel
        appState.launchAtLoginState = .enabled
        appState.captureMode = .table
        appState.captureOutputPreset = .office
        appState.watchState = .inactive
        appState.speechState = .idle
        appState.ocrLanguageSelection = .defaultValue
        appState.watchConfiguration = WatchConfiguration(
            copyBehavior: .wholeResult,
            regexFilter: L10n.pair("Fatura|Toplam", "Invoice|Total")
        )
        appState.permissionDiagnosticsProvider = previewPermissionService
        appState.launchAtLoginManager = previewLaunchManager
        appState.appProfilePanelAutoSyncEnabled = true
        appState.savedCaptureRegionQuickStartEnabled = true
        appState.savedSnippetCollectionAutoSyncEnabled = true
        appState.historyExportFormat = .markdown
        appState.activeSourceApp = sourceExcel
        appState.appProfiles = [
            AppCaptureProfile(
                bundleIdentifier: "com.microsoft.Excel",
                appName: "Microsoft Excel",
                captureMode: .table,
                outputPreset: .office,
                ocrLanguageSelection: .defaultValue
            ),
            AppCaptureProfile(
                bundleIdentifier: "com.apple.dt.Xcode",
                appName: "Xcode",
                captureMode: .code,
                outputPreset: .markdown,
                ocrLanguageSelection: .defaultValue
            ),
            AppCaptureProfile(
                bundleIdentifier: "com.apple.Safari",
                appName: "Safari",
                captureMode: .standard,
                outputPreset: .cleaned,
                ocrLanguageSelection: .defaultValue
            )
        ]
        appState.diagnostics = [
            DiagnosticEntry(
                timestamp: Date().addingTimeInterval(-240),
                category: "permission",
                message: L10n.pair("Screen Recording izni dogrulandi ve grant kaniti guncellendi.", "Screen Recording permission was verified and the grant evidence was refreshed."),
                domain: "ScreenPermissionService",
                code: 0,
                severity: .info
            ),
            DiagnosticEntry(
                timestamp: Date().addingTimeInterval(-540),
                category: "automation",
                message: L10n.pair("stg clipboard-image komutu sorunsuz tamamlandi.", "The stg clipboard-image command completed successfully."),
                domain: "AutomationSupport",
                code: 0,
                severity: .info
            ),
            DiagnosticEntry(
                timestamp: Date().addingTimeInterval(-1120),
                category: "ocr",
                message: L10n.pair("Dusuk guvenli satirlar tablo duzenleyici ile tekrar gozden gecirildi.", "Low-confidence rows were reviewed again in the table editor."),
                domain: "OCRService",
                code: 14,
                severity: .warning
            )
        ]

        let sampleEntries = screenshotHistoryEntries()
        appState.copyHistory = sampleEntries
        appState.lastCopiedText = sampleEntries.first?.text ?? ""
        appState.savedCaptureRegions = [
            SavedCaptureRegion(
                name: L10n.pair("Excel • Q2 Toplamlar", "Excel • Q2 Totals"),
                screenRect: CGRect(x: 420, y: 220, width: 960, height: 420),
                preferredDisplayID: nil,
                source: sourceExcel,
                sessionConfiguration: CaptureSessionConfiguration(
                    captureMode: .table,
                    outputPreset: .office,
                    ocrLanguageSelection: .defaultValue,
                    profileName: "Excel"
                ),
                updatedAt: Date().addingTimeInterval(-320)
            ),
            SavedCaptureRegion(
                name: L10n.pair("Safari • Dashboard Ozet", "Safari • Dashboard Summary"),
                screenRect: CGRect(x: 360, y: 180, width: 1040, height: 360),
                preferredDisplayID: nil,
                source: sourceSafari,
                sessionConfiguration: CaptureSessionConfiguration(
                    captureMode: .standard,
                    outputPreset: .cleaned,
                    ocrLanguageSelection: .defaultValue,
                    profileName: "Safari"
                ),
                updatedAt: Date().addingTimeInterval(-780)
            )
        ]
        appState.savedSnippets = [
            SavedSnippet(
                name: L10n.pair("Excel Ozet Tablosu", "Excel Summary Table"),
                text: L10n.usesEnglish
                    ? "Product\tPlan\tUnits\tTotal\nScreenTextGrab Pro\tAnnual\t12\t14,400 TRY"
                    : "Urun\tPlan\tAdet\tToplam\nScreenTextGrab Pro\tYillik\t12\t14.400 TL",
                rawText: L10n.usesEnglish
                    ? "Product\tPlan\tUnits\tTotal\nScreenTextGrab Pro\tAnnual\t12\t14,400 TRY"
                    : "Urun\tPlan\tAdet\tToplam\nScreenTextGrab Pro\tYillik\t12\t14.400 TL",
                captureMode: .table,
                outputPreset: .office,
                contentKind: .text,
                ocrConfidence: 0.93,
                source: sourceExcel,
                tags: L10n.usesEnglish ? ["report", "excel", "table"] : ["rapor", "excel", "tablo"],
                updatedAt: Date().addingTimeInterval(-180)
            ),
            SavedSnippet(
                name: L10n.pair("Word Aciklama Blogu", "Word Description Block"),
                text: L10n.pair("OCR tamamlandi. Office uyumlu zengin cikti panoya hazirlandi.", "OCR completed. Office-friendly rich output has been prepared on the clipboard."),
                rawText: nil,
                captureMode: .standard,
                outputPreset: .office,
                contentKind: .text,
                ocrConfidence: 0.88,
                source: sourceWord,
                tags: L10n.usesEnglish ? ["word", "description"] : ["word", "aciklama"],
                updatedAt: Date().addingTimeInterval(-520)
            ),
            SavedSnippet(
                name: L10n.pair("Xcode Log Filtre", "Xcode Log Filter"),
                text: "error: permissionDenied\nwarning: retrying capture pipeline",
                rawText: nil,
                captureMode: .code,
                outputPreset: .markdown,
                contentKind: .text,
                ocrConfidence: 0.79,
                source: sourceXcode,
                tags: L10n.usesEnglish ? ["xcode", "log", "code"] : ["xcode", "log", "kod"],
                updatedAt: Date().addingTimeInterval(-940),
                lastUsedAt: Date().addingTimeInterval(-120)
            )
        ]
        appState.savedSnippetCollections = [
            SavedSnippetCollection(
                name: L10n.pair("Excel Raporlari", "Excel Reports"),
                selectedTag: "excel",
                searchQuery: L10n.pair("Toplam", "Total"),
                updatedAt: Date().addingTimeInterval(-90)
            ),
            SavedSnippetCollection(
                name: L10n.pair("Kod ve Log", "Code and Logs"),
                selectedTag: L10n.pair("kod", "code"),
                searchQuery: "error",
                updatedAt: Date().addingTimeInterval(-610)
            )
        ]
        appState.rememberCaptureSelection(
            RecentCaptureSelection(
            screenRect: CGRect(x: 420, y: 220, width: 960, height: 420),
            preferredDisplayID: nil,
            source: sourceExcel,
            sessionConfiguration: CaptureSessionConfiguration(
                captureMode: .table,
                outputPreset: .office,
                ocrLanguageSelection: .defaultValue,
                profileName: "Excel"
            )
            )
        )
        if let tableEntry = sampleEntries.first(where: { $0.captureMode == .table }) {
            appState.activeTableReview = TableReviewSession(
                entry: tableEntry,
                sourceText: tableEntry.preferredTableSourceText
            )
        }
    }

    @MainActor
    private func configureMenuPanelPreviewState() {
        configurePreviewState()
        appState.statusMessage = L10n.pair("Hazır", "Ready")
        appState.launchAtLoginState = .disabled
        appState.watchState = .inactive
        appState.hotkeyDisplayLabel = HotkeyConfiguration.defaultValue.displayLabel
    }

    private func screenshotHistoryEntries() -> [ClipboardHistoryEntry] {
        [
            ClipboardHistoryEntry(
                text: L10n.usesEnglish
                    ? "Product\tPlan\tUnits\tTotal\nScreenTextGrab Pro\tAnnual\t12\t14,400 TRY\nOCR Office Pack\tTeam\t3\t5,700 TRY\nSupport\tPremium\t1\t1,250 TRY\nGrand Total\t\t\t21,350 TRY"
                    : "Urun\tPlan\tAdet\tToplam\nScreenTextGrab Pro\tYillik\t12\t14.400 TL\nOCR Office Pack\tTakim\t3\t5.700 TL\nDestek\tPremium\t1\t1.250 TL\nGenel Toplam\t\t\t21.350 TL",
                date: Date(),
                captureMode: .table,
                outputPreset: .office,
                contentKind: .text,
                rawText: L10n.usesEnglish
                    ? "Product\tPlan\tUnits\tTotal\nScreenTextGrab Pro\tAnnual\t12\t14,400 TRY\nOCR Office Pack\tTeam\t3\t5,700 TRY\nSupport\tPremium\t1\t1,250 TRY\nGrand Total\t\t\t21,350 TRY"
                    : "Urun\tPlan\tAdet\tToplam\nScreenTextGrab Pro\tYillik\t12\t14.400 TL\nOCR Office Pack\tTakim\t3\t5.700 TL\nDestek\tPremium\t1\t1.250 TL\nGenel Toplam\t\t\t21.350 TL",
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                isPinned: true
            ),
            ClipboardHistoryEntry(
                text: L10n.pair("OCR tamamlandi. Son pano cikisi Word uyumlu bicimde hazirlandi.", "OCR completed. The latest clipboard output was prepared in a Word-friendly format."),
                date: Date().addingTimeInterval(-320),
                captureMode: .standard,
                outputPreset: .office,
                contentKind: .text,
                source: .init(appName: "Microsoft Word", bundleIdentifier: "com.microsoft.Word")
            )
        ]
    }

    @MainActor
    private func showPreview(for mode: ScreenshotLaunchMode) {
        switch mode {
        case .menuPanel:
            configureMenuPanelPreviewState()
            let previewSize = NSSize(width: 404, height: 1110)
            showPreviewWindow(
                title: "ScreenTextGrab",
                size: previewSize,
                styleMask: [.borderless],
                isOpaque: false,
                backgroundColor: .clear,
                hasShadow: true,
                canBecomeKey: false
            ) {
                MenuBarView()
                    .environmentObject(self.appState)
                    .padding(22)
                    .frame(width: previewSize.width, height: previewSize.height, alignment: .top)
                    .background(Color(red: 0.03, green: 0.07, blue: 0.10))
            }
        case .settingsGeneral:
            showPreviewWindow(
                title: L10n.pair("Ayarlar", "Settings"),
                size: NSSize(width: 840, height: 980)
            ) {
                SettingsView(initialTab: .general)
                    .environmentObject(self.appState)
                    .frame(width: 840, height: 980)
            }
        case .settingsOCR:
            showPreviewWindow(
                title: L10n.pair("Ayarlar", "Settings"),
                size: NSSize(width: 840, height: 760)
            ) {
                SettingsView(initialTab: .ocr)
                    .environmentObject(self.appState)
                    .frame(width: 840, height: 760)
            }
        case .settingsDiagnostics:
            showPreviewWindow(
                title: L10n.pair("Ayarlar", "Settings"),
                size: NSSize(width: 840, height: 880)
            ) {
                SettingsView(initialTab: .diagnostics)
                    .environmentObject(self.appState)
                    .frame(width: 840, height: 880)
            }
        case .settingsHistory:
            appState.pendingSnippetCollectionSelectionName = L10n.pair("Excel Raporlari", "Excel Reports")
            showPreviewWindow(
                title: L10n.pair("Ayarlar", "Settings"),
                size: NSSize(width: 840, height: 1260)
            ) {
                SettingsView(initialTab: .history)
                    .environmentObject(self.appState)
                    .frame(width: 840, height: 1260)
            }
        case .tableReview:
            showPreviewWindow(
                title: L10n.pair("Tablo Duzenleyici", "Table Editor"),
                size: NSSize(width: 1020, height: 720)
            ) {
                TableReviewView()
                    .environmentObject(self.appState)
                    .frame(width: 1020, height: 720)
            }
        }
    }

    @MainActor
    private func showPreviewWindow<Content: View>(
        title: String,
        size: NSSize,
        styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable],
        isOpaque: Bool = true,
        backgroundColor: NSColor = .windowBackgroundColor,
        hasShadow: Bool = true,
        canBecomeKey: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        if let window = previewWindowController?.window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        let controller = NSWindowController(window: window)

        window.title = title
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = backgroundColor
        window.isOpaque = isOpaque
        window.hasShadow = hasShadow
        window.titleVisibility = styleMask.contains(.titled) ? .visible : .hidden
        window.center()
        window.contentView = NSHostingView(rootView: content())
        window.setContentSize(size)

        previewWindowController = controller
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        if canBecomeKey {
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFrontRegardless()
        }
        window.orderFrontRegardless()
    }

    private func handleLaunchAtLoginCommandIfNeeded(using service: LaunchAtLoginService) -> Bool {
        guard let command = LaunchAtLoginCommand(arguments: ProcessInfo.processInfo.arguments) else {
            return false
        }

        Task { @MainActor in
            do {
                let state: LaunchAtLoginState
                switch command {
                case .status:
                    state = service.refreshState()
                case .enable:
                    state = try await service.setEnabled(true)
                case .disable:
                    state = try await service.setEnabled(false)
                }

                writeLaunchAtLoginCommandOutput("launch-at-login=\(state.cliValue)")
            } catch {
                writeLaunchAtLoginCommandOutput("launch-at-login-error=\(error.localizedDescription)")
            }

            NSApplication.shared.terminate(nil)
        }

        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor [weak self] in
            self?.handleIncomingURLs(urls)
        }
    }

    private func writeLaunchAtLoginCommandOutput(_ message: String) {
        guard let data = "\(message)\n".data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }

    private func scheduleInitialPermissionRefreshes(for coordinator: CaptureCoordinator) {
        let refreshDelays: [TimeInterval] = [0.8, 2.0]
        for delay in refreshDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak coordinator] in
                Task { @MainActor in
                    coordinator?.refreshPermission()
                }
            }
        }
    }

    private func configureFinderImportServices() {
        guard !isRunningUnderTests else {
            return
        }

        let provider = FinderImportServiceProvider { [weak self] urls in
            self?.handleIncomingURLs(urls)
        }
        finderImportServiceProvider = provider
        NSApp.servicesProvider = provider

        let portName = ((Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 } ?? "ScreenTextGrab"
        NSRegisterServicesProvider(provider, portName)
        NSUpdateDynamicServices()
    }

    @MainActor
    private func handleIncomingURLs(_ urls: [URL]) {
        let commands = urls.compactMap(AutomationCommand.init(incomingURL:))
        guard !commands.isEmpty else {
            if !urls.isEmpty {
                appState.statusMessage = L10n.pair(
                    "⚠️ Yalnızca görsel veya PDF dosyaları desteklenir.",
                    "⚠️ Only image and PDF files are supported."
                )
            }
            return
        }

        pendingAutomationCommands.append(contentsOf: commands)
        flushPendingAutomationCommands()
    }

    private func beginStartupExperience(
        using coordinator: CaptureCoordinator,
        permissionService: ScreenPermissionService
    ) {
        DispatchQueue.main.async { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }

            Task { @MainActor [weak self, weak coordinator] in
                guard let self, let coordinator else { return }

                let ownBundleIdentifier = Bundle.main.bundleIdentifier
                let isForegroundLaunch = NSApp.isActive ||
                    NSWorkspace.shared.frontmostApplication?.bundleIdentifier == ownBundleIdentifier
                let state = await permissionService.resolveStartupState(isForegroundLaunch: isForegroundLaunch)
                coordinator.syncPermissionState(state)
                self.scheduleInitialPermissionRefreshes(for: coordinator)
            }
        }
    }

    @MainActor
    private func flushPendingAutomationCommands() {
        guard let coordinator = captureCoordinator, !pendingAutomationCommands.isEmpty else {
            return
        }

        let commands = pendingAutomationCommands
        pendingAutomationCommands.removeAll()

        for command in commands {
            dispatchAutomationCommand(command, coordinator: coordinator)
        }
    }

    @MainActor
    private func dispatchAutomationCommand(
        _ command: AutomationCommand,
        coordinator: CaptureCoordinator
    ) {
        switch command {
        case .capture(let overrides):
            NSApp.activate(ignoringOtherApps: true)
            coordinator.startCapture(trigger: .automation, sessionOverrides: overrides.isEmpty ? nil : overrides)
        case .repeatLast(let overrides):
            NSApp.activate(ignoringOtherApps: true)
            coordinator.repeatLastCapture(sessionOverrides: overrides.isEmpty ? nil : overrides)
        case .savedRegion(let name, let overrides):
            NSApp.activate(ignoringOtherApps: true)
            coordinator.captureSavedRegion(named: name, sessionOverrides: overrides.isEmpty ? nil : overrides)
        case .activeSnippet:
            guard let suggestion = appState.activeSavedSnippetSuggestion else {
                appState.statusMessage = L10n.pair(
                    "⚠️ Aktif uygulama için kullanılabilir snippet bulunamadı.",
                    "⚠️ No available snippet was found for the active app."
                )
                return
            }
            _ = coordinator.copySavedSnippet(suggestion.snippet)
        case .snippet(let name):
            _ = coordinator.copySavedSnippet(named: name)
        case .snippetCollection(let name):
            NSApp.activate(ignoringOtherApps: true)
            if !appState.presentSettingsForSavedSnippetCollection(named: name) {
                appState.statusMessage = L10n.usesEnglish
                    ? "⚠️ Saved snippet collection not found: \(name)"
                    : "⚠️ Snippet koleksiyonu bulunamadı: \(name)"
            }
        case .clipboardImage(let overrides):
            coordinator.captureClipboardImage(sessionOverrides: overrides.isEmpty ? nil : overrides)
        case .imageFile(let url, let overrides):
            coordinator.captureImageFile(at: url, sessionOverrides: overrides.isEmpty ? nil : overrides)
        case .pdfFile(let url, let overrides):
            coordinator.capturePDFFile(at: url, sessionOverrides: overrides.isEmpty ? nil : overrides)
        case .searchablePDF(let url, let destinationURL, let overrides):
            coordinator.exportSearchablePDF(
                at: url,
                destinationURL: destinationURL,
                sessionOverrides: overrides.isEmpty ? nil : overrides
            )
        }
    }

}

private enum LaunchAtLoginCommand {
    case status
    case enable
    case disable

    init?(arguments: [String]) {
        guard let flagIndex = arguments.firstIndex(of: "--launch-at-login"),
              arguments.indices.contains(flagIndex + 1)
        else {
            return nil
        }

        switch arguments[flagIndex + 1].lowercased() {
        case "status":
            self = .status
        case "on", "enable", "enabled":
            self = .enable
        case "off", "disable", "disabled":
            self = .disable
        default:
            return nil
        }
    }
}

enum ImportedDocumentRoute: Equatable {
    case image(URL)
    case pdf(URL)
}

final class FinderImportServiceProvider: NSObject {
    private let onImportURLs: @MainActor ([URL]) -> Void

    init(onImportURLs: @escaping @MainActor ([URL]) -> Void) {
        self.onImportURLs = onImportURLs
    }

    @objc func importSelectedFiles(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = Self.readFileURLs(from: pasteboard)
        guard !urls.isEmpty else {
            error.pointee = L10n.pair(
                "Yalnızca görsel veya PDF dosyaları desteklenir.",
                "Only image and PDF files are supported."
            ) as NSString
            return
        }

        Task { @MainActor in
            onImportURLs(urls)
        }
    }

    static func readFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
           !urls.isEmpty {
            return urls
                .filter(\.isFileURL)
                .map { $0.resolvingSymlinksInPath().standardizedFileURL }
        }

        return pasteboard.pasteboardItems?
            .compactMap { item -> URL? in
                guard let rawValue = item.string(forType: .fileURL),
                      let url = URL(string: rawValue),
                      url.isFileURL else {
                    return nil
                }
                return url.resolvingSymlinksInPath().standardizedFileURL
            } ?? []
    }
}

enum ImportedDocumentRouter {
    static func resolve(_ url: URL) -> ImportedDocumentRoute? {
        let standardizedURL = url.standardizedFileURL
        guard standardizedURL.isFileURL else {
            return nil
        }

        let type = UTType(filenameExtension: standardizedURL.pathExtension.lowercased())
        if type?.conforms(to: .pdf) == true {
            return .pdf(standardizedURL)
        }
        if type?.conforms(to: .image) == true {
            return .image(standardizedURL)
        }

        return nil
    }
}

@MainActor
protocol SpeechManaging: AnyObject {
    var speechState: SpeechPlaybackState { get }
    func toggleSpeechPlayback(for text: String)
    func stopSpeechPlayback()
}

@MainActor
final class SpeechService: NSObject {
    private let synthesizer: AVSpeechSynthesizer
    private let onStateChange: (SpeechPlaybackState) -> Void

    private(set) var state: SpeechPlaybackState = .idle {
        didSet {
            guard oldValue != state else { return }
            onStateChange(state)
        }
    }

    private var activeTextSignature: String?

    init(
        synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer(),
        onStateChange: @escaping (SpeechPlaybackState) -> Void = { _ in }
    ) {
        self.synthesizer = synthesizer
        self.onStateChange = onStateChange
        super.init()
        self.synthesizer.delegate = self
    }

    func toggleSpeaking(_ text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SmartActionBuilder.shouldOfferReadAloud(for: normalized) else {
            stopSpeaking()
            return
        }

        if state == .speaking, activeTextSignature == normalized {
            stopSpeaking()
            return
        }

        speak(normalized)
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        activeTextSignature = nil
        state = .idle
    }

    private func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: preparedUtteranceText(from: text))
        utterance.voice = preferredVoice(for: text)
        utterance.rate = 0.5
        utterance.volume = 1

        activeTextSignature = text
        state = .speaking
        synthesizer.speak(utterance)
    }

    private func preferredVoice(for text: String) -> AVSpeechSynthesisVoice? {
        let preferredLanguage = SmartActionBuilder.preferredSpeechLanguage(for: text)
        if let exactVoice = AVSpeechSynthesisVoice(language: preferredLanguage) {
            return exactVoice
        }

        let languagePrefix = String(preferredLanguage.prefix(2))
        return AVSpeechSynthesisVoice.speechVoices().first { voice in
            voice.language.hasPrefix(languagePrefix)
        }
    }

    private func preparedUtteranceText(from text: String) -> String {
        let cleanedLines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleanedLines.isEmpty else {
            return text
        }

        return cleanedLines.joined(separator: ". ")
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.activeTextSignature = nil
            self?.state = .idle
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.activeTextSignature = nil
            self?.state = .idle
        }
    }
}

private struct MenuBarStatusIcon: View {
    var body: some View {
        Image(nsImage: StatusBarIconFactory.image)
            .renderingMode(.template)
            .frame(width: 18, height: 18)
        .accessibilityLabel("ScreenTextGrab")
    }
}

private enum StatusBarIconFactory {
    static let image: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let strokeColor = NSColor.labelColor
        strokeColor.setStroke()
        strokeColor.setFill()

        let lineWidth: CGFloat = 1.7
        let cornerLength: CGFloat = 3.2
        let minX: CGFloat = 3.5
        let maxX: CGFloat = 14.5
        let minY: CGFloat = 3.8
        let maxY: CGFloat = 14.2

        func drawCorner(x: CGFloat, y: CGFloat, horizontalSign: CGFloat, verticalSign: CGFloat) {
            let path = NSBezierPath()
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.move(to: NSPoint(x: x, y: y + verticalSign * cornerLength))
            path.line(to: NSPoint(x: x, y: y))
            path.line(to: NSPoint(x: x + horizontalSign * cornerLength, y: y))
            path.stroke()
        }

        drawCorner(x: minX, y: maxY, horizontalSign: 1, verticalSign: -1)
        drawCorner(x: maxX, y: maxY, horizontalSign: -1, verticalSign: -1)
        drawCorner(x: minX, y: minY, horizontalSign: 1, verticalSign: 1)
        drawCorner(x: maxX, y: minY, horizontalSign: -1, verticalSign: 1)

        NSBezierPath(roundedRect: NSRect(x: 5.0, y: 8.4, width: 8.0, height: 1.6), xRadius: 0.8, yRadius: 0.8).fill()
        NSBezierPath(roundedRect: NSRect(x: 6.1, y: 5.9, width: 5.8, height: 1.5), xRadius: 0.75, yRadius: 0.75).fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }()
}

@MainActor
extension AppDelegate: HotkeyManaging {
    var hotkeyDisplayLabel: String {
        hotkeyService?.hotkeyDisplayLabel ?? HotkeyConfiguration.defaultValue.displayLabel
    }

    var isHotkeyRegistered: Bool {
        hotkeyService?.isRegistered ?? false
    }

    func updateHotkey(to configuration: HotkeyConfiguration) throws {
        guard let hotkeyService else { return }

        do {
            try hotkeyService.updateHotkey(to: configuration)
            appState.updateHotkeyAvailability(isAvailable: hotkeyService.isRegistered, label: hotkeyService.hotkeyDisplayLabel)
            appState.appendDiagnostic(
                category: "hotkey",
                message: "Shortcut updated to \(hotkeyService.hotkeyDisplayLabel)",
                domain: "HotkeyService",
                code: nil,
                severity: .info
            )
        } catch {
            let nsError = error as NSError
            appState.updateHotkeyAvailability(isAvailable: hotkeyService.isRegistered, label: hotkeyService.hotkeyDisplayLabel)
            appState.appendDiagnostic(
                category: "hotkey",
                message: error.localizedDescription,
                domain: nsError.domain,
                code: nsError.code,
                severity: .warning
            )
            throw error
        }
    }

    func resetHotkeyToDefault() throws {
        try updateHotkey(to: .defaultValue)
    }
}

@MainActor
extension AppDelegate: LaunchAtLoginManaging {
    var launchAtLoginState: LaunchAtLoginState {
        launchAtLoginService?.refreshState() ?? .unavailable
    }

    func refreshLaunchAtLoginState() -> LaunchAtLoginState {
        let state = launchAtLoginService?.refreshState() ?? .unavailable
        appState.updateLaunchAtLoginState(state)
        return state
    }

    func setLaunchAtLogin(enabled: Bool) async throws -> LaunchAtLoginState {
        guard let launchAtLoginService else {
            let fallbackState: LaunchAtLoginState = .unavailable
            appState.updateLaunchAtLoginState(fallbackState)
            return fallbackState
        }

        do {
            let state = try await launchAtLoginService.setEnabled(enabled)
            appState.updateLaunchAtLoginState(state)
            appState.appendDiagnostic(
                category: "startup",
                message: enabled ? "Launch at login enabled" : "Launch at login disabled",
                domain: "LaunchAtLoginService",
                code: nil,
                severity: .info
            )
            return state
        } catch {
            let nsError = error as NSError
            let state = launchAtLoginService.refreshState()
            appState.updateLaunchAtLoginState(state)
            appState.appendDiagnostic(
                category: "startup",
                message: error.localizedDescription,
                domain: nsError.domain,
                code: nsError.code,
                severity: .warning
            )
            throw error
        }
    }

    func openLoginItemsSettings() {
        launchAtLoginService?.openSystemSettings()
    }
}

@MainActor
extension AppDelegate: SpeechManaging {
    var speechState: SpeechPlaybackState {
        speechService?.state ?? .idle
    }

    func toggleSpeechPlayback(for text: String) {
        speechService?.toggleSpeaking(text)
        appState.updateSpeechState(speechState)
    }

    func stopSpeechPlayback() {
        speechService?.stopSpeaking()
        appState.updateSpeechState(speechState)
    }
}

@MainActor
extension AppDelegate: AppUpdateManaging {
    func performPrimaryUpdateAction() {
        appUpdateService?.performPrimaryUpdateAction()
    }
}
