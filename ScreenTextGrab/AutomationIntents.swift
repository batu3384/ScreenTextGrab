import AppIntents
import AppKit

@available(macOS 14.0, *)
enum CaptureModeIntentValue: String, AppEnum {
    case standard
    case subtitle
    case code
    case table

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Yakalama Modu"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .standard: "Standart",
        .subtitle: "Altyazı",
        .code: "Kod",
        .table: "Tablo"
    ]

    var captureMode: CaptureMode {
        switch self {
        case .standard:
            return .standard
        case .subtitle:
            return .subtitle
        case .code:
            return .code
        case .table:
            return .table
        }
    }
}

@available(macOS 14.0, *)
enum CaptureOutputIntentValue: String, AppEnum {
    case smart
    case plainText
    case cleaned
    case office
    case markdown
    case json

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Çıktı Biçimi"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .smart: "Akıllı",
        .plainText: "Düz Metin",
        .cleaned: "Temizlenmiş",
        .office: "Office",
        .markdown: "Markdown",
        .json: "JSON"
    ]

    var outputPreset: CaptureOutputPreset {
        switch self {
        case .smart:
            return .smart
        case .plainText:
            return .plainText
        case .cleaned:
            return .cleaned
        case .office:
            return .office
        case .markdown:
            return .markdown
        case .json:
            return .json
        }
    }
}

@available(macOS 14.0, *)
struct CaptureScreenTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Metni Yakala"
    static let description = IntentDescription("ScreenTextGrab ile yeni bir ekran yakalaması başlatır.")
    static let openAppWhenRun = true

    @Parameter(title: "Yakalama Modu")
    var mode: CaptureModeIntentValue?

    @Parameter(title: "Çıktı Biçimi")
    var output: CaptureOutputIntentValue?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let url = AutomationURLBuilder.capture(
            overrides: AutomationCaptureOverrides(
                captureMode: mode?.captureMode,
                outputPreset: output?.outputPreset
            )
        )
        if let url {
            NSWorkspace.shared.open(url)
        }

        return .result(dialog: "ScreenTextGrab yakalama modunu açtı.")
    }
}

@available(macOS 14.0, *)
struct RepeatLastCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Son Alanı Tekrar Yakala"
    static let description = IntentDescription("Son seçilen ekran bölgesini aynı ayarlarla yeniden yakalar.")
    static let openAppWhenRun = true

    @Parameter(title: "Yakalama Modu")
    var mode: CaptureModeIntentValue?

    @Parameter(title: "Çıktı Biçimi")
    var output: CaptureOutputIntentValue?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let url = AutomationURLBuilder.repeatLast(
            overrides: AutomationCaptureOverrides(
                captureMode: mode?.captureMode,
                outputPreset: output?.outputPreset
            )
        )
        if let url {
            NSWorkspace.shared.open(url)
        }

        return .result(dialog: "ScreenTextGrab son alanı yeniden yakalıyor.")
    }
}

@available(macOS 14.0, *)
struct CaptureClipboardImageIntent: AppIntent {
    static let title: LocalizedStringResource = "Panodaki Görseli Oku"
    static let description = IntentDescription("Panodaki görsel veya ekran görüntüsünden OCR başlatır.")
    static let openAppWhenRun = true

    @Parameter(title: "Yakalama Modu")
    var mode: CaptureModeIntentValue?

    @Parameter(title: "Çıktı Biçimi")
    var output: CaptureOutputIntentValue?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let url = AutomationURLBuilder.clipboardImage(
            overrides: AutomationCaptureOverrides(
                captureMode: mode?.captureMode,
                outputPreset: output?.outputPreset
            )
        )
        if let url {
            NSWorkspace.shared.open(url)
        }

        return .result(dialog: "ScreenTextGrab panodaki görseli okumaya başladı.")
    }
}

@available(macOS 14.0, *)
struct RunSavedRegionIntent: AppIntent {
    static let title: LocalizedStringResource = "Kayıtlı Bölgeyi Yakala"
    static let description = IntentDescription("Daha önce kaydedilmiş bir ekran bölgesini yeniden yakalar.")
    static let openAppWhenRun = true

    @Parameter(title: "Bölge Adı")
    var name: String

    @Parameter(title: "Yakalama Modu")
    var mode: CaptureModeIntentValue?

    @Parameter(title: "Çıktı Biçimi")
    var output: CaptureOutputIntentValue?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let url = AutomationURLBuilder.savedRegion(
            name: name,
            overrides: AutomationCaptureOverrides(
                captureMode: mode?.captureMode,
                outputPreset: output?.outputPreset
            )
        )
        if let url {
            NSWorkspace.shared.open(url)
        }

        return .result(dialog: "ScreenTextGrab kayıtlı bölgeyi çalıştırıyor.")
    }
}

@available(macOS 14.0, *)
struct CopyActiveSavedSnippetIntent: AppIntent {
    static let title: LocalizedStringResource = "Aktif Snippet'ı Kopyala"
    static let description = IntentDescription("Aktif uygulama veya pencere için ScreenTextGrab'ın önerdiği snippet'ı panoya kopyalar.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let url = AutomationURLBuilder.activeSnippet()
        if let url {
            NSWorkspace.shared.open(url)
        }

        return .result(dialog: "ScreenTextGrab aktif uygulama için önerilen snippet'ı kopyalıyor.")
    }
}

@available(macOS 14.0, *)
struct CopySavedSnippetIntent: AppIntent {
    static let title: LocalizedStringResource = "Kayıtlı Snippet'ı Kopyala"
    static let description = IntentDescription("Daha önce kaydedilmiş bir snippet'ı aynı çıktı biçimiyle panoya kopyalar.")
    static let openAppWhenRun = true

    @Parameter(title: "Snippet Adı")
    var name: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let url = AutomationURLBuilder.snippet(name: name)
        if let url {
            NSWorkspace.shared.open(url)
        }

        return .result(dialog: "ScreenTextGrab kayıtlı snippet'ı panoya kopyalıyor.")
    }
}

@available(macOS 14.0, *)
struct OpenSavedSnippetCollectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Snippet Koleksiyonunu Aç"
    static let description = IntentDescription("Kayıtlı bir snippet koleksiyonunu açar ve aynı filtreyi Ayarlar > Geçmiş içinde uygular.")
    static let openAppWhenRun = true

    @Parameter(title: "Koleksiyon Adı")
    var name: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let url = AutomationURLBuilder.snippetCollection(name: name)
        if let url {
            NSWorkspace.shared.open(url)
        }

        return .result(dialog: "ScreenTextGrab kayıtlı snippet koleksiyonunu açıyor.")
    }
}

@available(macOS 14.0, *)
struct ScreenTextGrabShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: CaptureScreenTextIntent(),
                phrases: [
                    "Metni \(.applicationName) ile yakala",
                    "Yeni yakalama başlat \(.applicationName)"
                ],
                shortTitle: "Metni Yakala",
                systemImageName: "text.viewfinder"
            ),
            AppShortcut(
                intent: RepeatLastCaptureIntent(),
                phrases: [
                    "Son alanı \(.applicationName) ile tekrar yakala",
                    "Son yakalamayı tekrar et \(.applicationName)"
                ],
                shortTitle: "Son Alanı Tekrar Yakala",
                systemImageName: "arrow.clockwise"
            ),
            AppShortcut(
                intent: CaptureClipboardImageIntent(),
                phrases: [
                    "Panodaki görseli \(.applicationName) ile oku",
                    "Panodaki ekran görüntüsünü \(.applicationName) ile yakala"
                ],
                shortTitle: "Panodaki Görseli Oku",
                systemImageName: "photo.on.rectangle"
            ),
            AppShortcut(
                intent: RunSavedRegionIntent(),
                phrases: [
                    "Kayıtlı bölgeyi \(.applicationName) ile yakala",
                    "Sabit alanı \(.applicationName) ile çalıştır"
                ],
                shortTitle: "Kayıtlı Bölgeyi Yakala",
                systemImageName: "rectangle.on.rectangle"
            ),
            AppShortcut(
                intent: CopyActiveSavedSnippetIntent(),
                phrases: [
                    "Aktif snippet'ı \(.applicationName) ile kopyala",
                    "Önerilen snippet'ı \(.applicationName) ile getir"
                ],
                shortTitle: "Aktif Snippet",
                systemImageName: "text.badge.star"
            ),
            AppShortcut(
                intent: CopySavedSnippetIntent(),
                phrases: [
                    "Snippet'ı \(.applicationName) ile kopyala",
                    "Kayıtlı snippet'ı \(.applicationName) ile getir"
                ],
                shortTitle: "Snippet'ı Kopyala",
                systemImageName: "bookmark"
            ),
            AppShortcut(
                intent: OpenSavedSnippetCollectionIntent(),
                phrases: [
                    "Snippet koleksiyonunu \(.applicationName) ile aç",
                    "Kaydedilmiş snippet filtresini \(.applicationName) ile aç"
                ],
                shortTitle: "Koleksiyonu Aç",
                systemImageName: "square.stack"
            )
        ]
    }
}
