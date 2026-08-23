import Combine
import Foundation
import SwiftUI

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
    @Published var urlSchemeAutomationEnabled: Bool
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
        self.urlSchemeAutomationEnabled = persistsUserPreferences
            ? URLSchemeAutomationStore.load(defaults: defaults)
            : false
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

    func setURLSchemeAutomationEnabled(_ isEnabled: Bool) {
        urlSchemeAutomationEnabled = isEnabled
        persistURLSchemeAutomationIfNeeded()
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

    private func persistURLSchemeAutomationIfNeeded() {
        guard persistsUserPreferences else { return }
        URLSchemeAutomationStore.save(urlSchemeAutomationEnabled, defaults: defaults)
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
