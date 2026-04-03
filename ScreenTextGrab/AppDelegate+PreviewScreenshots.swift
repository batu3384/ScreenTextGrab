import AppKit
import SwiftUI

@MainActor
extension AppDelegate {
    func configurePreviewState() {
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
                marketingVersion: (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.1.0",
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

    func configureMenuPanelPreviewState() {
        configurePreviewState()
        appState.statusMessage = L10n.pair("Hazır", "Ready")
        appState.launchAtLoginState = .disabled
        appState.watchState = .inactive
        appState.hotkeyDisplayLabel = HotkeyConfiguration.defaultValue.displayLabel
        appState.savedCaptureRegionQuickStartEnabled = false
        appState.activeSourceApp = nil
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

    func showPreview(for mode: ScreenshotLaunchMode) {
        switch mode {
        case .menuPanel:
            configureMenuPanelPreviewState()
            let previewSize = NSSize(width: 404, height: 1110)
            showPreviewWindow(
                title: "ScreenTextGrab",
                size: previewSize,
                styleMask: [.titled, .fullSizeContentView],
                isOpaque: false,
                backgroundColor: .clear,
                hasShadow: true,
                canBecomeKey: true
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

    func showPreviewWindow<Content: View>(
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
        if styleMask.contains(.fullSizeContentView) {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }
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
}
