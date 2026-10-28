import Foundation

enum L10n {
    static func resolvedLanguageIdentifier(
        defaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        if let override = environment["SCREENTEXTGRAB_UI_LANGUAGE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           !override.isEmpty {
            return override
        }

        if let storedIdentifier = InterfaceLanguageStore.load(defaults: defaults).resolvedIdentifier {
            return storedIdentifier
        }

        if let defaultsLanguages = defaults.array(forKey: "AppleLanguages") as? [String],
           let firstLanguage = defaultsLanguages.first?.lowercased(),
           !firstLanguage.isEmpty {
            return firstLanguage
        }

        return preferredLanguages.first?.lowercased() ?? "en"
    }

    private static var languageIdentifier: String {
        resolvedLanguageIdentifier()
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
    static var actionCheckForUpdates: String { pair("Güncellemeleri Kontrol Et", "Check for Updates") }
    static var actionCheckingForUpdates: String { pair("Kontrol Ediliyor...", "Checking...") }
    static var actionDownloadingUpdate: String { pair("İndiriliyor...", "Downloading...") }
    static var actionRestartToUpdate: String { pair("Yeniden Başlat ve Güncelle", "Restart & Update") }
    static var actionRetryUpdate: String { pair("Tekrar Dene", "Try Again") }
    static var actionUpToDate: String { pair("Güncel", "Up to Date") }
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
    static var accessibilityCheckForUpdates: String { pair("Güncellemeleri kontrol et", "Check for updates") }
    static var accessibilityResetHotkey: String { pair("Kısayolu varsayılana döndür", "Reset shortcut to default") }
    static var accessibilityLaunchAtLoginToggle: String { pair("Açılışta başlat", "Launch at login") }
    static var accessibilityCaptureMode: String { pair("Yakalama modu", "Capture mode") }
    static var accessibilityOCRLanguage: String { pair("OCR dili", "OCR language") }
    static var accessibilityAutomaticLanguage: String { pair("Dili otomatik algıla", "Automatically detect language") }
    static var accessibilityInterfaceLanguage: String { pair("Arayüz dili", "Interface language") }

    static var captureBlockedByWatch: String { pair("👁 İzleme aktifken normal yakalama başlamaz. Önce izlemeyi durdur.", "👁 Stop watching before starting a normal capture.") }
    static var capturePreparing: String { pair("Yakalamaya hazırlanıyor...", "Preparing capture...") }
    static var permissionRestartCapture: String { pair("🔐 İzin verildi. Lütfen uygulamayı yeniden başlatın.", "🔐 Access granted. Restart the app to capture.") }
    static var permissionDeniedRefresh: String { pair("🔐 Ekran kaydı izni gerekli. İzin verdiyseniz 'Yenile' ile tekrar kontrol edin.", "🔐 Screen recording permission is required. If you already allowed it, use Refresh.") }
    static var permissionUnknown: String { pair("🔐 İzin durumu doğrulanamadı. Sistem Ayarları veya 'Yenile' ile tekrar deneyin.", "🔐 Permission status could not be verified. Use System Settings or Refresh.") }
    static var permissionRequestInProgress: String { pair("İzin isteği devam ediyor...", "Permission request is still in progress...") }
    static var repeatBlockedByWatch: String { pair("👁 İzleme aktifken son alan yeniden yakalanmaz. Önce izlemeyi durdur.", "👁 Stop watching before recapturing the last region.") }
    static var repeatNeedsSelection: String { pair("Önce bir alan yakala, sonra tekrar kullan.", "Capture a region once before repeating it.") }
    static var savedRegionBlockedByWatch: String { pair("👁 İzleme aktifken kayıtlı bölge yakalanmaz. Önce izlemeyi durdur.", "👁 Stop watching before capturing a saved region.") }
    static var clipboardImageBlockedByWatch: String { pair("👁 İzleme aktifken panodaki görsel okunmaz. Önce izlemeyi durdur.", "👁 Stop watching before reading a clipboard image.") }
    static var clipboardImagePreparing: String { pair("Panodaki görsel hazırlanıyor...", "Preparing the clipboard image...") }
    static var imageFileBlockedByWatch: String { pair("👁 İzleme aktifken dosya OCR başlamaz. Önce izlemeyi durdur.", "👁 Stop watching before reading an image file.") }
    static var imageFilePreparing: String { pair("Görsel dosyası hazırlanıyor...", "Preparing the image file...") }
    static var pdfBlockedByWatch: String { pair("👁 İzleme aktifken PDF OCR başlamaz. Önce izlemeyi durdur.", "👁 Stop watching before reading a PDF.") }
    static var pdfPreparing: String { pair("PDF hazırlanıyor...", "Preparing the PDF...") }
    static var searchablePDFBlockedByWatch: String { pair("👁 İzleme aktifken searchable PDF üretilemez. Önce izlemeyi durdur.", "👁 Stop watching before creating a searchable PDF.") }
    static var searchablePDFPreparing: String { pair("Searchable PDF hazırlanıyor...", "Preparing the searchable PDF...") }
    static var watchPreparing: String { pair("İzleme hazırlanıyor...", "Preparing watch mode...") }
    static var watchPermissionRestart: String { pair("🔐 İzin verildi. İzleme için uygulamayı yeniden başlatın.", "🔐 Access granted. Restart the app before watching.") }
    static var watchPermissionDenied: String { pair("🔐 İzleme için ekran kaydı izni gerekli.", "🔐 Screen recording permission is required for watch mode.") }
    static var watchPermissionUnknown: String { pair("🔐 İzin durumu doğrulanamadı. Önce yenileyin.", "🔐 Permission status could not be verified. Refresh first.") }
    static var watchPermissionInProgress: String { pair("İzin isteği sürüyor...", "Permission request is still running...") }
    static var watchStopped: String { pair("İzleme durduruldu", "Watching stopped") }
    static var captureCancelled: String { pair("Yakalama iptal edildi", "Capture cancelled") }
    static var permissionRequesting: String { pair("Ekran izni isteniyor...", "Requesting screen recording permission...") }
    static var copyingToClipboard: String { pair("Panoya kopyalanıyor...", "Copying to the clipboard...") }
    static var pdfTextCopied: String { pair("✅ PDF metni kopyalandı", "✅ PDF text copied") }
    static var watchCancelled: String { pair("İzleme iptal edildi", "Watching cancelled") }
    static var permissionRestartShort: String { pair("🔐 İzin verildi, uygulamayı yeniden başlatın", "🔐 Access granted, restart the app") }
    static var permissionUnknownShort: String { pair("İzin durumu doğrulanamıyor. Sistem Ayarları veya 'Yenile' ile tekrar deneyin.", "Permission status cannot be verified. Use System Settings or Refresh.") }
    static var watchStoppedPermissionOff: String { pair("🔐 İzleme durdu. Ekran kaydı izni kapalı.", "🔐 Watching stopped. Screen recording permission is off.") }
    static var watchStoppedNeedsRestart: String { pair("🔐 İzleme durdu. Yeni izin için uygulamayı yeniden başlatın.", "🔐 Watching stopped. Restart the app to use the new permission.") }
    static var watchTemporaryPermissionError: String { pair("👁 Geçici izin hatası algılandı, izleme devam ediyor.", "👁 A temporary permission error was detected. Watching continues.") }
    static var watchClipboardFailed: String { pair("⚠️ İzleme kopyalama hatası", "⚠️ Watch mode could not copy text") }
    static var localImageOnly: String { pair("Yalnızca yerel görsel dosyaları destekleniyor.", "Only local image files are supported.") }
    static var localPDFOnly: String { pair("Yalnızca yerel PDF dosyaları destekleniyor.", "Only local PDF files are supported.") }
    static var unsupportedPath: String { pair("⚠️ Desteklenmeyen dosya yolu.", "⚠️ Unsupported file path.") }
    static var imageOpenFailed: String { pair("Görsel dosyası açılamadı veya desteklenmiyor.", "The image file could not be opened or is unsupported.") }
    static var imageTooLarge: String { pair("Görsel çözünürlüğü çok yüksek. Daha küçük bir dosya kullanın.", "The image resolution is too high. Use a smaller file.") }
    static var unknownFailure: String { pair("❌ Bilinmeyen hata", "❌ Unknown error") }
    static var clipboardImageMissing: String { pair("Panoda okunabilir bir görsel yok.", "The clipboard does not contain a readable image.") }
    static var clipboardImageMissingStatus: String { pair("⚠️ Panoda okunabilir bir görsel yok.", "⚠️ The clipboard does not contain a readable image.") }
    static var historySaveFailed: String { pair("⚠️ Geçmiş diske şifrelenerek yazılamadı.", "⚠️ History could not be encrypted to disk.") }

    static func savedRegionMissing(_ name: String) -> String {
        format("Kayıtlı bölge bulunamadı: %@", "Saved region not found: %@", name)
    }

    static func savedSnippetMissing(_ name: String) -> String {
        format("Kayıtlı snippet bulunamadı: %@", "Saved snippet not found: %@", name)
    }

    static func profileOutputCopied(appName: String, preset: String) -> String {
        format("✅ %@ için %@ çıktısı kopyalandı", "✅ %@ — %@ output copied", appName, preset)
    }

    static func watchActive(mode: String) -> String {
        format("👁 İzleme aktif. %@ profiliyle yeni içerik otomatik kopyalanır.", "👁 Watching. New %@ content is copied automatically.", mode)
    }

    static func retryProgress(_ title: String, index: Int, total: Int) -> String {
        format("%@... (%d/%d)", "%@... (%d/%d)", title, index, total)
    }

    static func recognitionVariants(_ title: String, count: Int) -> String {
        format("%@... (%d varyant)", "%@... (%d variants)", title, count)
    }

    static func clipboardRecognition(_ title: String) -> String {
        format("%@... (panodaki görsel)", "%@... (clipboard image)", title)
    }

    static func fileRecognition(_ title: String) -> String {
        format("%@... (dosya)", "%@... (file)", title)
    }

    static func pdfPageRecognition(_ title: String, page: Int, total: Int) -> String {
        format("%@... (PDF %d/%d)", "%@... (PDF %d/%d)", title, page, total)
    }

    static func searchablePDFCreated(_ name: String) -> String {
        format("✅ Searchable PDF oluşturuldu: %@", "✅ Searchable PDF created: %@", name)
    }

    static func chooseWatchRegion(mode: String, preset: String) -> String {
        format("İzlenecek alanı seçin (%@ • %@)", "Choose a region to watch (%@ • %@)", mode, preset)
    }
}
