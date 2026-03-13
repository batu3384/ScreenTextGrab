import Foundation

enum L10n {
    static let controlsTitle = NSLocalizedString("controls.title", value: "Kontroller", comment: "")
    static let settingsTitle = NSLocalizedString("settings.title", value: "ScreenTextGrab Ayarları", comment: "")
    static let settingsSubtitle = NSLocalizedString("settings.subtitle", value: "Kısayol, izinler, OCR dili ve geçmiş yönetimini buradan düzenle.", comment: "")

    static let settingsTabGeneral = NSLocalizedString("settings.tab.general", value: "Genel", comment: "")
    static let settingsTabOCR = NSLocalizedString("settings.tab.ocr", value: "OCR", comment: "")
    static let settingsTabDiagnostics = NSLocalizedString("settings.tab.diagnostics", value: "Tanı", comment: "")
    static let settingsTabHistory = NSLocalizedString("settings.tab.history", value: "Geçmiş", comment: "")

    static let actionSettings = NSLocalizedString("action.settings", value: "Ayarlar", comment: "")
    static let actionRefresh = NSLocalizedString("action.refresh", value: "Yenile", comment: "")
    static let actionAllow = NSLocalizedString("action.allow", value: "İzin Ver", comment: "")
    static let actionSystemSettings = NSLocalizedString("action.system_settings", value: "Sistem Ayarları", comment: "")
    static let actionRequestPermission = NSLocalizedString("action.request_permission", value: "İzin İste", comment: "")
    static let actionDiagnostics = NSLocalizedString("action.diagnostics", value: "Tanı", comment: "")
    static let actionCopy = NSLocalizedString("action.copy", value: "Kopyala", comment: "")
    static let actionDelete = NSLocalizedString("action.delete", value: "Sil", comment: "")
    static let actionExport = NSLocalizedString("action.export", value: "Dışa Aktar", comment: "")
    static let actionClear = NSLocalizedString("action.clear", value: "Temizle", comment: "")
    static let actionSupportBundle = NSLocalizedString("action.support_bundle", value: "Support Paketi", comment: "")
    static let actionCopyDiagnostics = NSLocalizedString("action.copy_diagnostics", value: "Tanıyı Kopyala", comment: "")
    static let actionLoginItems = NSLocalizedString("action.login_items", value: "Giriş Öğeleri", comment: "")
    static let actionDefault = NSLocalizedString("action.default", value: "Varsayılan", comment: "")
    static let actionChange = NSLocalizedString("action.change", value: "Değiştir", comment: "")
    static let actionCancel = NSLocalizedString("action.cancel", value: "İptal", comment: "")
    static let ocrAutomaticLanguage = NSLocalizedString("ocr.automatic_language", value: "Dili otomatik algıla", comment: "")

    static let accessibilityQuitApp = NSLocalizedString("accessibility.quit_app", value: "Uygulamadan çık", comment: "")
    static let accessibilityResetHotkey = NSLocalizedString("accessibility.reset_hotkey", value: "Kısayolu varsayılana döndür", comment: "")
    static let accessibilityLaunchAtLoginToggle = NSLocalizedString("accessibility.launch_at_login_toggle", value: "Açılışta başlat", comment: "")
    static let accessibilityCaptureMode = NSLocalizedString("accessibility.capture_mode", value: "Yakalama modu", comment: "")
    static let accessibilityOCRLanguage = NSLocalizedString("accessibility.ocr_language", value: "OCR dili", comment: "")
    static let accessibilityAutomaticLanguage = NSLocalizedString("accessibility.automatic_language", value: "Dili otomatik algıla", comment: "")
}
