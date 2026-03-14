import Foundation
import CoreGraphics

enum ScreenPermissionState: Equatable, Sendable {
    case unknown
    case granted
    case denied
    case requestInProgress
    case requiresRestart

    var uiMessage: String {
        switch self {
        case .unknown:
            return "İzin durumu bilinmiyor"
        case .granted:
            return "Ekran kaydı izni hazır"
        case .denied:
            return "Ekran kaydı izni verilmemiş"
        case .requestInProgress:
            return "İzin isteği bekleniyor"
        case .requiresRestart:
            return "İzin verildi, uygulamayı yeniden başlatın"
        }
    }
}

enum CaptureState: Equatable, Sendable {
    case idle
    case preparing
    case selecting
    case capturing
    case recognizing
    case copying
    case completed
    case completedEmpty
    case failed
    case cancelled

    var isBusy: Bool {
        switch self {
        case .preparing, .selecting, .capturing, .recognizing, .copying:
            return true
        case .idle, .completed, .completedEmpty, .failed, .cancelled:
            return false
        }
    }
}

enum WatchState: Equatable, Sendable {
    case inactive
    case selecting
    case active

    var title: String {
        switch self {
        case .inactive:
            return "Kapalı"
        case .selecting:
            return "Seçiliyor"
        case .active:
            return "Aktif"
        }
    }

    var detail: String {
        switch self {
        case .inactive:
            return "Belirli bir alanı izler, yeni metin gelince otomatik kopyalar."
        case .selecting:
            return "İzlenecek alanı seçmen bekleniyor."
        case .active:
            return "Seçilen alan düzenli taranıyor; değişiklik olursa pano güncellenir."
        }
    }

    var isActive: Bool {
        self == .active
    }
}

enum SpeechPlaybackState: Equatable, Sendable {
    case idle
    case speaking

    var title: String {
        switch self {
        case .idle:
            return "Hazır"
        case .speaking:
            return "Okuyor"
        }
    }

    var detail: String {
        switch self {
        case .idle:
            return "Sesli okuma hazır."
        case .speaking:
            return "Son yakalanan metin sesli okunuyor."
        }
    }
}

enum CaptureMode: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case standard
    case subtitle
    case code
    case table

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "Standart"
        case .subtitle:
            return "Altyazı"
        case .code:
            return "Kod"
        case .table:
            return "Tablo"
        }
    }

    var shortTitle: String {
        switch self {
        case .standard:
            return "Standart"
        case .subtitle:
            return "Altyazı"
        case .code:
            return "Kod"
        case .table:
            return "Tablo"
        }
    }

    var detail: String {
        switch self {
        case .standard:
            return "Genel ekran metni, pencere içeriği ve belgeler için dengeli OCR."
        case .subtitle:
            return "Video, yayın ve canlı altyazılar için alt banda ve tekrar denemelere öncelik verir."
        case .code:
            return "Kod blokları, terminal çıktıları ve monospaced metin için boşlukları daha korumacı işler."
        case .table:
            return "Tablo, fiyat listesi ve çok sütunlu içerikleri sekmeyle hizalanmış çıktıya dönüştürür."
        }
    }

    var readyDescription: String {
        switch self {
        case .standard:
            return "Seçim modunu aç ve algılanan metni panoya kopyala."
        case .subtitle:
            return "Alt yazı bandını seç; uygulama alt bölgeyi ve tekrar denemeleri önceliklendirir."
        case .code:
            return "Kod veya terminal alanını seç; satır ve girinti yapısı daha dikkatli korunur."
        case .table:
            return "Tablo alanını seç; sütunları koruyarak sekme ayrılmış çıktı üretir."
        }
    }

    var selectionPrompt: String {
        switch self {
        case .standard:
            return "Alan seçin (ESC = İptal)"
        case .subtitle:
            return "Altyazı bandını seçin (ESC = İptal)"
        case .code:
            return "Kod alanını seçin (ESC = İptal)"
        case .table:
            return "Tablo alanını seçin (ESC = İptal)"
        }
    }

    var recognitionProgressTitle: String {
        switch self {
        case .standard:
            return "Metin tanınıyor"
        case .subtitle:
            return "Altyazı tanınıyor"
        case .code:
            return "Kod tanınıyor"
        case .table:
            return "Tablo tanınıyor"
        }
    }

    var retryProgressTitle: String {
        switch self {
        case .standard:
            return "Video yazısı bekleniyor"
        case .subtitle:
            return "Altyazı yenileniyor"
        case .code:
            return "Kod yeniden değerlendiriliyor"
        case .table:
            return "Tablo yeniden değerlendiriliyor"
        }
    }

    var emptyResultMessage: String {
        switch self {
        case .standard:
            return "⚠️ Metin bulunamadı"
        case .subtitle:
            return "⚠️ Altyazı bulunamadı"
        case .code:
            return "⚠️ Kod metni bulunamadı"
        case .table:
            return "⚠️ Tablo metni bulunamadı"
        }
    }

    var isSubtitleFocused: Bool {
        self == .subtitle
    }

    var isCodeFocused: Bool {
        self == .code
    }

    var isTableFocused: Bool {
        self == .table
    }
}

enum CaptureOutputPreset: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case smart
    case plainText
    case cleaned
    case office
    case markdown
    case json

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart:
            return "Akıllı"
        case .plainText:
            return "Düz Metin"
        case .cleaned:
            return "Temizlenmiş"
        case .office:
            return "Office"
        case .markdown:
            return "Markdown"
        case .json:
            return "JSON"
        }
    }

    var shortTitle: String {
        switch self {
        case .smart:
            return "Akıllı"
        case .plainText:
            return "Düz"
        case .cleaned:
            return "Temiz"
        case .office:
            return "Office"
        case .markdown:
            return "MD"
        case .json:
            return "JSON"
        }
    }

    var summary: String {
        switch self {
        case .smart:
            return "Moda göre en uygun sonuç"
        case .plainText:
            return "Yalın ve doğrudan metin"
        case .cleaned:
            return "OCR gürültüsünü azaltır"
        case .office:
            return "Excel ve Word ile uyumlu"
        case .markdown:
            return "Kod ve tablo için hazır"
        case .json:
            return "Otomasyon için yapılandırılmış"
        }
    }

    var detail: String {
        switch self {
        case .smart:
            return "Moda uygun doğal çıktıyı panoya kopyalar."
        case .plainText:
            return "Biçimi azaltılmış, doğrudan yapıştırılabilir düz metin üretir."
        case .cleaned:
            return "Gürültüyü temizler; özellikle altyazı ve dağınık OCR sonuçlarında faydalıdır."
        case .office:
            return "Excel ve Word için zengin yapıştırma verisi üretir."
        case .markdown:
            return "Kod ve tablo gibi içerikleri Markdown uyumlu biçimde hazırlar."
        case .json:
            return "Otomasyon ve entegrasyonlar için yapılandırılmış çıktı üretir."
        }
    }
}

enum ClipboardWriteResult: Equatable, Sendable {
    case success
    case failedWrite
    case failedReadback
}

enum CaptureStrategy: String, Equatable, Sendable {
    case screenshotKitGlobalRect        // SCScreenshotManager global rect — macOS 15.2+
    case screenshotKitDisplayFilter     // SCScreenshotManager per-display filter — macOS 14+
    case systemScreencaptureCLI         // /usr/sbin/screencapture CLI subprocess
    case displayCropTopLeft             // CGDisplayCreateImage + crop — legacy fallback
    case clipboardImage                 // NSPasteboard image OCR
    case importedImageFile              // User-selected image file OCR
    case importedPDFPage                // User-selected PDF page OCR
}

struct CaptureCandidate: @unchecked Sendable {
    let strategy: CaptureStrategy
    let image: CGImage
    var debugInfo: String
}

enum CapturePipelineError: Error, LocalizedError, Equatable, Sendable {
    case permissionDenied(detail: String?)
    case invalidSourceRect
    case displayNotFound
    case captureFailed(domain: String, code: Int, description: String)
    case noTextFound
    case ocrFailed(description: String)
    case clipboardFailed(result: ClipboardWriteResult)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "🔐 Ekran kaydı izni gerekli."
        case .invalidSourceRect:
            return "❌ Seçilen alan geçersiz."
        case .displayNotFound:
            return "❌ Seçilen alan için ekran bulunamadı."
        case .noTextFound:
            return "⚠️ Seçilen alanda metin bulunamadı."
        case .captureFailed(_, _, let description):
            return "❌ Ekran yakalama hatası: \(description)"
        case .ocrFailed(let description):
            return "❌ OCR hatası: \(description)"
        case .clipboardFailed(let result):
            switch result {
            case .failedWrite:
                return "⚠️ Metin alındı ancak panoya yazılamadı."
            case .failedReadback:
                return "⚠️ Pano doğrulaması başarısız oldu."
            case .success:
                return ""
            }
        }
    }
}

enum DiagnosticSeverity: String, Equatable, Sendable {
    case info
    case warning
    case error
}

struct DiagnosticEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let category: String
    let message: String
    let domain: String?
    let code: Int?
    let severity: DiagnosticSeverity

    var summary: String {
        if let domain, let code {
            return "[\(category)] \(message) (\(domain):\(code))"
        }
        if let domain {
            return "[\(category)] \(message) (\(domain))"
        }
        return "[\(category)] \(message)"
    }
}

struct PermissionDiagnosticSnapshot: Equatable, Sendable {
    let timestamp: Date
    let currentState: ScreenPermissionState
    let preflightGranted: Bool
    let probeState: ScreenPermissionState
    let needsRestartAfterGrant: Bool
    let lastConfirmedGrantAt: Date?
    let lastProbeAt: Date?
    let bundleIdentifier: String
    let appPath: String
    let marketingVersion: String
    let buildVersion: String

    var versionLabel: String {
        "\(marketingVersion) (\(buildVersion))"
    }

    var preflightLabel: String {
        preflightGranted ? "Açık" : "Kapalı"
    }

    var reportText: String {
        let formatter = ISO8601DateFormatter()
        var lines = [
            "ScreenTextGrab İzin Tanısı",
            "Oluşturulma: \(formatter.string(from: timestamp))",
            "Sürüm: \(versionLabel)",
            "Bundle ID: \(bundleIdentifier)",
            "Uygulama Yolu: \(appPath)",
            "Durum: \(currentState.uiMessage)",
            "Preflight: \(preflightLabel)",
            "Probe: \(probeState.uiMessage)",
            "Yeniden Açma Gerekli: \(needsRestartAfterGrant ? "Evet" : "Hayır")"
        ]

        if let lastProbeAt {
            lines.append("Son Probe: \(formatter.string(from: lastProbeAt))")
        }

        if let lastConfirmedGrantAt {
            lines.append("Son Başarılı Grant Kanıtı: \(formatter.string(from: lastConfirmedGrantAt))")
        }

        return lines.joined(separator: "\n")
    }
}

struct ScreenDescriptor: Equatable, Sendable {
    let displayID: CGDirectDisplayID
    let frame: CGRect
    let backingScaleFactor: CGFloat
}

struct ScreenEnvironmentSnapshot: Equatable, Sendable {
    let displays: [ScreenDescriptor]

    var desktopBounds: CGRect {
        displays.reduce(CGRect.null) { partial, display in
            partial.union(display.frame)
        }
    }

    func bestDisplay(for rect: CGRect, preferredDisplayID: CGDirectDisplayID?) -> ScreenDescriptor? {
        if let preferredDisplayID,
           let preferred = displays.first(where: { $0.displayID == preferredDisplayID }) {
            return preferred
        }

        return displays
            .map { display in
                (display: display, area: rect.intersection(display.frame).area)
            }
            .filter { $0.area > 0 }
            .max { $0.area < $1.area }?
            .display
    }
}

struct CaptureRequest: Sendable {
    let selectionRect: CGRect
    let preferredDisplay: ScreenDescriptor?
    let environment: ScreenEnvironmentSnapshot
}

enum OCRLanguagePreference: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case turkish = "tr-TR"
    case english = "en-US"
    case german = "de-DE"
    case french = "fr-FR"
    case spanish = "es-ES"
    case italian = "it-IT"
    case portuguese = "pt-BR"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .turkish:
            return "Türkçe"
        case .english:
            return "English"
        case .german:
            return "Deutsch"
        case .french:
            return "Français"
        case .spanish:
            return "Español"
        case .italian:
            return "Italiano"
        case .portuguese:
            return "Português"
        }
    }

    var shortTitle: String {
        switch self {
        case .turkish:
            return "TR"
        case .english:
            return "EN"
        case .german:
            return "DE"
        case .french:
            return "FR"
        case .spanish:
            return "ES"
        case .italian:
            return "IT"
        case .portuguese:
            return "PT"
        }
    }
}

struct OCRLanguageSelection: Codable, Equatable, Sendable {
    var automaticDetection: Bool
    var languages: [OCRLanguagePreference]

    static let fallbackLanguages: [OCRLanguagePreference] = [.turkish, .english]
    static let defaultValue = OCRLanguageSelection(
        automaticDetection: true,
        languages: fallbackLanguages
    )

    init(automaticDetection: Bool = false, languages: [OCRLanguagePreference]) {
        let ordered = OCRLanguagePreference.allCases.filter { languages.contains($0) }
        self.automaticDetection = automaticDetection
        self.languages = ordered.isEmpty ? Self.fallbackLanguages : ordered
    }

    var recognitionLanguages: [String] {
        if automaticDetection {
            return []
        }
        return languages.map(\.rawValue)
    }

    var summary: String {
        if automaticDetection {
            return "Otomatik algılama"
        }

        return languages.map(\.title).joined(separator: ", ")
    }

    func contains(_ language: OCRLanguagePreference) -> Bool {
        languages.contains(language)
    }

    func updating(_ language: OCRLanguagePreference, enabled: Bool) -> OCRLanguageSelection? {
        if enabled {
            if contains(language) {
                return self
            }
            return OCRLanguageSelection(
                automaticDetection: automaticDetection,
                languages: languages + [language]
            )
        }

        let remaining = languages.filter { $0 != language }
        guard !remaining.isEmpty else {
            return nil
        }
        return OCRLanguageSelection(
            automaticDetection: automaticDetection,
            languages: remaining
        )
    }

    func settingAutomaticDetection(_ enabled: Bool) -> OCRLanguageSelection {
        OCRLanguageSelection(
            automaticDetection: enabled,
            languages: languages
        )
    }

    private enum CodingKeys: String, CodingKey {
        case automaticDetection
        case languages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let automaticDetection = try container.decodeIfPresent(Bool.self, forKey: .automaticDetection) ?? false
        let languages = try container.decodeIfPresent([OCRLanguagePreference].self, forKey: .languages) ?? Self.fallbackLanguages
        self.init(
            automaticDetection: automaticDetection,
            languages: languages
        )
    }
}

enum OCRLanguageSelectionStore {
    static let key = "screenTextGrab.ocrLanguageSelection"

    static func load(defaults: UserDefaults = .standard) -> OCRLanguageSelection {
        guard let data = defaults.data(forKey: key),
              let selection = try? JSONDecoder().decode(OCRLanguageSelection.self, from: data) else {
            return .defaultValue
        }
        return selection
    }

    static func save(_ selection: OCRLanguageSelection, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(selection) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}

enum CaptureModeStore {
    static let key = "screenTextGrab.captureMode"

    static func load(defaults: UserDefaults = .standard) -> CaptureMode {
        guard let rawValue = defaults.string(forKey: key),
              let mode = CaptureMode(rawValue: rawValue) else {
            return .standard
        }
        return mode
    }

    static func save(_ mode: CaptureMode, defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: key)
    }
}

enum CaptureOutputPresetStore {
    static let key = "screenTextGrab.captureOutputPreset"

    static func load(defaults: UserDefaults = .standard) -> CaptureOutputPreset {
        guard let rawValue = defaults.string(forKey: key),
              let preset = CaptureOutputPreset(rawValue: rawValue) else {
            return .smart
        }

        return preset
    }

    static func save(_ preset: CaptureOutputPreset, defaults: UserDefaults = .standard) {
        defaults.set(preset.rawValue, forKey: key)
    }
}

struct ClipboardHistoryEntry: Identifiable, Equatable, Sendable, Codable {
    enum ContentKind: String, CaseIterable, Identifiable, Codable, Sendable {
        case text
        case barcode

        var id: String { rawValue }

        var title: String {
            switch self {
            case .text:
                return "Metin"
            case .barcode:
                return "Barkod"
            }
        }
    }

    enum ConfidenceIndicator: String, Codable, Sendable {
        case low
        case medium
        case high

        var title: String {
            switch self {
            case .low:
                return "Düşük Güven"
            case .medium:
                return "Kontrol Et"
            case .high:
                return "Yüksek Güven"
            }
        }

        var shortTitle: String {
            switch self {
            case .low:
                return "Düşük"
            case .medium:
                return "Orta"
            case .high:
                return "Yüksek"
            }
        }

        var detail: String {
            switch self {
            case .low:
                return "Son OCR çıktısı zayıf güvenle üretildi. Yapıştırmadan önce gözden geçirmek iyi olur."
            case .medium:
                return "Son OCR çıktısı kullanılabilir görünüyor ama kısa bir göz kontrolü faydalı olabilir."
            case .high:
                return "Son OCR çıktısı yüksek güvenle üretildi."
            }
        }
    }

    struct SourceContext: Equatable, Sendable, Codable {
        let appName: String?
        let bundleIdentifier: String?
        let windowTitle: String?

        init(appName: String?, bundleIdentifier: String?, windowTitle: String? = nil) {
            self.appName = Self.normalizedValue(appName)
            self.bundleIdentifier = Self.normalizedValue(bundleIdentifier)
            self.windowTitle = Self.normalizedValue(windowTitle)
        }

        var displayName: String {
            if let appName, !appName.isEmpty {
                return appName
            }

            if let bundleIdentifier, !bundleIdentifier.isEmpty {
                return bundleIdentifier
            }

            return "Bilinmeyen Kaynak"
        }

        var displayContextName: String {
            guard let windowTitle else {
                return displayName
            }

            return "\(displayName) • \(windowTitle)"
        }

        func matchesWindowTitle(_ candidate: String?) -> Bool {
            guard let normalizedSelf = Self.normalizedComparisonValue(windowTitle),
                  let normalizedCandidate = Self.normalizedComparisonValue(candidate) else {
                return false
            }

            return normalizedSelf == normalizedCandidate ||
                normalizedSelf.contains(normalizedCandidate) ||
                normalizedCandidate.contains(normalizedSelf)
        }

        private static func normalizedValue(_ value: String?) -> String? {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else {
                return nil
            }

            return trimmed
        }

        private static func normalizedComparisonValue(_ value: String?) -> String? {
            normalizedValue(value)?
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }
    }

    let id: UUID
    let text: String
    let date: Date
    let captureMode: CaptureMode
    let outputPreset: CaptureOutputPreset
    let contentKind: ContentKind
    let rawText: String?
    let ocrConfidence: Float?
    let source: SourceContext?
    let isPinned: Bool

    init(
        id: UUID = UUID(),
        text: String,
        date: Date,
        captureMode: CaptureMode = .standard,
        outputPreset: CaptureOutputPreset = .smart,
        contentKind: ContentKind = .text,
        rawText: String? = nil,
        ocrConfidence: Float? = nil,
        source: SourceContext? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.text = text
        self.date = date
        self.captureMode = captureMode
        self.outputPreset = outputPreset
        self.contentKind = contentKind
        self.rawText = rawText
        self.ocrConfidence = ocrConfidence
        self.source = source
        self.isPinned = isPinned
    }

    var effectiveRawText: String {
        let candidate = rawText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return candidate.isEmpty ? text : candidate
    }

    var preferredTableSourceText: String {
        let candidates = [effectiveRawText, text]
            .map(Self.normalizedReviewSource(_:))
            .filter { !$0.isEmpty }

        guard !candidates.isEmpty else {
            return ""
        }

        if let candidate = candidates.first(where: Self.containsExplicitTableSeparators(_:)) {
            return candidate
        }

        if let candidate = candidates.first(where: Self.looksLikeMarkdownTable(_:)) {
            return candidate
        }

        if let candidate = candidates.first(where: Self.looksLikelyTabularText(_:)) {
            return candidate
        }

        return candidates[0]
    }

    var previewText: String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var confidenceIndicator: ConfidenceIndicator? {
        guard let ocrConfidence else {
            return nil
        }

        return Self.confidenceIndicator(for: ocrConfidence, contentKind: contentKind)
    }

    var searchableText: String {
        [
            text,
            effectiveRawText,
            captureMode.title,
            outputPreset.title,
            contentKind.title,
            isPinned ? "Sabit Favori" : "",
            confidenceIndicator?.title ?? "",
            source?.displayName ?? "",
            source?.bundleIdentifier ?? ""
        ]
        .joined(separator: "\n")
    }

    func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return true
        }

        return searchableText.localizedCaseInsensitiveContains(trimmed)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case date
        case captureMode
        case outputPreset
        case contentKind
        case rawText
        case ocrConfidence
        case source
        case isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try container.decode(String.self, forKey: .text)
        date = try container.decode(Date.self, forKey: .date)
        captureMode = try container.decodeIfPresent(CaptureMode.self, forKey: .captureMode) ?? .standard
        outputPreset = try container.decodeIfPresent(CaptureOutputPreset.self, forKey: .outputPreset) ?? .smart
        contentKind = try container.decodeIfPresent(ContentKind.self, forKey: .contentKind) ?? .text
        rawText = try container.decodeIfPresent(String.self, forKey: .rawText)
        ocrConfidence = try container.decodeIfPresent(Float.self, forKey: .ocrConfidence)
        source = try container.decodeIfPresent(SourceContext.self, forKey: .source)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    static func confidenceIndicator(for confidence: Float, contentKind: ContentKind) -> ConfidenceIndicator? {
        if contentKind == .barcode {
            return .high
        }

        let normalized = min(max(confidence, 0), 1)
        switch normalized {
        case ..<0.58:
            return .low
        case 0.82...:
            return .high
        default:
            return .medium
        }
    }

    private static func normalizedReviewSource(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsExplicitTableSeparators(_ text: String) -> Bool {
        text.contains("\t")
    }

    private static func looksLikeMarkdownTable(_ text: String) -> Bool {
        let nonEmptyLines = normalizedReviewSource(text)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard nonEmptyLines.count >= 2 else {
            return false
        }

        let pipeLines = nonEmptyLines.filter { $0.contains("|") }
        return pipeLines.count >= 2
    }

    private static func looksLikelyTabularText(_ text: String) -> Bool {
        let nonEmptyLines = normalizedReviewSource(text)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard nonEmptyLines.count >= 2 else {
            return false
        }

        let wideGapLines = nonEmptyLines.filter {
            $0.range(of: #"\s{2,}"#, options: .regularExpression) != nil
        }

        return wideGapLines.count >= max(2, Int(ceil(Double(nonEmptyLines.count) * 0.5)))
    }
}

struct TableReviewSession: Identifiable, Equatable, Sendable {
    let id: UUID
    let entry: ClipboardHistoryEntry
    let sourceText: String

    init(id: UUID = UUID(), entry: ClipboardHistoryEntry, sourceText: String) {
        self.id = id
        self.entry = entry
        self.sourceText = sourceText
    }
}

struct TableReviewDocument: Equatable, Sendable {
    var rows: [[String]]

    init(rows: [[String]]) {
        self.rows = Self.rectangularized(rows)
    }

    init(sourceText: String) {
        self.init(rows: Self.parseRows(from: sourceText))
    }

    var rowCount: Int {
        rows.count
    }

    var columnCount: Int {
        rows.first?.count ?? 0
    }

    var tsvText: String {
        Self.rectangularized(rows)
            .map { row in
                row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .joined(separator: "\t")
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cellValue(row: Int, column: Int) -> String {
        guard rows.indices.contains(row),
              rows[row].indices.contains(column) else {
            return ""
        }

        return rows[row][column]
    }

    mutating func setCell(row: Int, column: Int, value: String) {
        ensureSize(rowCount: row + 1, columnCount: column + 1)
        rows[row][column] = value
    }

    mutating func appendRow() {
        rows.append(Array(repeating: "", count: max(columnCount, 1)))
        rows = Self.rectangularized(rows)
    }

    mutating func appendColumn() {
        ensureSize(rowCount: max(rowCount, 1), columnCount: columnCount + 1)
    }

    mutating func removeLastRow() {
        guard rows.count > 1 else {
            rows = [[""]]
            return
        }

        rows.removeLast()
        rows = Self.rectangularized(rows)
    }

    mutating func removeLastColumn() {
        guard columnCount > 1 else {
            rows = Array(repeating: [""], count: max(rowCount, 1))
            return
        }

        for rowIndex in rows.indices {
            rows[rowIndex].removeLast()
        }
    }

    mutating func trimEmptyEdges() {
        let trimmedRows = Self.trimmedEdges(from: rows)
        rows = trimmedRows.isEmpty ? [[""]] : Self.rectangularized(trimmedRows)
    }

    mutating func reset(from sourceText: String) {
        self = Self(sourceText: sourceText)
    }

    private mutating func ensureSize(rowCount targetRows: Int, columnCount targetColumns: Int) {
        let resolvedRows = max(targetRows, 1)
        let resolvedColumns = max(targetColumns, 1)

        if rows.isEmpty {
            rows = Array(repeating: Array(repeating: "", count: resolvedColumns), count: resolvedRows)
            return
        }

        while rows.count < resolvedRows {
            rows.append(Array(repeating: "", count: max(columnCount, resolvedColumns)))
        }

        rows = Self.rectangularized(rows, minimumColumnCount: resolvedColumns)
    }

    private static func parseRows(from sourceText: String) -> [[String]] {
        let normalized = sourceText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return [[""]]
        }

        let lines = normalized
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return [[""]]
        }

        if lines.contains(where: { $0.contains("\t") }) {
            return rectangularized(
                lines.map { line in
                    line.split(separator: "\t", omittingEmptySubsequences: false)
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                }
            )
        }

        if let markdownRows = parseMarkdownRows(from: lines) {
            return rectangularized(markdownRows)
        }

        if let wideGapRows = parseRows(from: lines, separatorPattern: #"\s{2,}"#, minimumSupportedRows: max(2, Int(ceil(Double(lines.count) * 0.5)))) {
            return rectangularized(wideGapRows)
        }

        if let whitespaceRows = parseWhitespaceRows(from: lines) {
            return rectangularized(whitespaceRows)
        }

        return rectangularized(lines.map { [$0] })
    }

    private static func parseMarkdownRows(from lines: [String]) -> [[String]]? {
        let pipeLines = lines.filter { $0.contains("|") }
        guard pipeLines.count >= 2 else {
            return nil
        }

        let rows = pipeLines.compactMap { line -> [String]? in
            let cleaned = line
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "|"))

            let cells = cleaned
                .split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            if cells.isEmpty || cells.allSatisfy(isBlankCell(_:)) {
                return nil
            }

            if cells.allSatisfy({ $0.range(of: #"^:?-{2,}:?$"#, options: .regularExpression) != nil }) {
                return nil
            }

            return cells
        }

        guard rows.contains(where: { $0.count > 1 }) else {
            return nil
        }

        return rows
    }

    private static func parseRows(
        from lines: [String],
        separatorPattern: String,
        minimumSupportedRows: Int
    ) -> [[String]]? {
        let parsedRows = lines.map { split($0, by: separatorPattern) }
        let multiColumnRows = parsedRows.filter { $0.count > 1 }

        guard multiColumnRows.count >= minimumSupportedRows else {
            return nil
        }

        return parsedRows
    }

    private static func parseWhitespaceRows(from lines: [String]) -> [[String]]? {
        let parsedRows = lines.map {
            $0.split(whereSeparator: \.isWhitespace)
                .map(String.init)
        }

        guard let firstCount = parsedRows.first?.count, firstCount > 1 else {
            return nil
        }

        guard parsedRows.allSatisfy({ $0.count == firstCount }) else {
            return nil
        }

        return parsedRows
    }

    private static func split(_ line: String, by separatorPattern: String) -> [String] {
        line
            .replacingOccurrences(of: separatorPattern, with: "\t", options: .regularExpression)
            .split(separator: "\t", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private static func rectangularized(_ rows: [[String]], minimumColumnCount: Int = 1) -> [[String]] {
        let normalizedRows = rows.isEmpty ? [[""]] : rows.map { $0.isEmpty ? [""] : $0 }
        let columnCount = max(normalizedRows.map(\.count).max() ?? 1, minimumColumnCount)

        return normalizedRows.map { row in
            if row.count == columnCount {
                return row
            }

            return row + Array(repeating: "", count: columnCount - row.count)
        }
    }

    private static func trimmedEdges(from rows: [[String]]) -> [[String]] {
        var normalizedRows = rectangularized(rows)

        while normalizedRows.count > 1,
              normalizedRows.first?.allSatisfy(isBlankCell(_:)) == true {
            normalizedRows.removeFirst()
        }

        while normalizedRows.count > 1,
              normalizedRows.last?.allSatisfy(isBlankCell(_:)) == true {
            normalizedRows.removeLast()
        }

        while (normalizedRows.first?.count ?? 0) > 1,
              normalizedRows.allSatisfy({ isBlankCell($0.first ?? "") }) {
            for rowIndex in normalizedRows.indices {
                normalizedRows[rowIndex].removeFirst()
            }
        }

        while (normalizedRows.first?.count ?? 0) > 1,
              normalizedRows.allSatisfy({ isBlankCell($0.last ?? "") }) {
            for rowIndex in normalizedRows.indices {
                normalizedRows[rowIndex].removeLast()
            }
        }

        return normalizedRows
    }

    private static func isBlankCell(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum ClipboardHistoryExportFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case text
    case markdown
    case json
    case csv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text:
            return "TXT"
        case .markdown:
            return "Markdown"
        case .json:
            return "JSON"
        case .csv:
            return "CSV"
        }
    }

    var subtitle: String {
        switch self {
        case .text:
            return "Okunabilir düz metin"
        case .markdown:
            return "Başlıklı doküman"
        case .json:
            return "Yapılandırılmış veri"
        case .csv:
            return "Spreadsheet uyumlu"
        }
    }

    var fileExtension: String {
        rawValue
    }
}

enum ClipboardHistoryExportFormatStore {
    static let key = "screenTextGrab.historyExportFormat"

    static func load(defaults: UserDefaults = .standard) -> ClipboardHistoryExportFormat {
        guard let rawValue = defaults.string(forKey: key),
              let format = ClipboardHistoryExportFormat(rawValue: rawValue) else {
            return .markdown
        }

        return format
    }

    static func save(_ format: ClipboardHistoryExportFormat, defaults: UserDefaults = .standard) {
        defaults.set(format.rawValue, forKey: key)
    }
}

enum ClipboardHistoryStore {
    static let key = "screenTextGrab.copyHistory"
    static let maximumEntries = 25

    static func load(defaults: UserDefaults = .standard) -> [ClipboardHistoryEntry] {
        guard let data = defaults.data(forKey: key),
              let history = try? JSONDecoder().decode([ClipboardHistoryEntry].self, from: data) else {
            return []
        }
        return Array(history.prefix(maximumEntries))
    }

    static func save(_ history: [ClipboardHistoryEntry], defaults: UserDefaults = .standard) {
        let trimmed = Array(history.prefix(maximumEntries))
        guard let data = try? JSONEncoder().encode(trimmed) else {
            return
        }
        defaults.set(data, forKey: key)
    }

    static func export(_ history: [ClipboardHistoryEntry], format: ClipboardHistoryExportFormat, generatedAt: Date = Date()) -> String {
        switch format {
        case .text:
            return exportText(history, generatedAt: generatedAt)
        case .markdown:
            return exportMarkdown(history, generatedAt: generatedAt)
        case .json:
            return exportJSON(history)
        case .csv:
            return exportCSV(history)
        }
    }

    static func orderedForDisplay(_ history: [ClipboardHistoryEntry]) -> [ClipboardHistoryEntry] {
        history.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }

            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    static func exportText(_ history: [ClipboardHistoryEntry], generatedAt: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = [
            "ScreenTextGrab Geçmişi",
            "Oluşturulma: \(formatter.string(from: generatedAt))",
            ""
        ]

        for (index, entry) in history.enumerated() {
            lines.append("#\(index + 1) - \(formatter.string(from: entry.date))")
            lines.append("Mod: \(entry.captureMode.title) | Çıktı: \(entry.outputPreset.title) | Tür: \(entry.contentKind.title) | Kaynak: \(entry.source?.displayName ?? "Bilinmiyor") | Sabit: \(entry.isPinned ? "Evet" : "Hayır")")
            lines.append(entry.text)
            if entry.effectiveRawText != entry.text {
                lines.append("Ham Metin: \(entry.effectiveRawText)")
            }
            lines.append("")
        }

        return lines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func exportMarkdown(_ history: [ClipboardHistoryEntry], generatedAt: Date) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = [
            "# ScreenTextGrab Geçmişi",
            "",
            "- Oluşturulma: \(formatter.string(from: generatedAt))",
            "- Kayıt Sayısı: \(history.count)",
            ""
        ]

        for (index, entry) in history.enumerated() {
            lines.append("## \(index + 1). Kayıt")
            lines.append("")
            lines.append("- Tarih: \(formatter.string(from: entry.date))")
            lines.append("- Mod: \(entry.captureMode.title)")
            lines.append("- Çıktı: \(entry.outputPreset.title)")
            lines.append("- Tür: \(entry.contentKind.title)")
            lines.append("- Kaynak: \(entry.source?.displayName ?? "Bilinmiyor")")
            lines.append("- Sabit: \(entry.isPinned ? "Evet" : "Hayır")")
            lines.append("")
            lines.append("```text")
            lines.append(entry.text)
            lines.append("```")
            if entry.effectiveRawText != entry.text {
                lines.append("")
                lines.append("Ham İçerik")
                lines.append("")
                lines.append("```text")
                lines.append(entry.effectiveRawText)
                lines.append("```")
            }
            lines.append("")
        }

        return lines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func exportJSON(_ history: [ClipboardHistoryEntry]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(history),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return string
    }

    private static func exportCSV(_ history: [ClipboardHistoryEntry]) -> String {
        var rows = [
            [
                "date",
                "mode",
                "output_preset",
                "content_kind",
                "is_pinned",
                "source_app",
                "source_bundle_id",
                "raw_text",
                "text"
            ].joined(separator: ",")
        ]

        for entry in history {
            rows.append([
                csvEscaped(ISO8601DateFormatter().string(from: entry.date)),
                csvEscaped(entry.captureMode.title),
                csvEscaped(entry.outputPreset.title),
                csvEscaped(entry.contentKind.title),
                csvEscaped(entry.isPinned ? "true" : "false"),
                csvEscaped(entry.source?.appName ?? ""),
                csvEscaped(entry.source?.bundleIdentifier ?? ""),
                csvEscaped(entry.effectiveRawText),
                csvEscaped(entry.text)
            ].joined(separator: ","))
        }

        return rows.joined(separator: "\n")
    }

    private static func csvEscaped(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

struct SmartActionContext: Equatable, Sendable {
    let copiedText: String
    let rawText: String
    let captureMode: CaptureMode
    let outputPreset: CaptureOutputPreset
    let contentKind: ClipboardHistoryEntry.ContentKind

    init(
        copiedText: String,
        rawText: String,
        captureMode: CaptureMode = .standard,
        outputPreset: CaptureOutputPreset = .smart,
        contentKind: ClipboardHistoryEntry.ContentKind = .text
    ) {
        self.copiedText = copiedText
        self.rawText = rawText
        self.captureMode = captureMode
        self.outputPreset = outputPreset
        self.contentKind = contentKind
    }

    init(entry: ClipboardHistoryEntry) {
        self.init(
            copiedText: entry.text,
            rawText: entry.effectiveRawText,
            captureMode: entry.captureMode,
            outputPreset: entry.outputPreset,
            contentKind: entry.contentKind
        )
    }
}

struct SmartActionDescriptor: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case openURL(URL)
        case composeEmail(URL)
        case callPhone(URL)
        case translateText(URL)
        case searchWeb(URL)
        case copyAsPreset(CaptureOutputPreset)
    }

    let kind: Kind
    let title: String
    let icon: String
    let target: String

    var id: String {
        "\(title)|\(target)"
    }

    var url: URL? {
        switch kind {
        case let .openURL(url),
             let .composeEmail(url),
             let .callPhone(url),
             let .translateText(url),
             let .searchWeb(url):
            return url
        case .copyAsPreset:
            return nil
        }
    }
}

enum SmartActionBuilder {
    static func actions(for text: String) -> [SmartActionDescriptor] {
        actions(
            for: SmartActionContext(
                copiedText: text,
                rawText: text
            )
        )
    }

    static func actions(for entry: ClipboardHistoryEntry?) -> [SmartActionDescriptor] {
        guard let entry else {
            return []
        }

        return actions(for: SmartActionContext(entry: entry))
    }

    static func actions(for context: SmartActionContext) -> [SmartActionDescriptor] {
        let raw = context.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return []
        }

        var actions = transformationActions(for: context)

        if let url = normalizedURL(from: raw) {
            actions.append(
                SmartActionDescriptor(
                    kind: .openURL(url),
                    title: "Bağlantıyı Aç",
                    icon: "safari",
                    target: url.absoluteString
                )
            )
            return uniqueActions(actions)
        }

        if let email = emailAddress(from: raw),
           let url = URL(string: "mailto:\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email)") {
            actions.append(
                SmartActionDescriptor(
                    kind: .composeEmail(url),
                    title: "Mail Yaz",
                    icon: "envelope",
                    target: email
                )
            )
            return uniqueActions(actions)
        }

        if let phone = phoneNumber(from: raw),
           let encoded = phone.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "tel:\(encoded)") {
            actions.append(
                SmartActionDescriptor(
                    kind: .callPhone(url),
                    title: "Ara",
                    icon: "phone",
                    target: phone
                )
            )
            return uniqueActions(actions)
        }

        if let translationAction = translationAction(for: context) {
            actions.append(translationAction)
        }

        if shouldOfferWebSearch(for: context),
           let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let searchURL = URL(string: "https://www.google.com/search?q=\(encoded)") {
            actions.append(
                SmartActionDescriptor(
                    kind: .searchWeb(searchURL),
                    title: "Web'de Ara",
                    icon: "magnifyingglass",
                    target: raw
                )
            )
        }

        return uniqueActions(actions)
    }

    static func shouldOfferReadAloud(for text: String) -> Bool {
        shouldOfferReadAloud(
            for: SmartActionContext(
                copiedText: text,
                rawText: text
            )
        )
    }

    static func shouldOfferReadAloud(for entry: ClipboardHistoryEntry?) -> Bool {
        guard let entry else {
            return false
        }

        return shouldOfferReadAloud(for: SmartActionContext(entry: entry))
    }

    static func shouldOfferReadAloud(for context: SmartActionContext) -> Bool {
        let raw = context.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return false
        }

        guard context.outputPreset != .markdown && context.outputPreset != .json else {
            return false
        }

        return containsLetters(raw) &&
            !raw.contains("\t") &&
            raw.count >= 2 &&
            raw.count <= 1_500 &&
            normalizedURL(from: raw) == nil &&
            emailAddress(from: raw) == nil &&
            phoneNumber(from: raw) == nil &&
            !looksLikeCode(raw)
    }

    static func preferredSpeechLanguage(for text: String) -> String {
        likelyTurkish(text) ? OCRLanguagePreference.turkish.rawValue : OCRLanguagePreference.english.rawValue
    }

    static func preferredSpeechLanguage(for entry: ClipboardHistoryEntry?) -> String {
        likelyTurkish(entry?.effectiveRawText ?? entry?.text ?? "")
            ? OCRLanguagePreference.turkish.rawValue
            : OCRLanguagePreference.english.rawValue
    }

    private static func normalizedURL(from text: String) -> URL? {
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
           let match = detector.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
           match.range.length == text.utf16.count,
           let url = match.url,
           ["http", "https"].contains(url.scheme?.lowercased()) {
            return url
        }

        if text.lowercased().hasPrefix("www."),
           let url = URL(string: "https://\(text)") {
            return url
        }

        guard let url = URL(string: text),
              ["http", "https"].contains(url.scheme?.lowercased()) else {
            return nil
        }

        return url
    }

    private static func translationAction(for context: SmartActionContext) -> SmartActionDescriptor? {
        let text = context.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldOfferTranslation(for: context) else {
            return nil
        }

        let targetLanguage = preferredTranslationTargetLanguage(for: text)
        let targetTitle = targetLanguage == "en" ? "İngilizceye Çevir" : "Türkçeye Çevir"
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.google.com/?sl=auto&tl=\(targetLanguage)&text=\(encoded)&op=translate") else {
            return nil
        }

        return SmartActionDescriptor(
            kind: .translateText(url),
            title: targetTitle,
            icon: "globe",
            target: text
        )
    }

    private static func emailAddress(from text: String) -> String? {
        let pattern = #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#
        guard text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil else {
            return nil
        }
        return text
    }

    private static func phoneNumber(from text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue),
              let match = detector.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
              match.range.length == text.utf16.count,
              let phoneNumber = match.phoneNumber else {
            return nil
        }

        let digits = phoneNumber.filter(\.isNumber)
        return digits.count >= 7 ? phoneNumber : nil
    }

    private static func shouldOfferWebSearch(for context: SmartActionContext) -> Bool {
        let text = context.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard context.outputPreset != .markdown && context.outputPreset != .json else {
            return false
        }

        return !text.contains("\n") &&
            !text.contains("\t") &&
            text.count >= 2 &&
            text.count <= 90
    }

    private static func shouldOfferTranslation(for context: SmartActionContext) -> Bool {
        let text = context.rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard context.outputPreset != .markdown && context.outputPreset != .json else {
            return false
        }

        return containsLetters(text) &&
            !text.contains("\t") &&
            text.count >= 2 &&
            text.count <= 300 &&
            normalizedURL(from: text) == nil &&
            emailAddress(from: text) == nil &&
            phoneNumber(from: text) == nil &&
            !looksLikeCode(text)
    }

    private static func preferredTranslationTargetLanguage(for text: String) -> String {
        likelyTurkish(text) ? "en" : "tr"
    }

    private static func containsLetters(_ text: String) -> Bool {
        text.unicodeScalars.contains { CharacterSet.letters.contains($0) }
    }

    private static func looksLikeCode(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let codeSignals = [
            "func ", "let ", "var ", "const ", "class ", "struct ", "import ", "return ",
            "public ", "private ", "=>", "->", "::", "</", "/>", "console.", "print(",
            "select ", "from ", "where ", "{", "}", "==", ";"
        ]

        let matches = codeSignals.reduce(into: 0) { count, signal in
            if lowercased.contains(signal) {
                count += 1
            }
        }

        if matches >= 2 {
            return true
        }

        if matches >= 1 && (text.contains("=") || text.contains(".") || text.contains("(") || text.contains("[") || text.contains("{")) {
            return true
        }

        if text.contains("\n") && (text.contains("{") || text.contains("}") || text.contains(";")) {
            return true
        }

        return false
    }

    private static func likelyTurkish(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        if lowercased.contains(where: { "çğıöşü".contains($0) }) {
            return true
        }

        let words = lowercased
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
        let commonTurkishWords: Set<String> = [
            "ve", "için", "bir", "ile", "bu", "şu", "değil",
            "ekran", "ekrandaki", "metin", "metni", "kopya", "kopyala", "yakala",
            "başlat", "durdur", "ayar", "ayarlar", "izin", "yenile", "kapat"
        ]
        let domainPrefixes = ["ekran", "metin", "kopy", "yakal", "ayar", "izin", "başlat", "durdur"]
        let directMatches = words.filter { commonTurkishWords.contains($0) }.count
        if directMatches >= 1 {
            return true
        }

        return words.contains { word in
            domainPrefixes.contains(where: { word.hasPrefix($0) })
        }
    }

    private static func transformationActions(for context: SmartActionContext) -> [SmartActionDescriptor] {
        var actions: [SmartActionDescriptor] = []

        switch context.captureMode {
        case .code:
            if context.outputPreset != .markdown {
                actions.append(
                    SmartActionDescriptor(
                        kind: .copyAsPreset(.markdown),
                        title: "Markdown Kod",
                        icon: "chevron.left.forwardslash.chevron.right",
                        target: "markdown-code"
                    )
                )
            }

            if context.outputPreset != .office {
                actions.append(
                    SmartActionDescriptor(
                        kind: .copyAsPreset(.office),
                        title: "Word'e Uygun",
                        icon: "doc.richtext",
                        target: "office-code"
                    )
                )
            }
        case .table:
            if context.outputPreset != .office {
                actions.append(
                    SmartActionDescriptor(
                        kind: .copyAsPreset(.office),
                        title: "Excel'e Uygun",
                        icon: "tablecells",
                        target: "office-table"
                    )
                )
            }

            if context.outputPreset != .markdown {
                actions.append(
                    SmartActionDescriptor(
                        kind: .copyAsPreset(.markdown),
                        title: "Markdown Tablo",
                        icon: "tablecells",
                        target: "markdown-table"
                    )
                )
            }

            if context.outputPreset != .json {
                actions.append(
                    SmartActionDescriptor(
                        kind: .copyAsPreset(.json),
                        title: "JSON Çıktı",
                        icon: "curlybraces",
                        target: "json-table"
                    )
                )
            }
        case .subtitle:
            if context.outputPreset != .cleaned {
                actions.append(
                    SmartActionDescriptor(
                        kind: .copyAsPreset(.cleaned),
                        title: "Altyazıyı Temizle",
                        icon: "text.badge.checkmark",
                        target: "clean-subtitle"
                    )
                )
            }

            if context.outputPreset != .office {
                actions.append(
                    SmartActionDescriptor(
                        kind: .copyAsPreset(.office),
                        title: "Word'e Uygun",
                        icon: "doc.richtext",
                        target: "office-subtitle"
                    )
                )
            }
        case .standard:
            break
        }

        if context.outputPreset != .smart &&
            (context.outputPreset == .markdown || context.outputPreset == .json || context.outputPreset == .cleaned || context.outputPreset == .office) {
            actions.append(
                SmartActionDescriptor(
                    kind: .copyAsPreset(.smart),
                    title: "Ham Çıktı",
                    icon: "doc.on.doc",
                    target: "smart-output"
                )
            )
        }

        return actions
    }

    private static func uniqueActions(_ actions: [SmartActionDescriptor]) -> [SmartActionDescriptor] {
        var seen = Set<String>()
        return actions.filter { action in
            seen.insert(action.id).inserted
        }
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, width > 0, height > 0 else { return 0 }
        return width * height
    }
}
