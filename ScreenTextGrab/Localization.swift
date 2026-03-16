import Foundation

enum L10n {
    private static var languageIdentifier: String {
        if let override = ProcessInfo.processInfo.environment["SCREENTEXTGRAB_UI_LANGUAGE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           !override.isEmpty {
            return override
        }

        if let storedIdentifier = InterfaceLanguageStore.load().resolvedIdentifier {
            return storedIdentifier
        }

        if let defaultsLanguages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           let firstLanguage = defaultsLanguages.first?.lowercased(),
           !firstLanguage.isEmpty {
            return firstLanguage
        }

        return Locale.preferredLanguages.first?.lowercased() ?? "en"
    }

    static var usesEnglish: Bool {
        languageIdentifier.hasPrefix("en")
    }

    static func pair(_ tr: String, _ en: String) -> String {
        usesEnglish ? en : tr
    }

    static func format(_ tr: String, _ en: String, _ arguments: CVarArg...) -> String {
        let format = pair(tr, en)
        return String(format: format, locale: Locale.current, arguments: arguments)
    }

    static var controlsTitle: String { pair("Kontroller", "Controls") }
    static var settingsTitle: String { pair("ScreenTextGrab Ayarları", "ScreenTextGrab Settings") }
    static var settingsSubtitle: String { pair("Kısayol, izinler, OCR dili ve geçmiş yönetimini buradan düzenle.", "Manage shortcuts, permissions, OCR language, and history here.") }

    static var settingsTabGeneral: String { pair("Genel", "General") }
    static var settingsTabOCR: String { "OCR" }
    static var settingsTabDiagnostics: String { pair("Tanı", "Diagnostics") }
    static var settingsTabHistory: String { pair("Geçmiş", "History") }

    static var actionSettings: String { pair("Ayarlar", "Settings") }
    static var actionRefresh: String { pair("Yenile", "Refresh") }
    static var actionClipboardImage: String { pair("Panodaki Görseli Oku", "Read Clipboard Image") }
    static var actionImageFile: String { pair("Görsel Dosyası Oku", "Read Image File") }
    static var actionPDFFile: String { pair("PDF Oku", "Read PDF") }
    static var actionSearchablePDF: String { "Searchable PDF" }
    static var actionAllow: String { pair("İzin Ver", "Allow Access") }
    static var actionSystemSettings: String { pair("Sistem Ayarları", "System Settings") }
    static var actionRequestPermission: String { pair("İzin İste", "Request Access") }
    static var actionDiagnostics: String { pair("Tanı", "Diagnostics") }
    static var actionCopy: String { pair("Kopyala", "Copy") }
    static var actionDelete: String { pair("Sil", "Delete") }
    static var actionExport: String { pair("Dışa Aktar", "Export") }
    static var actionClear: String { pair("Temizle", "Clear") }
    static var actionSupportBundle: String { pair("Support Paketi", "Support Bundle") }
    static var actionCopyDiagnostics: String { pair("Tanıyı Kopyala", "Copy Diagnostics") }
    static var actionLoginItems: String { pair("Giriş Öğeleri", "Login Items") }
    static var actionDefault: String { pair("Varsayılan", "Default") }
    static var actionChange: String { pair("Değiştir", "Change") }
    static var actionCancel: String { pair("İptal", "Cancel") }
    static var actionOpenApplicationsFolder: String { pair("Applications Klasörünü Aç", "Open Applications Folder") }
    static var actionContinue: String { pair("Devam Et", "Continue") }
    static var ocrAutomaticLanguage: String { pair("Dili otomatik algıla", "Automatically detect language") }

    static var installRootUnavailable: String { pair("Applications klasöründe yazılabilir bir hedef bulunamadı.", "No writable install destination was found in Applications.") }
    static var installCopyFailedPrefix: String { pair("Uygulama Applications klasörüne taşınamadı:", "The app could not be moved to Applications:") }
    static var installRelocatingStatus: String { pair("⚠️ Uygulama Applications klasörüne taşınıyor...", "⚠️ Moving the app to Applications...") }
    static var installOpenFromApplicationsStatus: String { pair("⚠️ Uygulamayı Applications klasöründen aç", "⚠️ Open the app from Applications") }
    static var installOpeningInstalledCopyStatus: String { pair("⚠️ Yüklü uygulama kopyası açılıyor...", "⚠️ Opening the installed app copy...") }
    static var installAlertTitle: String { pair("Uygulamayı Applications klasöründen aç", "Open the app from Applications") }
    static var installAlertBody: String { pair("ScreenTextGrab izinleri ve Spotlight kaydını stabil tutmak için Applications klasöründen çalışmalıdır.", "ScreenTextGrab should run from Applications so permissions and Spotlight registration stay stable.") }

    static var accessibilityQuitApp: String { pair("Uygulamadan çık", "Quit app") }
    static var accessibilityResetHotkey: String { pair("Kısayolu varsayılana döndür", "Reset shortcut to default") }
    static var accessibilityLaunchAtLoginToggle: String { pair("Açılışta başlat", "Launch at login") }
    static var accessibilityCaptureMode: String { pair("Yakalama modu", "Capture mode") }
    static var accessibilityOCRLanguage: String { pair("OCR dili", "OCR language") }
    static var accessibilityAutomaticLanguage: String { pair("Dili otomatik algıla", "Automatically detect language") }
    static var accessibilityInterfaceLanguage: String { pair("Arayüz dili", "Interface language") }
}
