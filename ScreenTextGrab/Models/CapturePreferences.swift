import CoreGraphics
import Foundation

enum WatchCopyBehavior: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case wholeResult
    case newLinesOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wholeResult:
            return L10n.pair("Tam Sonuç", "Full Result")
        case .newLinesOnly:
            return L10n.pair("Sadece Yeni Satırlar", "New Lines Only")
        }
    }

    var detail: String {
        switch self {
        case .wholeResult:
            return L10n.pair("İzlenen alan değiştiğinde tüm metni yeniden kopyalar.", "Copies the full text again whenever the watched region changes.")
        case .newLinesOnly:
            return L10n.pair("Önceki sonuca göre sadece yeni gelen satırları kopyalar.", "Copies only newly added lines compared with the previous result.")
        }
    }
}

struct WatchConfiguration: Codable, Equatable, Sendable {
    var copyBehavior: WatchCopyBehavior
    var regexFilter: String

    static let defaultValue = WatchConfiguration(copyBehavior: .wholeResult, regexFilter: "")

    var summary: String {
        if regexFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return copyBehavior.detail
        }

        return "\(copyBehavior.title) • Regex: \(regexFilter)"
    }
}

enum WatchConfigurationStore {
    static let key = "screenTextGrab.watchConfiguration"

    static func load(defaults: UserDefaults = .standard) -> WatchConfiguration {
        guard let data = defaults.data(forKey: key),
              let configuration = try? JSONDecoder().decode(WatchConfiguration.self, from: data) else {
            return .defaultValue
        }

        return configuration
    }

    static func save(_ configuration: WatchConfiguration, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}

struct AppCaptureProfile: Identifiable, Equatable, Codable, Sendable {
    let bundleIdentifier: String
    let appName: String
    let captureMode: CaptureMode
    let outputPreset: CaptureOutputPreset
    let ocrLanguageSelection: OCRLanguageSelection

    var id: String { bundleIdentifier }

    var summary: String {
        "\(captureMode.title) • \(outputPreset.title) • \(ocrLanguageSelection.summary)"
    }
}

enum AppCaptureProfileStore {
    static let key = "screenTextGrab.appCaptureProfiles"
    static let recommendedProfiles: [AppCaptureProfile] = [
        AppCaptureProfile(
            bundleIdentifier: "com.microsoft.Excel",
            appName: "Microsoft Excel",
            captureMode: .table,
            outputPreset: .office,
            ocrLanguageSelection: .defaultValue
        ),
        AppCaptureProfile(
            bundleIdentifier: "com.apple.iWork.Numbers",
            appName: "Numbers",
            captureMode: .table,
            outputPreset: .office,
            ocrLanguageSelection: .defaultValue
        ),
        AppCaptureProfile(
            bundleIdentifier: "com.microsoft.Word",
            appName: "Microsoft Word",
            captureMode: .standard,
            outputPreset: .office,
            ocrLanguageSelection: .defaultValue
        ),
        AppCaptureProfile(
            bundleIdentifier: "com.apple.iWork.Pages",
            appName: "Pages",
            captureMode: .standard,
            outputPreset: .office,
            ocrLanguageSelection: .defaultValue
        )
    ]

    static func load(defaults: UserDefaults = .standard) -> [AppCaptureProfile] {
        guard defaults.object(forKey: key) != nil else {
            return sortedProfiles(recommendedProfiles)
        }

        guard let data = defaults.data(forKey: key),
              let profiles = try? JSONDecoder().decode([AppCaptureProfile].self, from: data) else {
            return sortedProfiles(recommendedProfiles)
        }

        return sortedProfiles(profiles)
    }

    static func save(_ profiles: [AppCaptureProfile], defaults: UserDefaults = .standard) {
        let sorted = sortedProfiles(profiles)
        guard let data = try? JSONEncoder().encode(sorted) else {
            return
        }

        defaults.set(data, forKey: key)
    }

    private static func sortedProfiles(_ profiles: [AppCaptureProfile]) -> [AppCaptureProfile] {
        profiles.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }
}

struct SavedCaptureRegion: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var name: String
    var screenRect: CGRect
    var preferredDisplayID: CGDirectDisplayID?
    var source: ClipboardHistoryEntry.SourceContext?
    var sessionConfiguration: CaptureSessionConfiguration
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        screenRect: CGRect,
        preferredDisplayID: CGDirectDisplayID?,
        source: ClipboardHistoryEntry.SourceContext?,
        sessionConfiguration: CaptureSessionConfiguration,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.screenRect = screenRect.standardized
        self.preferredDisplayID = preferredDisplayID
        self.source = source
        self.sessionConfiguration = sessionConfiguration
        self.updatedAt = updatedAt
    }

    var summary: String {
        let size = "\(Int(screenRect.width.rounded()))×\(Int(screenRect.height.rounded()))"
        let sourceName = source?.displayName ?? L10n.pair("Genel", "General")
        return "\(sourceName) • \(sessionConfiguration.captureMode.title) • \(sessionConfiguration.outputPreset.title) • \(size)"
    }

    var recentSelection: RecentCaptureSelection {
        RecentCaptureSelection(
            screenRect: screenRect,
            preferredDisplayID: preferredDisplayID,
            source: source,
            sessionConfiguration: sessionConfiguration
        )
    }
}

enum SavedCaptureRegionStore {
    static let key = "screenTextGrab.savedCaptureRegions"
    static let maximumEntries = 12

    static func load(defaults: UserDefaults = .standard) -> [SavedCaptureRegion] {
        guard let data = defaults.data(forKey: key),
              let regions = try? JSONDecoder().decode([SavedCaptureRegion].self, from: data) else {
            return []
        }

        return Array(sortedRegions(regions).prefix(maximumEntries))
    }

    static func save(_ regions: [SavedCaptureRegion], defaults: UserDefaults = .standard) {
        let trimmed = Array(sortedRegions(regions).prefix(maximumEntries))
        guard let data = try? JSONEncoder().encode(trimmed) else {
            return
        }

        defaults.set(data, forKey: key)
    }

    private static func sortedRegions(_ regions: [SavedCaptureRegion]) -> [SavedCaptureRegion] {
        regions.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

enum URLSchemeAutomationStore {
    static let key = "screenTextGrab.urlSchemeAutomationEnabled"

    static func load(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return false
        }

        return defaults.bool(forKey: key)
    }

    static func save(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: key)
    }
}

enum SavedCaptureRegionQuickStartStore {
    static let key = "screenTextGrab.savedCaptureRegions.quickStartEnabled"

    static func load(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return true
        }

        return defaults.bool(forKey: key)
    }

    static func save(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: key)
    }
}

enum SavedSnippetCollectionAutoSyncStore {
    static let key = "screenTextGrab.savedSnippetCollections.autoSyncEnabled"

    static func load(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return true
        }

        return defaults.bool(forKey: key)
    }

    static func save(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: key)
    }
}

enum AppProfilePanelAutoSyncStore {
    static let key = "screenTextGrab.appProfiles.panelAutoSyncEnabled"

    static func load(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return false
        }

        return defaults.bool(forKey: key)
    }

    static func save(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: key)
    }
}

enum InterfaceLanguage: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case system
    case turkish
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return L10n.pair("Sistem", "System")
        case .turkish:
            return "Türkçe"
        case .english:
            return "English"
        }
    }

    var detail: String {
        switch self {
        case .system:
            return L10n.pair("Arayüz dili macOS tercihini takip eder.", "The interface follows your macOS language.")
        case .turkish:
            return L10n.pair("Arayüz her zaman Türkçe görünür.", "The interface always appears in Turkish.")
        case .english:
            return L10n.pair("Arayüz her zaman English görünür.", "The interface always appears in English.")
        }
    }

    var resolvedIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .turkish:
            return "tr"
        case .english:
            return "en"
        }
    }
}

enum InterfaceLanguageStore {
    static let key = "screenTextGrab.interfaceLanguage"

    static func load(defaults: UserDefaults = .standard) -> InterfaceLanguage {
        guard let rawValue = defaults.string(forKey: key),
              let language = InterfaceLanguage(rawValue: rawValue) else {
            return .system
        }

        return language
    }

    static func save(_ language: InterfaceLanguage, defaults: UserDefaults = .standard) {
        defaults.set(language.rawValue, forKey: key)
    }
}

struct SavedSnippet: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var name: String
    var text: String
    var rawText: String?
    var captureMode: CaptureMode
    var outputPreset: CaptureOutputPreset
    var contentKind: ClipboardHistoryEntry.ContentKind
    var ocrConfidence: Float?
    var source: ClipboardHistoryEntry.SourceContext?
    var tags: [String]
    var updatedAt: Date
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        text: String,
        rawText: String? = nil,
        captureMode: CaptureMode,
        outputPreset: CaptureOutputPreset,
        contentKind: ClipboardHistoryEntry.ContentKind = .text,
        ocrConfidence: Float? = nil,
        source: ClipboardHistoryEntry.SourceContext? = nil,
        tags: [String] = [],
        updatedAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.text = text
        self.rawText = rawText
        self.captureMode = captureMode
        self.outputPreset = outputPreset
        self.contentKind = contentKind
        self.ocrConfidence = ocrConfidence
        self.source = source
        self.tags = Self.normalizedTags(tags)
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
    }

    init(entry: ClipboardHistoryEntry, name: String, tags: [String] = [], updatedAt: Date = Date()) {
        self.init(
            name: name,
            text: entry.text,
            rawText: entry.rawText,
            captureMode: entry.captureMode,
            outputPreset: entry.outputPreset,
            contentKind: entry.contentKind,
            ocrConfidence: entry.ocrConfidence,
            source: entry.source,
            tags: tags,
            updatedAt: updatedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case text
        case rawText
        case captureMode
        case outputPreset
        case contentKind
        case ocrConfidence
        case source
        case tags
        case updatedAt
        case lastUsedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let name = try container.decode(String.self, forKey: .name)
        let text = try container.decode(String.self, forKey: .text)
        let rawText = try container.decodeIfPresent(String.self, forKey: .rawText)
        let captureMode = try container.decode(CaptureMode.self, forKey: .captureMode)
        let outputPreset = try container.decode(CaptureOutputPreset.self, forKey: .outputPreset)
        let contentKind = try container.decodeIfPresent(ClipboardHistoryEntry.ContentKind.self, forKey: .contentKind) ?? .text
        let ocrConfidence = try container.decodeIfPresent(Float.self, forKey: .ocrConfidence)
        let source = try container.decodeIfPresent(ClipboardHistoryEntry.SourceContext.self, forKey: .source)
        let tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        let updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        let lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)

        self.init(
            id: id,
            name: name,
            text: text,
            rawText: rawText,
            captureMode: captureMode,
            outputPreset: outputPreset,
            contentKind: contentKind,
            ocrConfidence: ocrConfidence,
            source: source,
            tags: tags,
            updatedAt: updatedAt,
            lastUsedAt: lastUsedAt
        )
    }

    var previewText: String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var effectiveRawText: String {
        let candidate = rawText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return candidate.isEmpty ? text : candidate
    }

    var confidenceIndicator: ClipboardHistoryEntry.ConfidenceIndicator? {
        guard let ocrConfidence else {
            return nil
        }

        return ClipboardHistoryEntry.confidenceIndicator(for: ocrConfidence, contentKind: contentKind)
    }

    var summary: String {
        let sourceName = source?.displayName ?? L10n.pair("Genel", "General")
        return "\(sourceName) • \(captureMode.title) • \(outputPreset.title)"
    }

    private static func normalizedTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()

        return tags.compactMap { rawTag in
            let trimmed = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }

            let key = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !seen.contains(key) else {
                return nil
            }

            seen.insert(key)
            return trimmed
        }
    }
}

enum SavedSnippetStore {
    static let key = "screenTextGrab.savedSnippets"
    static let maximumEntries = 16

    static func load(defaults: UserDefaults = .standard) -> [SavedSnippet] {
        guard let data = defaults.data(forKey: key),
              let snippets = try? JSONDecoder().decode([SavedSnippet].self, from: data) else {
            return []
        }

        return Array(sortedSnippets(snippets).prefix(maximumEntries))
    }

    static func save(_ snippets: [SavedSnippet], defaults: UserDefaults = .standard) {
        let trimmed = Array(sortedSnippets(snippets).prefix(maximumEntries))
        guard let data = try? JSONEncoder().encode(trimmed) else {
            return
        }

        defaults.set(data, forKey: key)
    }

    private static func sortedSnippets(_ snippets: [SavedSnippet]) -> [SavedSnippet] {
        snippets.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

struct SavedSnippetCollection: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var name: String
    var selectedTag: String?
    var searchQuery: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        selectedTag: String? = nil,
        searchQuery: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTag = selectedTag?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.selectedTag = (trimmedTag?.isEmpty == false) ? trimmedTag : nil
        self.searchQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        self.updatedAt = updatedAt
    }

    var summary: String {
        switch (selectedTag, searchQuery.isEmpty) {
        case let (tag?, false):
            return "#\(tag) • \"\(searchQuery)\""
        case let (tag?, true):
            return "#\(tag)"
        case (nil, false):
            return "\"\(searchQuery)\""
        case (nil, true):
            return L10n.pair("Tum snippet'lar", "All snippets")
        }
    }
}

enum SavedSnippetCollectionStore {
    static let key = "screenTextGrab.savedSnippetCollections"
    static let maximumEntries = 12

    static func load(defaults: UserDefaults = .standard) -> [SavedSnippetCollection] {
        guard let data = defaults.data(forKey: key),
              let collections = try? JSONDecoder().decode([SavedSnippetCollection].self, from: data) else {
            return []
        }

        return Array(sortedCollections(collections).prefix(maximumEntries))
    }

    static func save(_ collections: [SavedSnippetCollection], defaults: UserDefaults = .standard) {
        let trimmed = Array(sortedCollections(collections).prefix(maximumEntries))
        guard let data = try? JSONEncoder().encode(trimmed) else {
            return
        }

        defaults.set(data, forKey: key)
    }

    private static func sortedCollections(_ collections: [SavedSnippetCollection]) -> [SavedSnippetCollection] {
        collections.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

struct CaptureSessionConfiguration: Equatable, Codable, Sendable {
    let captureMode: CaptureMode
    let outputPreset: CaptureOutputPreset
    let ocrLanguageSelection: OCRLanguageSelection
    let profileName: String?
}
