import ApplicationServices
import Combine
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
        SavedWorkflowLibrary.availableSnippetTags(from: savedSnippets)
    }

    @discardableResult
    func saveSnippetCollection(named name: String, selectedTag: String?, searchQuery: String) -> SavedSnippetCollection? {
        let result = SavedWorkflowLibrary.upsertSnippetCollection(
            named: name,
            selectedTag: selectedTag,
            searchQuery: searchQuery,
            existing: savedSnippetCollections
        )
        guard let saved = result.saved else {
            return nil
        }
        savedSnippetCollections = result.collections
        persistSavedSnippetCollectionsIfNeeded()
        return saved
    }

    func removeSavedSnippetCollection(_ collection: SavedSnippetCollection) {
        savedSnippetCollections = SavedWorkflowLibrary.removeSnippetCollection(collection, from: savedSnippetCollections)
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
        appProfiles = SavedWorkflowLibrary.upsertAppProfile(
            bundleIdentifier: bundleIdentifier,
            appName: appName,
            captureMode: captureMode,
            outputPreset: captureOutputPreset,
            ocrLanguageSelection: ocrLanguageSelection,
            existing: appProfiles
        )
        persistAppProfilesIfNeeded()
        _ = syncActiveAppProfileIfNeeded()
    }

    func removeAppProfile(_ profile: AppCaptureProfile) {
        appProfiles = SavedWorkflowLibrary.removeAppProfile(profile, from: appProfiles)
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

        let result = SavedWorkflowLibrary.addSavedCaptureRegion(
            from: selection,
            existing: savedCaptureRegions
        )
        savedCaptureRegions = result.regions
        persistSavedCaptureRegionsIfNeeded()
        return result.saved
    }

    @discardableResult
    func refreshSavedCaptureRegion(_ region: SavedCaptureRegion) -> SavedCaptureRegion? {
        guard let selection = lastCaptureSelection else {
            return nil
        }

        let result = SavedWorkflowLibrary.refreshSavedCaptureRegion(
            region,
            using: selection,
            existing: savedCaptureRegions
        )
        guard let saved = result.saved else {
            return nil
        }
        savedCaptureRegions = result.regions
        persistSavedCaptureRegionsIfNeeded()
        return saved
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
        let result = SavedWorkflowLibrary.saveSnippet(from: entry, existing: savedSnippets)
        savedSnippets = result.snippets
        persistSavedSnippetsIfNeeded()
        return result.saved
    }

    func removeSavedSnippet(_ snippet: SavedSnippet) {
        savedSnippets = SavedWorkflowLibrary.removeSnippet(snippet, from: savedSnippets)
        persistSavedSnippetsIfNeeded()
    }

    func updateSavedSnippetTags(_ tags: [String], for snippet: SavedSnippet) {
        savedSnippets = SavedWorkflowLibrary.updateSnippetTags(tags, for: snippet, existing: savedSnippets)
        persistSavedSnippetsIfNeeded()
    }

    @discardableResult
    func noteSavedSnippetUsed(_ snippet: SavedSnippet, usedAt: Date = Date()) -> SavedSnippet? {
        let result = SavedWorkflowLibrary.noteSnippetUsed(snippet, usedAt: usedAt, existing: savedSnippets)
        savedSnippets = result.snippets
        persistSavedSnippetsIfNeeded()
        return result.updated
    }

    func suggestedTags(for snippet: SavedSnippet) -> [String] {
        SavedWorkflowLibrary.suggestedTags(for: snippet)
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

    private func persistHistoryExportFormatIfNeeded() {
        guard persistsUserPreferences else { return }
        ClipboardHistoryExportFormatStore.save(historyExportFormat, defaults: defaults)
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
                tags: SavedWorkflowLibrary.defaultSnippetTags(
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

enum ScreenshotLaunchMode {
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
final class PreviewLaunchAtLoginManager: LaunchAtLoginManaging {
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
final class PreviewPermissionProvider: ScreenPermissionProviding {
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
    var previewWindowController: NSWindowController?
    var previewLaunchAtLoginManager: PreviewLaunchAtLoginManager?
    var previewPermissionProvider: PreviewPermissionProvider?
    private var finderImportServiceProvider: FinderImportServiceProvider?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var workspaceActivationObserver: NSObjectProtocol?
    private var captureStateObserver: AnyCancellable?
    private var automationCommandQueue = AutomationCommandQueue()
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
            automationCommandQueue.enqueue([automationCommand])
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

        captureStateObserver = appState.$captureState
            .removeDuplicates()
            .sink { [weak self] state in
                guard let self else { return }
                self.automationCommandQueue.captureStateDidChange(state)
                guard !state.isBusy else { return }
                Task { @MainActor [weak self] in
                    self?.flushPendingAutomationCommands()
                }
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
        captureStateObserver?.cancel()
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
        switch AutomationCommand.resolveIncomingURLs(urls) {
        case .unsupported:
            if !urls.isEmpty {
                appState.statusMessage = L10n.pair(
                    "⚠️ Yalnızca görsel veya PDF dosyaları desteklenir.",
                    "⚠️ Only image and PDF files are supported."
                )
            }
        case .commands(let commands):
            automationCommandQueue.enqueue(commands)
            let importedFileCount = commands.filter(\.isImportedFileCommand).count
            if importedFileCount > 1 {
                appState.statusMessage = L10n.format(
                    "📥 %d dosya sıraya alındı. İçe aktarma işlemi otomatik sırayla devam edecek.",
                    "📥 %d files were queued. Imports will continue automatically one by one.",
                    importedFileCount
                )
            }
            flushPendingAutomationCommands()
        }
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
        guard let coordinator = captureCoordinator else {
            return
        }

        while let command = automationCommandQueue.nextCommand(captureState: appState.captureState) {
            dispatchAutomationCommand(command, coordinator: coordinator)
            let startedBusyWork = appState.captureState.isBusy
            automationCommandQueue.markDispatchResult(for: command, startedBusyWork: startedBusyWork)

            if startedBusyWork {
                return
            }
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
