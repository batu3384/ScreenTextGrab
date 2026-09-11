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

    static var usesChinese: Bool {
        languageIdentifier.hasPrefix("zh")
    }

    static func pair(_ tr: String, _ en: String) -> String {
        if usesChinese { return en }
        return usesEnglish ? en : tr
    }

    static func triple(_ tr: String, _ en: String, _ zh: String) -> String {
        if usesChinese { return zh }
        return usesEnglish ? en : tr
    }

    static func format(_ tr: String, _ en: String, _ arguments: CVarArg...) -> String {
        let format = pair(tr, en)
        return String(format: format, locale: Locale.current, arguments: arguments)
    }

    static var controlsTitle: String { triple("Kontroller", "Controls", "控制") }
    static var settingsTitle: String { triple("ScreenTextGrab Ayarları", "ScreenTextGrab Settings", "ScreenTextGrab 设置") }
    static var settingsSubtitle: String { triple("Kısayol, izinler, OCR dili ve geçmiş yönetimini buradan düzenle.", "Manage shortcuts, permissions, OCR language, and history here.", "在此管理快捷键、权限、OCR 语言和历史记录。") }

    static var settingsTabGeneral: String { triple("Genel", "General", "通用") }
    static var settingsTabOCR: String { "OCR" }
    static var settingsTabDiagnostics: String { triple("Tanı", "Diagnostics", "诊断") }
    static var settingsTabHistory: String { triple("Geçmiş", "History", "历史记录") }

    static var actionSettings: String { triple("Ayarlar", "Settings", "设置") }
    static var actionRefresh: String { triple("Yenile", "Refresh", "刷新") }
    static var actionClipboardImage: String { triple("Panodaki Görseli Oku", "Read Clipboard Image", "读取剪贴板图片") }
    static var actionImageFile: String { triple("Görsel Dosyası Oku", "Read Image File", "读取图片文件") }
    static var actionPDFFile: String { triple("PDF Oku", "Read PDF", "读取 PDF") }
    static var actionSearchablePDF: String { "Searchable PDF" }
    static var actionCheckForUpdates: String { triple("Güncellemeleri Kontrol Et", "Check for Updates", "检查更新") }
    static var actionCheckingForUpdates: String { triple("Kontrol Ediliyor...", "Checking...", "检查中...") }
    static var actionDownloadingUpdate: String { triple("İndiriliyor...", "Downloading...", "下载中...") }
    static var actionRestartToUpdate: String { triple("Yeniden Başlat ve Güncelle", "Restart & Update", "重启并更新") }
    static var actionRetryUpdate: String { triple("Tekrar Dene", "Try Again", "重试") }
    static var actionUpToDate: String { triple("Güncel", "Up to Date", "已是最新") }
    static var actionAllow: String { triple("İzin Ver", "Allow Access", "允许访问") }
    static var actionSystemSettings: String { triple("Sistem Ayarları", "System Settings", "系统设置") }
    static var actionRequestPermission: String { triple("İzin İste", "Request Access", "请求权限") }
    static var actionDiagnostics: String { triple("Tanı", "Diagnostics", "诊断") }
    static var actionCopy: String { triple("Kopyala", "Copy", "复制") }
    static var actionDelete: String { triple("Sil", "Delete", "删除") }
    static var actionExport: String { triple("Dışa Aktar", "Export", "导出") }
    static var actionClear: String { triple("Temizle", "Clear", "清除") }
    static var actionSupportBundle: String { triple("Support Paketi", "Support Bundle", "支持包") }
    static var actionCopyDiagnostics: String { triple("Tanıyı Kopyala", "Copy Diagnostics", "复制诊断信息") }
    static var actionLoginItems: String { triple("Giriş Öğeleri", "Login Items", "登录项") }
    static var actionDefault: String { triple("Varsayılan", "Default", "默认") }
    static var actionChange: String { triple("Değiştir", "Change", "更改") }
    static var actionCancel: String { triple("İptal", "Cancel", "取消") }
    static var actionOpenApplicationsFolder: String { triple("Applications Klasörünü Aç", "Open Applications Folder", "打开应用程序文件夹") }
    static var actionContinue: String { triple("Devam Et", "Continue", "继续") }
    static var ocrAutomaticLanguage: String { triple("Dili otomatik algıla", "Automatically detect language", "自动检测语言") }

    static var installRootUnavailable: String { pair("Applications klasöründe yazılabilir bir hedef bulunamadı.", "No writable install destination was found in Applications.") }
    static var installCopyFailedPrefix: String { pair("Uygulama Applications klasörüne taşınamadı:", "The app could not be moved to Applications:") }
    static var installRelocatingStatus: String { pair("⚠️ Uygulama Applications klasörüne taşınıyor...", "⚠️ Moving the app to Applications...") }
    static var installOpenFromApplicationsStatus: String { pair("⚠️ Uygulamayı Applications klasöründen aç", "⚠️ Open the app from Applications") }
    static var installOpeningInstalledCopyStatus: String { pair("⚠️ Yüklü uygulama kopyası açılıyor...", "⚠️ Opening the installed app copy...") }
    static var installAlertTitle: String { pair("Uygulamayı Applications klasöründen aç", "Open the app from Applications") }
    static var installAlertBody: String { pair("ScreenTextGrab izinleri ve Spotlight kaydını stabil tutmak için Applications klasöründen çalışmalıdır.", "ScreenTextGrab should run from Applications so permissions and Spotlight registration stay stable.") }

    static var accessibilityQuitApp: String { triple("Uygulamadan çık", "Quit app", "退出应用") }
    static var accessibilityCheckForUpdates: String { triple("Güncellemeleri kontrol et", "Check for updates", "检查更新") }
    static var accessibilityResetHotkey: String { triple("Kısayolu varsayılana döndür", "Reset shortcut to default", "重置快捷键为默认") }
    static var accessibilityLaunchAtLoginToggle: String { triple("Açılışta başlat", "Launch at login", "开机启动") }
    static var accessibilityCaptureMode: String { triple("Yakalama modu", "Capture mode", "捕获模式") }
    static var accessibilityOCRLanguage: String { triple("OCR dili", "OCR language", "OCR 语言") }
    static var accessibilityAutomaticLanguage: String { triple("Dili otomatik algıla", "Automatically detect language", "自动检测语言") }
    static var accessibilityInterfaceLanguage: String { triple("Arayüz dili", "Interface language", "界面语言") }
}
