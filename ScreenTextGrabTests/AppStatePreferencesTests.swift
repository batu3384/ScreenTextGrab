import XCTest
@testable import ScreenTextGrab

final class AppStatePreferencesTests: XCTestCase {
    func testAppStateLoadsPersistedHistoryAndLanguages() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let expectedHistory = [
            ClipboardHistoryEntry(
                text: "Kayitli metin",
                date: Date(timeIntervalSince1970: 123),
                captureMode: .code,
                contentKind: .barcode,
                source: .init(appName: "Safari", bundleIdentifier: "com.apple.Safari")
            )
        ]
        ClipboardHistoryStore.save(expectedHistory, defaults: defaults)
        CaptureModeStore.save(.subtitle, defaults: defaults)
        CaptureOutputPresetStore.save(.json, defaults: defaults)
        WatchConfigurationStore.save(
            WatchConfiguration(copyBehavior: .newLinesOnly, regexFilter: "Invoice #[0-9]+"),
            defaults: defaults
        )
        AppCaptureProfileStore.save(
            [
                AppCaptureProfile(
                    bundleIdentifier: "com.apple.dt.Xcode",
                    appName: "Xcode",
                    captureMode: .code,
                    outputPreset: .markdown,
                    ocrLanguageSelection: OCRLanguageSelection(automaticDetection: false, languages: [.english])
                )
            ],
            defaults: defaults
        )
        ClipboardHistoryExportFormatStore.save(.json, defaults: defaults)
        OCRLanguageSelectionStore.save(
            OCRLanguageSelection(automaticDetection: false, languages: [.turkish]),
            defaults: defaults
        )

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)

        XCTAssertEqual(appState.copyHistory, expectedHistory)
        XCTAssertEqual(appState.lastCopiedText, "Kayitli metin")
        XCTAssertEqual(appState.captureMode, .subtitle)
        XCTAssertEqual(appState.captureOutputPreset, .json)
        XCTAssertEqual(appState.watchConfiguration.copyBehavior, .newLinesOnly)
        XCTAssertEqual(appState.watchConfiguration.regexFilter, "Invoice #[0-9]+")
        XCTAssertEqual(appState.appProfiles.first?.bundleIdentifier, "com.apple.dt.Xcode")
        XCTAssertEqual(appState.historyExportFormat, .json)
        XCTAssertFalse(appState.ocrLanguageSelection.automaticDetection)
        XCTAssertEqual(appState.ocrLanguageSelection.languages, [.turkish])
    }

    func testRecordCopiedTextPersistsHistory() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        appState.recordCopiedText("Yeni kayit")

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertEqual(restored.copyHistory.map(\.text), ["Yeni kayit"])
        XCTAssertEqual(restored.lastCopiedText, "Yeni kayit")
    }

    func testSetOCRLanguageRejectsEmptySelection() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertTrue(appState.setOCRLanguage(.english, enabled: false))
        XCTAssertFalse(appState.setOCRLanguage(.turkish, enabled: false))
        XCTAssertEqual(appState.ocrLanguageSelection.languages, [.turkish])
    }

    func testSetOCRAutomaticDetectionPersistsSelection() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        appState.setOCRAutomaticDetection(false)
        _ = appState.setOCRLanguage(.english, enabled: false)

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertFalse(restored.ocrLanguageSelection.automaticDetection)
        XCTAssertEqual(restored.ocrLanguageSelection.languages, [.turkish])
    }

    func testSetCaptureModePersistsSelection() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        appState.setCaptureMode(.table)

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertEqual(restored.captureMode, .table)
    }

    func testSetCaptureOutputPresetPersistsSelection() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        appState.setCaptureOutputPreset(.markdown)

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertEqual(restored.captureOutputPreset, .markdown)
    }

    func testWatchConfigurationPersists() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        appState.setWatchCopyBehavior(.newLinesOnly)
        XCTAssertTrue(appState.setWatchRegexFilter("Invoice #[0-9]+"))

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertEqual(restored.watchConfiguration.copyBehavior, .newLinesOnly)
        XCTAssertEqual(restored.watchConfiguration.regexFilter, "Invoice #[0-9]+")
    }

    func testAppProfilePersistsAndCanBeResolved() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        appState.setCaptureMode(.table)
        appState.setCaptureOutputPreset(.json)
        _ = appState.setOCRLanguage(.english, enabled: true)
        appState.upsertAppProfile(bundleIdentifier: "com.apple.Safari", appName: "Safari")

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        let profile = restored.appProfile(for: "com.apple.Safari")
        XCTAssertEqual(profile?.captureMode, .table)
        XCTAssertEqual(profile?.outputPreset, .json)
        XCTAssertEqual(profile?.appName, "Safari")
    }

    func testAppStateSeedsRecommendedOfficeProfilesWhenNoProfilesPersisted() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)

        let excelProfile = appState.appProfile(for: "com.microsoft.Excel")
        let numbersProfile = appState.appProfile(for: "com.apple.iWork.Numbers")
        let wordProfile = appState.appProfile(for: "com.microsoft.Word")
        let pagesProfile = appState.appProfile(for: "com.apple.iWork.Pages")

        XCTAssertEqual(excelProfile?.captureMode, .table)
        XCTAssertEqual(excelProfile?.outputPreset, .office)
        XCTAssertEqual(numbersProfile?.captureMode, .table)
        XCTAssertEqual(numbersProfile?.outputPreset, .office)
        XCTAssertEqual(wordProfile?.captureMode, .standard)
        XCTAssertEqual(wordProfile?.outputPreset, .office)
        XCTAssertEqual(pagesProfile?.captureMode, .standard)
        XCTAssertEqual(pagesProfile?.outputPreset, .office)
    }

    func testUpsertingRecommendedProfileOverridesSeededDefaults() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        appState.setCaptureMode(.code)
        appState.setCaptureOutputPreset(.markdown)
        appState.setOCRAutomaticDetection(false)
        _ = appState.setOCRLanguage(.english, enabled: true)
        appState.upsertAppProfile(bundleIdentifier: "com.microsoft.Word", appName: "Microsoft Word")

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        let wordProfile = restored.appProfile(for: "com.microsoft.Word")

        XCTAssertEqual(wordProfile?.captureMode, .code)
        XCTAssertEqual(wordProfile?.outputPreset, .markdown)
        XCTAssertEqual(wordProfile?.ocrLanguageSelection.automaticDetection, false)
        XCTAssertEqual(wordProfile?.ocrLanguageSelection.languages, [.turkish, .english])
    }

    func testRemovingSeededProfilePersistsUserChoice() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        guard let excelProfile = appState.appProfile(for: "com.microsoft.Excel") else {
            XCTFail("Expected seeded Excel profile")
            return
        }

        appState.removeAppProfile(excelProfile)

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertNil(restored.appProfile(for: "com.microsoft.Excel"))
    }

    func testSetHistoryExportFormatPersistsSelection() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        appState.setHistoryExportFormat(.csv)

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertEqual(restored.historyExportFormat, .csv)
    }

    func testRemoveAndClearHistoryPersist() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let first = ClipboardHistoryEntry(text: "Bir", date: Date(timeIntervalSince1970: 10))
        let second = ClipboardHistoryEntry(text: "Iki", date: Date(timeIntervalSince1970: 20))
        ClipboardHistoryStore.save([first, second], defaults: defaults)

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        appState.removeHistoryEntry(first)
        XCTAssertEqual(appState.copyHistory.map(\.text), ["Iki"])

        appState.clearHistory()

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertTrue(restored.copyHistory.isEmpty)
        XCTAssertEqual(restored.lastCopiedText, "")
    }

    func testClipboardHistoryExportTextIncludesEntries() {
        let entries = [
            ClipboardHistoryEntry(text: "Birinci satir", date: Date(timeIntervalSince1970: 10)),
            ClipboardHistoryEntry(text: "Ikinci satir", date: Date(timeIntervalSince1970: 20))
        ]

        let output = ClipboardHistoryStore.exportText(
            entries,
            generatedAt: Date(timeIntervalSince1970: 30)
        )

        XCTAssertTrue(output.contains("ScreenTextGrab Geçmişi"))
        XCTAssertTrue(output.contains("Birinci satir"))
        XCTAssertTrue(output.contains("Ikinci satir"))
    }

    func testClipboardHistoryExportJSONIncludesMetadata() {
        let entries = [
            ClipboardHistoryEntry(
                text: "Kod parcasi",
                date: Date(timeIntervalSince1970: 10),
                captureMode: .code,
                outputPreset: .markdown,
                contentKind: .text,
                rawText: "let value = 42",
                source: .init(appName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode")
            )
        ]

        let output = ClipboardHistoryStore.export(entries, format: .json)

        XCTAssertTrue(output.contains("\"captureMode\""))
        XCTAssertTrue(output.contains("\"outputPreset\""))
        XCTAssertTrue(output.contains("\"rawText\""))
        XCTAssertTrue(output.contains("\"source\""))
        XCTAssertTrue(output.contains("com.apple.dt.Xcode"))
    }

    func testClipboardHistoryEntryMatchesSearchAcrossMetadata() {
        let entry = ClipboardHistoryEntry(
            text: "Merhaba dunya",
            date: Date(timeIntervalSince1970: 10),
            captureMode: .table,
            outputPreset: .json,
            contentKind: .barcode,
            rawText: "https://example.com",
            source: .init(appName: "Safari", bundleIdentifier: "com.apple.Safari")
        )

        XCTAssertTrue(entry.matches(query: "Safari"))
        XCTAssertTrue(entry.matches(query: "Tablo"))
        XCTAssertTrue(entry.matches(query: "Barkod"))
        XCTAssertTrue(entry.matches(query: "JSON"))
        XCTAssertTrue(entry.matches(query: "example.com"))
        XCTAssertFalse(entry.matches(query: "Terminal"))
    }

    func testLaunchPanelPolicyShowsWindowForForegroundLaunch() {
        XCTAssertTrue(
            LaunchPanelPresentationPolicy.shouldPresentOnStartup(
                isAppActive: true,
                frontmostBundleIdentifier: "dev.screentextgrab.app",
                ownBundleIdentifier: "dev.screentextgrab.app"
            )
        )
    }

    func testLaunchPanelPolicySuppressesWindowForBackgroundLaunch() {
        XCTAssertFalse(
            LaunchPanelPresentationPolicy.shouldPresentOnStartup(
                isAppActive: false,
                frontmostBundleIdentifier: "com.apple.finder",
                ownBundleIdentifier: "dev.screentextgrab.app"
            )
        )
    }

    func testInstalledAppLocatorRecognizesApplicationsRoots() {
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Users/example/Applications", isDirectory: true)
        ]

        XCTAssertTrue(
            InstalledAppLocator.isInstalledAppURL(
                URL(fileURLWithPath: "/Applications/ScreenTextGrab.app"),
                searchRoots: roots
            )
        )
        XCTAssertTrue(
            InstalledAppLocator.isInstalledAppURL(
                URL(fileURLWithPath: "/Users/example/Applications/ScreenTextGrab.app"),
                searchRoots: roots
            )
        )
        XCTAssertFalse(
            InstalledAppLocator.isInstalledAppURL(
                URL(fileURLWithPath: "/Users/example/Downloads/ScreenTextGrab.app"),
                searchRoots: roots
            )
        )
    }

    func testPreferredInstalledCopyIgnoresOlderInstalledBuild() throws {
        let sandbox = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let installedRoot = sandbox.appendingPathComponent("Applications", isDirectory: true)
        let downloadsRoot = sandbox.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: installedRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: downloadsRoot, withIntermediateDirectories: true)

        _ = try makeFakeApp(
            named: "ScreenTextGrab.app",
            version: "2",
            bundleIdentifier: "dev.screentextgrab.app",
            in: installedRoot
        )
        let downloadedApp = try makeFakeApp(
            named: "ScreenTextGrab.app",
            version: "3",
            bundleIdentifier: "dev.screentextgrab.app",
            in: downloadsRoot
        )

        let preferred = InstalledAppLocator.preferredInstalledCopy(
            currentURL: downloadedApp,
            bundleIdentifier: "dev.screentextgrab.app",
            searchRoots: [installedRoot]
        )

        XCTAssertNil(preferred)
    }

    func testPreferredInstalledCopyFindsMatchingInstalledBundle() throws {
        let sandbox = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let installedRoot = sandbox.appendingPathComponent("Applications", isDirectory: true)
        let downloadsRoot = sandbox.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: installedRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: downloadsRoot, withIntermediateDirectories: true)

        let installedApp = try makeFakeApp(
            named: "ScreenTextGrab Pro.app",
            version: "4",
            bundleIdentifier: "dev.screentextgrab.app",
            in: installedRoot
        )
        let downloadedApp = try makeFakeApp(
            named: "ScreenTextGrab.app",
            version: "4",
            bundleIdentifier: "dev.screentextgrab.app",
            in: downloadsRoot
        )

        let preferred = InstalledAppLocator.preferredInstalledCopy(
            currentURL: downloadedApp,
            bundleIdentifier: "dev.screentextgrab.app",
            searchRoots: [installedRoot]
        )

        XCTAssertEqual(preferred?.lastPathComponent, installedApp.lastPathComponent)
    }

    func testPreferredTableSourceTextPrefersTabSeparatedRawValue() {
        let entry = ClipboardHistoryEntry(
            text: "| Urun | Fiyat |\n| --- | --- |\n| Elma | 12.99 |",
            date: Date(timeIntervalSince1970: 10),
            captureMode: .table,
            outputPreset: .markdown,
            rawText: "Urun\tFiyat\nElma\t12.99"
        )

        XCTAssertEqual(entry.preferredTableSourceText, "Urun\tFiyat\nElma\t12.99")
    }

    func testTableReviewDocumentParsesMarkdownTable() {
        let document = TableReviewDocument(
            sourceText: """
            | Urun | Fiyat |
            | --- | --- |
            | Elma | 12.99 |
            | Armut | 9.50 |
            """
        )

        XCTAssertEqual(
            document.rows,
            [
                ["Urun", "Fiyat"],
                ["Elma", "12.99"],
                ["Armut", "9.50"]
            ]
        )
    }

    func testTableReviewDocumentTrimsEmptyEdges() {
        var document = TableReviewDocument(
            rows: [
                ["", "", ""],
                ["", "Urun", "Fiyat"],
                ["", "Elma", "12.99"],
                ["", "", ""]
            ]
        )

        document.trimEmptyEdges()

        XCTAssertEqual(
            document.rows,
            [
                ["Urun", "Fiyat"],
                ["Elma", "12.99"]
            ]
        )
    }

    private var defaultsSuiteName: String {
        "ScreenTextGrab.AppStatePreferencesTests"
    }

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        return defaults
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeFakeApp(
        named appName: String,
        version: String,
        bundleIdentifier: String,
        in root: URL
    ) throws -> URL {
        let appURL = root.appendingPathComponent(appName, isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleVersion": version,
            "CFBundlePackageType": "APPL",
            "CFBundleName": appName.replacingOccurrences(of: ".app", with: "")
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL)

        return appURL
    }
}
