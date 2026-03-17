import AppKit
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
        SavedCaptureRegionStore.save(
            [
                SavedCaptureRegion(
                    name: "Safari • Tablo",
                    screenRect: CGRect(x: 20, y: 30, width: 240, height: 120),
                    preferredDisplayID: 77,
                    source: .init(appName: "Safari", bundleIdentifier: "com.apple.Safari"),
                    sessionConfiguration: CaptureSessionConfiguration(
                        captureMode: .table,
                        outputPreset: .office,
                        ocrLanguageSelection: OCRLanguageSelection(automaticDetection: false, languages: [.english]),
                        profileName: "Safari"
                    )
                )
            ],
            defaults: defaults
        )
        SavedSnippetStore.save(
            [
                SavedSnippet(
                    name: "Fiyat listesi",
                    text: "Urun\tFiyat\nKalem\t12",
                    rawText: "Urun\tFiyat\nKalem\t12",
                    captureMode: .table,
                    outputPreset: .office,
                    contentKind: .text,
                    ocrConfidence: 0.91,
                    source: .init(appName: "Safari", bundleIdentifier: "com.apple.Safari")
                )
            ],
            defaults: defaults
        )
        ClipboardHistoryExportFormatStore.save(.json, defaults: defaults)
        OCRLanguageSelectionStore.save(
            OCRLanguageSelection(automaticDetection: false, languages: [.turkish]),
            defaults: defaults
        )
        InterfaceLanguageStore.save(.english, defaults: defaults)

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)

        XCTAssertEqual(appState.copyHistory, expectedHistory)
        XCTAssertEqual(appState.lastCopiedText, "Kayitli metin")
        XCTAssertEqual(appState.captureMode, .subtitle)
        XCTAssertEqual(appState.captureOutputPreset, .json)
        XCTAssertEqual(appState.watchConfiguration.copyBehavior, .newLinesOnly)
        XCTAssertEqual(appState.watchConfiguration.regexFilter, "Invoice #[0-9]+")
        XCTAssertEqual(appState.appProfiles.first?.bundleIdentifier, "com.apple.dt.Xcode")
        XCTAssertEqual(appState.savedCaptureRegions.first?.name, "Safari • Tablo")
        XCTAssertEqual(appState.savedSnippets.first?.name, "Fiyat listesi")
        XCTAssertEqual(appState.historyExportFormat, .json)
        XCTAssertFalse(appState.ocrLanguageSelection.automaticDetection)
        XCTAssertEqual(appState.ocrLanguageSelection.languages, [.turkish])
        XCTAssertEqual(appState.interfaceLanguage, .english)
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

    func testPinnedHistoryEntryPersistsAcrossReload() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        appState.recordCopiedText("Sabitlenecek kayit")
        guard let entry = appState.copyHistory.first else {
            XCTFail("Expected history entry")
            return
        }

        appState.togglePinnedHistoryEntry(entry)

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertEqual(restored.copyHistory.first?.isPinned, true)
        XCTAssertEqual(restored.pinnedHistoryCount, 1)
    }

    func testRecordCopiedTextPreservesPinnedStateForDuplicateEntry() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        appState.recordCopiedText("Ayni metin", captureMode: .table, outputPreset: .office)
        guard let firstEntry = appState.copyHistory.first else {
            XCTFail("Expected initial entry")
            return
        }

        appState.togglePinnedHistoryEntry(firstEntry)
        appState.recordCopiedText("Ayni metin", captureMode: .table, outputPreset: .office)

        XCTAssertEqual(appState.copyHistory.count, 1)
        XCTAssertEqual(appState.copyHistory.first?.isPinned, true)
    }

    func testRecordCopiedTextPersistsOCRConfidence() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        appState.recordCopiedText("Dusuk guvenli kayit", ocrConfidence: 0.42)

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertEqual(restored.copyHistory.first?.ocrConfidence ?? 0, 0.42, accuracy: 0.0001)
        XCTAssertEqual(restored.copyHistory.first?.confidenceIndicator, .low)
    }

    func testClipboardHistoryEntryComputesConfidenceIndicator() {
        let lowEntry = ClipboardHistoryEntry(
            text: "Zor okunan metin",
            date: Date(),
            ocrConfidence: 0.41
        )
        let mediumEntry = ClipboardHistoryEntry(
            text: "Kontrol edilebilir metin",
            date: Date(),
            ocrConfidence: 0.70
        )
        let highEntry = ClipboardHistoryEntry(
            text: "Net metin",
            date: Date(),
            ocrConfidence: 0.91
        )

        XCTAssertEqual(lowEntry.confidenceIndicator, .low)
        XCTAssertEqual(mediumEntry.confidenceIndicator, .medium)
        XCTAssertEqual(highEntry.confidenceIndicator, .high)
    }

    func testClipboardHistoryStoreOrdersPinnedEntriesFirstForDisplay() {
        let now = Date()
        let history = [
            ClipboardHistoryEntry(text: "Yeni", date: now),
            ClipboardHistoryEntry(text: "Eski Sabit", date: now.addingTimeInterval(-3600), isPinned: true),
            ClipboardHistoryEntry(text: "Yeni Sabit", date: now.addingTimeInterval(-60), isPinned: true)
        ]

        XCTAssertEqual(
            ClipboardHistoryStore.orderedForDisplay(history).map(\.text),
            ["Yeni Sabit", "Eski Sabit", "Yeni"]
        )
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

    func testSetInterfaceLanguagePersistsSelection() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        appState.setInterfaceLanguage(.english)

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertEqual(restored.interfaceLanguage, .english)
    }

    func testL10nUsesStoredInterfaceLanguagePreference() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        defaults.set(["tr"], forKey: "AppleLanguages")

        InterfaceLanguageStore.save(.english, defaults: defaults)
        XCTAssertEqual(
            L10n.resolvedLanguageIdentifier(
                defaults: defaults,
                environment: [:],
                preferredLanguages: ["tr"]
            ),
            "en"
        )

        InterfaceLanguageStore.save(.turkish, defaults: defaults)
        XCTAssertEqual(
            L10n.resolvedLanguageIdentifier(
                defaults: defaults,
                environment: [:],
                preferredLanguages: ["en"]
            ),
            "tr"
        )

        InterfaceLanguageStore.save(.system, defaults: defaults)
        XCTAssertEqual(
            L10n.resolvedLanguageIdentifier(
                defaults: defaults,
                environment: [:],
                preferredLanguages: ["tr"]
            ),
            "tr"
        )
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

    func testActiveAppProfileSuggestionUsesTrackedProfileWhenCurrentSettingsDiffer() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        appState.setCaptureMode(.code)
        appState.setCaptureOutputPreset(.markdown)
        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel")
        )

        let suggestion = appState.activeAppProfileSuggestion

        XCTAssertEqual(suggestion?.source.appName, "Microsoft Excel")
        XCTAssertEqual(suggestion?.profile.captureMode, .table)
        XCTAssertEqual(suggestion?.profile.outputPreset, .office)
    }

    func testActiveAppProfileSuggestionHidesWhenCurrentSettingsAlreadyMatchProfile() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        appState.setCaptureMode(.table)
        appState.setCaptureOutputPreset(.office)
        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel")
        )

        XCTAssertNil(appState.activeAppProfileSuggestion)
    }

    func testActiveAppProfilePanelAutoSyncAppliesTrackedProfileWhenEnabled() {
        let appState = AppState(persistsUserPreferences: false)
        appState.appProfiles = [
            AppCaptureProfile(
                bundleIdentifier: "com.microsoft.Excel",
                appName: "Microsoft Excel",
                captureMode: .table,
                outputPreset: .office,
                ocrLanguageSelection: .defaultValue
            )
        ]
        appState.setCaptureMode(.code)
        appState.setCaptureOutputPreset(.markdown)
        appState.setAppProfilePanelAutoSyncEnabled(true)

        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel")
        )

        XCTAssertEqual(appState.captureMode, .table)
        XCTAssertEqual(appState.captureOutputPreset, .office)
        XCTAssertNil(appState.activeAppProfileSuggestion)
    }

    func testActiveAppProfilePanelAutoSyncDoesNotApplyProfileWhenDisabled() {
        let appState = AppState(persistsUserPreferences: false)
        appState.appProfiles = [
            AppCaptureProfile(
                bundleIdentifier: "com.microsoft.Excel",
                appName: "Microsoft Excel",
                captureMode: .table,
                outputPreset: .office,
                ocrLanguageSelection: .defaultValue
            )
        ]
        appState.setCaptureMode(.code)
        appState.setCaptureOutputPreset(.markdown)

        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel")
        )

        XCTAssertEqual(appState.captureMode, .code)
        XCTAssertEqual(appState.captureOutputPreset, .markdown)
        XCTAssertEqual(appState.activeAppProfileSuggestion?.profile.outputPreset, .office)
    }

    func testActiveSavedCaptureRegionSuggestionUsesMatchingActiveAppRegions() {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedCaptureRegions = [
            SavedCaptureRegion(
                name: "Safari • Tablo",
                screenRect: CGRect(x: 20, y: 30, width: 240, height: 120),
                preferredDisplayID: 77,
                source: .init(appName: "Safari", bundleIdentifier: "com.apple.Safari"),
                sessionConfiguration: CaptureSessionConfiguration(
                    captureMode: .table,
                    outputPreset: .office,
                    ocrLanguageSelection: .defaultValue,
                    profileName: "Safari"
                ),
                updatedAt: Date(timeIntervalSince1970: 20)
            ),
            SavedCaptureRegion(
                name: "Safari • Kod",
                screenRect: CGRect(x: 40, y: 50, width: 220, height: 160),
                preferredDisplayID: 77,
                source: .init(appName: "Safari", bundleIdentifier: "com.apple.Safari"),
                sessionConfiguration: CaptureSessionConfiguration(
                    captureMode: .code,
                    outputPreset: .markdown,
                    ocrLanguageSelection: .defaultValue,
                    profileName: "Safari"
                ),
                updatedAt: Date(timeIntervalSince1970: 10)
            ),
            SavedCaptureRegion(
                name: "Xcode • Kod",
                screenRect: CGRect(x: 90, y: 70, width: 280, height: 180),
                preferredDisplayID: 91,
                source: .init(appName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
                sessionConfiguration: CaptureSessionConfiguration(
                    captureMode: .code,
                    outputPreset: .markdown,
                    ocrLanguageSelection: .defaultValue,
                    profileName: "Xcode"
                ),
                updatedAt: Date(timeIntervalSince1970: 30)
            )
        ]
        appState.updateActiveSourceApp(
            .init(appName: "Safari", bundleIdentifier: "com.apple.Safari")
        )

        let suggestion = appState.activeSavedCaptureRegionSuggestion

        XCTAssertEqual(suggestion?.source.appName, "Safari")
        XCTAssertEqual(suggestion?.primaryRegion.name, "Safari • Tablo")
        XCTAssertEqual(suggestion?.regionCount, 2)
        XCTAssertEqual(suggestion?.matchKind, .application)
    }

    func testActiveSavedCaptureRegionSuggestionHidesWhenNoMatchingRegionExists() {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedCaptureRegions = [
            SavedCaptureRegion(
                name: "Xcode • Kod",
                screenRect: CGRect(x: 90, y: 70, width: 280, height: 180),
                preferredDisplayID: 91,
                source: .init(appName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
                sessionConfiguration: CaptureSessionConfiguration(
                    captureMode: .code,
                    outputPreset: .markdown,
                    ocrLanguageSelection: .defaultValue,
                    profileName: "Xcode"
                )
            )
        ]
        appState.updateActiveSourceApp(
            .init(appName: "Safari", bundleIdentifier: "com.apple.Safari")
        )

        XCTAssertNil(appState.activeSavedCaptureRegionSuggestion)
    }

    func testActiveSavedCaptureRegionSuggestionPrefersMatchingWindowTitle() {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedCaptureRegions = [
            SavedCaptureRegion(
                name: "Safari • Dokumantasyon",
                screenRect: CGRect(x: 20, y: 30, width: 240, height: 120),
                preferredDisplayID: 77,
                source: .init(
                    appName: "Safari",
                    bundleIdentifier: "com.apple.Safari",
                    windowTitle: "OpenAI Docs"
                ),
                sessionConfiguration: CaptureSessionConfiguration(
                    captureMode: .standard,
                    outputPreset: .cleaned,
                    ocrLanguageSelection: .defaultValue,
                    profileName: "Safari"
                ),
                updatedAt: Date(timeIntervalSince1970: 10)
            ),
            SavedCaptureRegion(
                name: "Safari • Kanban",
                screenRect: CGRect(x: 40, y: 50, width: 220, height: 160),
                preferredDisplayID: 77,
                source: .init(
                    appName: "Safari",
                    bundleIdentifier: "com.apple.Safari",
                    windowTitle: "Proje Panosu"
                ),
                sessionConfiguration: CaptureSessionConfiguration(
                    captureMode: .table,
                    outputPreset: .office,
                    ocrLanguageSelection: .defaultValue,
                    profileName: "Safari"
                ),
                updatedAt: Date(timeIntervalSince1970: 20)
            )
        ]
        appState.updateActiveSourceApp(
            .init(
                appName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                windowTitle: "Proje Panosu"
            )
        )

        let suggestion = appState.activeSavedCaptureRegionSuggestion

        XCTAssertEqual(suggestion?.primaryRegion.name, "Safari • Kanban")
        XCTAssertEqual(suggestion?.regionCount, 1)
        XCTAssertEqual(suggestion?.totalAppMatchingRegions, 2)
        XCTAssertEqual(suggestion?.matchKind, .windowTitle("Proje Panosu"))
    }

    func testActiveSavedCaptureRegionSuggestionFallsBackToAppMatchWhenWindowTitleDoesNotMatch() {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedCaptureRegions = [
            SavedCaptureRegion(
                name: "Safari • Dokumantasyon",
                screenRect: CGRect(x: 20, y: 30, width: 240, height: 120),
                preferredDisplayID: 77,
                source: .init(
                    appName: "Safari",
                    bundleIdentifier: "com.apple.Safari",
                    windowTitle: "OpenAI Docs"
                ),
                sessionConfiguration: CaptureSessionConfiguration(
                    captureMode: .standard,
                    outputPreset: .cleaned,
                    ocrLanguageSelection: .defaultValue,
                    profileName: "Safari"
                ),
                updatedAt: Date(timeIntervalSince1970: 20)
            ),
            SavedCaptureRegion(
                name: "Safari • Kanban",
                screenRect: CGRect(x: 40, y: 50, width: 220, height: 160),
                preferredDisplayID: 77,
                source: .init(
                    appName: "Safari",
                    bundleIdentifier: "com.apple.Safari",
                    windowTitle: "Proje Panosu"
                ),
                sessionConfiguration: CaptureSessionConfiguration(
                    captureMode: .table,
                    outputPreset: .office,
                    ocrLanguageSelection: .defaultValue,
                    profileName: "Safari"
                ),
                updatedAt: Date(timeIntervalSince1970: 10)
            )
        ]
        appState.updateActiveSourceApp(
            .init(
                appName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                windowTitle: "Baska Sekme"
            )
        )

        let suggestion = appState.activeSavedCaptureRegionSuggestion

        XCTAssertEqual(suggestion?.primaryRegion.name, "Safari • Dokumantasyon")
        XCTAssertEqual(suggestion?.regionCount, 2)
        XCTAssertEqual(suggestion?.totalAppMatchingRegions, 2)
        XCTAssertEqual(suggestion?.matchKind, .application)
    }

    func testPrimaryQuickStartRegionUsesActiveSuggestionWhenEnabled() {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedCaptureRegions = [
            SavedCaptureRegion(
                name: "Safari • Tablo",
                screenRect: CGRect(x: 20, y: 30, width: 240, height: 120),
                preferredDisplayID: 77,
                source: .init(appName: "Safari", bundleIdentifier: "com.apple.Safari"),
                sessionConfiguration: CaptureSessionConfiguration(
                    captureMode: .table,
                    outputPreset: .office,
                    ocrLanguageSelection: .defaultValue,
                    profileName: "Safari"
                ),
                updatedAt: Date(timeIntervalSince1970: 20)
            )
        ]
        appState.updateActiveSourceApp(
            .init(appName: "Safari", bundleIdentifier: "com.apple.Safari")
        )

        XCTAssertEqual(appState.primaryQuickStartRegion?.name, "Safari • Tablo")
    }

    func testPrimaryQuickStartRegionIsNilWhenPreferenceDisabled() {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedCaptureRegions = [
            SavedCaptureRegion(
                name: "Safari • Tablo",
                screenRect: CGRect(x: 20, y: 30, width: 240, height: 120),
                preferredDisplayID: 77,
                source: .init(appName: "Safari", bundleIdentifier: "com.apple.Safari"),
                sessionConfiguration: CaptureSessionConfiguration(
                    captureMode: .table,
                    outputPreset: .office,
                    ocrLanguageSelection: .defaultValue,
                    profileName: "Safari"
                ),
                updatedAt: Date(timeIntervalSince1970: 20)
            )
        ]
        appState.updateActiveSourceApp(
            .init(appName: "Safari", bundleIdentifier: "com.apple.Safari")
        )
        appState.setSavedCaptureRegionQuickStartEnabled(false)

        XCTAssertNil(appState.primaryQuickStartRegion)
    }

    func testSavedCaptureRegionQuickStartPreferencePersists() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertTrue(appState.savedCaptureRegionQuickStartEnabled)

        appState.setSavedCaptureRegionQuickStartEnabled(false)

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertFalse(restored.savedCaptureRegionQuickStartEnabled)
    }

    func testActiveSavedSnippetCollectionSuggestionUsesMatchingActiveAppSnippets() {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedSnippets = [
            SavedSnippet(
                name: "Excel Toplam",
                text: "Toplam 42",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor", "Excel"],
                updatedAt: Date(timeIntervalSince1970: 30)
            ),
            SavedSnippet(
                name: "Excel Gelir",
                text: "Gelir Toplam",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"],
                updatedAt: Date(timeIntervalSince1970: 20)
            ),
            SavedSnippet(
                name: "Word Toplam",
                text: "Toplam",
                captureMode: .standard,
                outputPreset: .cleaned,
                source: .init(appName: "Microsoft Word", bundleIdentifier: "com.microsoft.Word"),
                tags: ["Rapor"],
                updatedAt: Date(timeIntervalSince1970: 40)
            )
        ]
        appState.savedSnippetCollections = [
            SavedSnippetCollection(
                name: "Excel Raporlari",
                selectedTag: "Rapor",
                searchQuery: "toplam",
                updatedAt: Date(timeIntervalSince1970: 10)
            ),
            SavedSnippetCollection(
                name: "Belgeler",
                selectedTag: "Belge",
                searchQuery: "",
                updatedAt: Date(timeIntervalSince1970: 50)
            )
        ]
        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel")
        )

        let suggestion = appState.activeSavedSnippetCollectionSuggestion

        XCTAssertEqual(suggestion?.collection.name, "Excel Raporlari")
        XCTAssertEqual(suggestion?.source.appName, "Microsoft Excel")
        XCTAssertEqual(suggestion?.snippetCount, 2)
        XCTAssertEqual(suggestion?.totalAppMatchingSnippets, 2)
        XCTAssertEqual(suggestion?.matchKind, .application)
    }

    func testActiveSavedSnippetCollectionSuggestionPrefersMatchingWindowTitle() {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedSnippets = [
            SavedSnippet(
                name: "Safari Docs",
                text: "API reference",
                captureMode: .standard,
                outputPreset: .cleaned,
                source: .init(
                    appName: "Safari",
                    bundleIdentifier: "com.apple.Safari",
                    windowTitle: "OpenAI Docs"
                ),
                tags: ["Docs"],
                updatedAt: Date(timeIntervalSince1970: 10)
            ),
            SavedSnippet(
                name: "Safari Pano",
                text: "Sprint backlog",
                captureMode: .standard,
                outputPreset: .cleaned,
                source: .init(
                    appName: "Safari",
                    bundleIdentifier: "com.apple.Safari",
                    windowTitle: "Proje Panosu"
                ),
                tags: ["Docs"],
                updatedAt: Date(timeIntervalSince1970: 20)
            )
        ]
        appState.savedSnippetCollections = [
            SavedSnippetCollection(
                name: "Safari Notlari",
                selectedTag: "Docs",
                searchQuery: "",
                updatedAt: Date(timeIntervalSince1970: 30)
            )
        ]
        appState.updateActiveSourceApp(
            .init(
                appName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                windowTitle: "Proje Panosu"
            )
        )

        let suggestion = appState.activeSavedSnippetCollectionSuggestion

        XCTAssertEqual(suggestion?.collection.name, "Safari Notlari")
        XCTAssertEqual(suggestion?.snippetCount, 1)
        XCTAssertEqual(suggestion?.totalAppMatchingSnippets, 2)
        XCTAssertEqual(suggestion?.matchKind, .windowTitle("Proje Panosu"))
    }

    func testActiveSavedSnippetCollectionSuggestionHidesWhenNoMatchingSnippetExists() {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedSnippets = [
            SavedSnippet(
                name: "Word Belge",
                text: "Sozlesme",
                captureMode: .standard,
                outputPreset: .cleaned,
                source: .init(appName: "Microsoft Word", bundleIdentifier: "com.microsoft.Word"),
                tags: ["Belge"]
            )
        ]
        appState.savedSnippetCollections = [
            SavedSnippetCollection(
                name: "Belgeler",
                selectedTag: "Belge",
                searchQuery: ""
            )
        ]
        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel")
        )

        XCTAssertNil(appState.activeSavedSnippetCollectionSuggestion)
    }

    func testActiveSavedSnippetSuggestionReturnsSingleMatchingSnippet() {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedSnippets = [
            SavedSnippet(
                name: "Excel Toplam",
                text: "Toplam 42",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"]
            )
        ]
        appState.savedSnippetCollections = [
            SavedSnippetCollection(
                name: "Excel Raporlari",
                selectedTag: "Rapor",
                searchQuery: "toplam"
            )
        ]
        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel")
        )

        let suggestion = appState.activeSavedSnippetSuggestion

        XCTAssertEqual(suggestion?.collection.name, "Excel Raporlari")
        XCTAssertEqual(suggestion?.snippet.name, "Excel Toplam")
        XCTAssertEqual(suggestion?.matchKind, .application)
    }

    func testActiveSavedSnippetSuggestionPrefersWindowMatchedSnippet() {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedSnippets = [
            SavedSnippet(
                name: "Safari Docs",
                text: "API reference",
                captureMode: .standard,
                outputPreset: .cleaned,
                source: .init(
                    appName: "Safari",
                    bundleIdentifier: "com.apple.Safari",
                    windowTitle: "OpenAI Docs"
                ),
                tags: ["Docs"]
            ),
            SavedSnippet(
                name: "Safari Pano",
                text: "Sprint backlog",
                captureMode: .standard,
                outputPreset: .cleaned,
                source: .init(
                    appName: "Safari",
                    bundleIdentifier: "com.apple.Safari",
                    windowTitle: "Proje Panosu"
                ),
                tags: ["Docs"],
                updatedAt: Date(timeIntervalSince1970: 20)
            )
        ]
        appState.savedSnippetCollections = [
            SavedSnippetCollection(
                name: "Safari Notlari",
                selectedTag: "Docs",
                searchQuery: "",
                updatedAt: Date(timeIntervalSince1970: 30)
            )
        ]
        appState.updateActiveSourceApp(
            .init(
                appName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                windowTitle: "Proje Panosu"
            )
        )

        let suggestion = appState.activeSavedSnippetSuggestion

        XCTAssertEqual(suggestion?.snippet.name, "Safari Pano")
        XCTAssertEqual(suggestion?.matchKind, .windowTitle("Proje Panosu"))
    }

    func testActiveSavedSnippetSuggestionReturnsNilWhenMultipleMatchesRemain() {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedSnippets = [
            SavedSnippet(
                name: "Excel Toplam",
                text: "Toplam 42",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"]
            ),
            SavedSnippet(
                name: "Excel Ozet",
                text: "Ozet 12",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"],
                updatedAt: Date(timeIntervalSince1970: 30)
            )
        ]
        appState.savedSnippetCollections = [
            SavedSnippetCollection(
                name: "Excel Raporlari",
                selectedTag: "Rapor",
                searchQuery: ""
            )
        ]
        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel")
        )

        XCTAssertNil(appState.activeSavedSnippetSuggestion)
    }

    func testActiveSavedSnippetSuggestionPrefersPreviouslyUsedSnippetWhenMultipleMatchesRemain() {
        let appState = AppState(persistsUserPreferences: false)
        let usedAt = Date(timeIntervalSince1970: 120)
        appState.savedSnippets = [
            SavedSnippet(
                name: "Excel Toplam",
                text: "Toplam 42",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"],
                updatedAt: Date(timeIntervalSince1970: 40),
                lastUsedAt: usedAt
            ),
            SavedSnippet(
                name: "Excel Ozet",
                text: "Ozet 12",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"],
                updatedAt: Date(timeIntervalSince1970: 90)
            )
        ]
        appState.savedSnippetCollections = [
            SavedSnippetCollection(
                name: "Excel Raporlari",
                selectedTag: "Rapor",
                searchQuery: ""
            )
        ]
        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel")
        )

        let suggestion = appState.activeSavedSnippetSuggestion

        XCTAssertEqual(suggestion?.snippet.name, "Excel Toplam")
        XCTAssertEqual(suggestion?.selectionKind, .learnedPreference)
        XCTAssertTrue(appState.activeSavedSnippetQuickPicks.isEmpty)
    }

    func testActiveSavedSnippetQuickPicksReturnsTopMatchesWhenMultipleRemain() {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedSnippets = [
            SavedSnippet(
                name: "Excel Toplam",
                text: "Toplam 42",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"],
                updatedAt: Date(timeIntervalSince1970: 40)
            ),
            SavedSnippet(
                name: "Excel Ozet",
                text: "Ozet 12",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"],
                updatedAt: Date(timeIntervalSince1970: 30)
            ),
            SavedSnippet(
                name: "Excel Kalemler",
                text: "Kalem 5",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"],
                updatedAt: Date(timeIntervalSince1970: 20)
            ),
            SavedSnippet(
                name: "Excel Diger",
                text: "Diger 2",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"],
                updatedAt: Date(timeIntervalSince1970: 10)
            )
        ]
        appState.savedSnippetCollections = [
            SavedSnippetCollection(
                name: "Excel Raporlari",
                selectedTag: "Rapor",
                searchQuery: ""
            )
        ]
        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel")
        )

        XCTAssertEqual(
            appState.activeSavedSnippetQuickPicks.map(\.name),
            ["Excel Toplam", "Excel Ozet", "Excel Kalemler"]
        )
    }

    func testActiveSavedSnippetQuickPicksPrioritizeRecentlyUsedSnippet() {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedSnippets = [
            SavedSnippet(
                name: "Excel Toplam",
                text: "Toplam 42",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"],
                updatedAt: Date(timeIntervalSince1970: 40),
                lastUsedAt: Date(timeIntervalSince1970: 120)
            ),
            SavedSnippet(
                name: "Excel Ozet",
                text: "Ozet 12",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"],
                updatedAt: Date(timeIntervalSince1970: 80),
                lastUsedAt: Date(timeIntervalSince1970: 120)
            ),
            SavedSnippet(
                name: "Excel Kalemler",
                text: "Kalem 5",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"],
                updatedAt: Date(timeIntervalSince1970: 60)
            )
        ]
        appState.savedSnippetCollections = [
            SavedSnippetCollection(
                name: "Excel Raporlari",
                selectedTag: "Rapor",
                searchQuery: ""
            )
        ]
        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel")
        )

        XCTAssertNil(appState.activeSavedSnippetSuggestion)
        XCTAssertEqual(
            appState.activeSavedSnippetQuickPicks.map(\.name),
            ["Excel Ozet", "Excel Toplam", "Excel Kalemler"]
        )
    }

    func testActiveSavedSnippetQuickPicksHidesWhenSingleSnippetSuggestionExists() {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedSnippets = [
            SavedSnippet(
                name: "Excel Toplam",
                text: "Toplam 42",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"]
            )
        ]
        appState.savedSnippetCollections = [
            SavedSnippetCollection(
                name: "Excel Raporlari",
                selectedTag: "Rapor",
                searchQuery: ""
            )
        ]
        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel")
        )

        XCTAssertTrue(appState.activeSavedSnippetQuickPicks.isEmpty)
    }

    func testPreferredActiveSavedSnippetCollectionSelectionReturnsSuggestionWhenAutoSyncEnabled() {
        let appState = AppState(persistsUserPreferences: false)
        let collection = SavedSnippetCollection(
            name: "Excel Raporlari",
            selectedTag: "Rapor",
            searchQuery: "toplam"
        )
        appState.savedSnippets = [
            SavedSnippet(
                name: "Excel Toplam",
                text: "Toplam 42",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"]
            )
        ]
        appState.savedSnippetCollections = [collection]
        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel")
        )

        XCTAssertEqual(
            appState.preferredActiveSavedSnippetCollectionSelection(currentSelectionID: nil)?.name,
            "Excel Raporlari"
        )
    }

    func testPreferredActiveSavedSnippetCollectionSelectionSkipsWhenAlreadySelected() {
        let appState = AppState(persistsUserPreferences: false)
        let collection = SavedSnippetCollection(
            name: "Excel Raporlari",
            selectedTag: "Rapor",
            searchQuery: "toplam"
        )
        appState.savedSnippets = [
            SavedSnippet(
                name: "Excel Toplam",
                text: "Toplam 42",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"]
            )
        ]
        appState.savedSnippetCollections = [collection]
        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel")
        )

        XCTAssertNil(
            appState.preferredActiveSavedSnippetCollectionSelection(currentSelectionID: collection.id)
        )
    }

    func testPreferredActiveSavedSnippetCollectionSelectionReturnsNilWhenAutoSyncDisabled() {
        let appState = AppState(persistsUserPreferences: false)
        let collection = SavedSnippetCollection(
            name: "Excel Raporlari",
            selectedTag: "Rapor",
            searchQuery: "toplam"
        )
        appState.savedSnippets = [
            SavedSnippet(
                name: "Excel Toplam",
                text: "Toplam 42",
                captureMode: .table,
                outputPreset: .office,
                source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel"),
                tags: ["Rapor"]
            )
        ]
        appState.savedSnippetCollections = [collection]
        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel")
        )
        appState.setSavedSnippetCollectionAutoSyncEnabled(false)

        XCTAssertNil(
            appState.preferredActiveSavedSnippetCollectionSelection(currentSelectionID: nil)
        )
    }

    func testSavedSnippetCollectionAutoSyncPreferencePersists() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertTrue(appState.savedSnippetCollectionAutoSyncEnabled)

        appState.setSavedSnippetCollectionAutoSyncEnabled(false)

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertFalse(restored.savedSnippetCollectionAutoSyncEnabled)
    }

    func testApplyCaptureProfileSynchronizesCurrentSelections() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        let profile = AppCaptureProfile(
            bundleIdentifier: "com.apple.dt.Xcode",
            appName: "Xcode",
            captureMode: .code,
            outputPreset: .plainText,
            ocrLanguageSelection: OCRLanguageSelection(
                automaticDetection: false,
                languages: [.english]
            )
        )

        appState.applyCaptureProfile(profile)

        XCTAssertEqual(appState.captureMode, .code)
        XCTAssertEqual(appState.captureOutputPreset, .plainText)
        XCTAssertEqual(
            appState.ocrLanguageSelection,
            OCRLanguageSelection(automaticDetection: false, languages: [.english])
        )
    }

    func testAppProfilePanelAutoSyncPreferencePersists() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertFalse(appState.appProfilePanelAutoSyncEnabled)

        appState.setAppProfilePanelAutoSyncEnabled(true)

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertTrue(restored.appProfilePanelAutoSyncEnabled)
    }

    func testPreferredRepasteOutputPresetUsesActiveAppProfile() {
        let appState = AppState(persistsUserPreferences: false)
        appState.appProfiles = [
            AppCaptureProfile(
                bundleIdentifier: "com.microsoft.Word",
                appName: "Microsoft Word",
                captureMode: .standard,
                outputPreset: .office,
                ocrLanguageSelection: .defaultValue
            )
        ]
        appState.updateActiveSourceApp(
            .init(appName: "Microsoft Word", bundleIdentifier: "com.microsoft.Word")
        )

        XCTAssertEqual(appState.preferredRepasteOutputPreset(defaultingTo: .markdown), .office)
        XCTAssertEqual(appState.activeTargetBundleIdentifier, "com.microsoft.Word")
    }

    func testPreferredRepasteOutputPresetFallsBackWithoutActiveProfile() {
        let appState = AppState(persistsUserPreferences: false)
        appState.updateActiveSourceApp(
            .init(appName: "Preview", bundleIdentifier: "com.apple.Preview")
        )

        XCTAssertEqual(appState.preferredRepasteOutputPreset(defaultingTo: .markdown), .markdown)
        XCTAssertEqual(appState.activeTargetBundleIdentifier, "com.apple.Preview")
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
            ClipboardHistoryEntry(text: "Birinci satir", date: Date(timeIntervalSince1970: 10), isPinned: true),
            ClipboardHistoryEntry(text: "Ikinci satir", date: Date(timeIntervalSince1970: 20))
        ]

        let output = ClipboardHistoryStore.exportText(
            entries,
            generatedAt: Date(timeIntervalSince1970: 30)
        )

        XCTAssertTrue(output.contains("ScreenTextGrab Geçmişi"))
        XCTAssertTrue(output.contains("Birinci satir"))
        XCTAssertTrue(output.contains("Ikinci satir"))
        XCTAssertTrue(output.contains("Sabit: Evet"))
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
                source: .init(appName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
                isPinned: true
            )
        ]

        let output = ClipboardHistoryStore.export(entries, format: .json)

        XCTAssertTrue(output.contains("\"captureMode\""))
        XCTAssertTrue(output.contains("\"outputPreset\""))
        XCTAssertTrue(output.contains("\"rawText\""))
        XCTAssertTrue(output.contains("\"source\""))
        XCTAssertTrue(output.contains("\"isPinned\""))
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
        XCTAssertTrue(entry.matches(query: CaptureMode.table.title))
        XCTAssertTrue(entry.matches(query: ClipboardHistoryEntry.ContentKind.barcode.title))
        XCTAssertTrue(entry.matches(query: CaptureOutputPreset.json.title))
        XCTAssertTrue(entry.matches(query: "example.com"))
        XCTAssertFalse(entry.matches(query: "Terminal"))
    }

    func testAppStateRemembersLastCaptureSelection() {
        let appState = AppState(persistsUserPreferences: false)
        let selection = RecentCaptureSelection(
            screenRect: CGRect(x: 20, y: 30, width: 240, height: 120),
            preferredDisplayID: 77,
            source: .init(appName: "Safari", bundleIdentifier: "com.apple.Safari"),
            sessionConfiguration: CaptureSessionConfiguration(
                captureMode: .table,
                outputPreset: .office,
                ocrLanguageSelection: OCRLanguageSelection(automaticDetection: false, languages: [.english]),
                profileName: "Safari"
            )
        )

        appState.rememberCaptureSelection(selection)

        XCTAssertEqual(appState.lastCaptureSelection, selection)
    }

    func testSaveLastCaptureSelectionPersistsSavedRegion() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        let selection = RecentCaptureSelection(
            screenRect: CGRect(x: 20, y: 30, width: 240, height: 120),
            preferredDisplayID: 77,
            source: .init(appName: "Safari", bundleIdentifier: "com.apple.Safari"),
            sessionConfiguration: CaptureSessionConfiguration(
                captureMode: .table,
                outputPreset: .office,
                ocrLanguageSelection: OCRLanguageSelection(automaticDetection: false, languages: [.english]),
                profileName: "Safari"
            )
        )

        appState.rememberCaptureSelection(selection)
        let saved = appState.saveLastCaptureSelection()

        let expectedName = "Safari • \(CaptureMode.table.shortTitle)"

        XCTAssertEqual(saved?.name, expectedName)
        XCTAssertEqual(appState.savedCaptureRegions.first?.screenRect, selection.screenRect)

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertEqual(restored.savedCaptureRegions.first?.name, expectedName)
        XCTAssertEqual(restored.savedCaptureRegions.first?.sessionConfiguration.captureMode, .table)
    }

    func testRefreshSavedCaptureRegionPreservesNameAndUpdatesSelection() {
        let appState = AppState(persistsUserPreferences: false)
        let initialSelection = RecentCaptureSelection(
            screenRect: CGRect(x: 20, y: 30, width: 240, height: 120),
            preferredDisplayID: 77,
            source: .init(appName: "Safari", bundleIdentifier: "com.apple.Safari"),
            sessionConfiguration: CaptureSessionConfiguration(
                captureMode: .table,
                outputPreset: .office,
                ocrLanguageSelection: .defaultValue,
                profileName: "Safari"
            )
        )

        appState.rememberCaptureSelection(initialSelection)
        guard let saved = appState.saveLastCaptureSelection() else {
            XCTFail("Expected saved region")
            return
        }

        let updatedSelection = RecentCaptureSelection(
            screenRect: CGRect(x: 90, y: 110, width: 300, height: 180),
            preferredDisplayID: 99,
            source: .init(appName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
            sessionConfiguration: CaptureSessionConfiguration(
                captureMode: .code,
                outputPreset: .markdown,
                ocrLanguageSelection: OCRLanguageSelection(automaticDetection: false, languages: [.english]),
                profileName: "Xcode"
            )
        )

        appState.rememberCaptureSelection(updatedSelection)
        let refreshed = appState.refreshSavedCaptureRegion(saved)

        XCTAssertEqual(refreshed?.name, saved.name)
        XCTAssertEqual(refreshed?.screenRect, updatedSelection.screenRect)
        XCTAssertEqual(refreshed?.sessionConfiguration.captureMode, .code)
        XCTAssertEqual(refreshed?.source?.bundleIdentifier, "com.apple.dt.Xcode")
    }

    func testSavedCaptureSelectionUsesUniqueGeneratedNames() {
        let appState = AppState(persistsUserPreferences: false)
        let selection = RecentCaptureSelection(
            screenRect: CGRect(x: 20, y: 30, width: 240, height: 120),
            preferredDisplayID: 77,
            source: .init(appName: "Safari", bundleIdentifier: "com.apple.Safari"),
            sessionConfiguration: CaptureSessionConfiguration(
                captureMode: .table,
                outputPreset: .office,
                ocrLanguageSelection: .defaultValue,
                profileName: "Safari"
            )
        )

        appState.rememberCaptureSelection(selection)
        let first = appState.saveLastCaptureSelection()
        let second = appState.saveLastCaptureSelection()

        let expectedName = "Safari • \(CaptureMode.table.shortTitle)"
        XCTAssertEqual(first?.name, expectedName)
        XCTAssertEqual(second?.name, "\(expectedName) 2")
    }

    func testSaveHistoryEntryAsSnippetPersistsMetadata() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        let entry = ClipboardHistoryEntry(
            text: "if value {\n    print(value)\n}",
            date: Date(),
            captureMode: .code,
            outputPreset: .markdown,
            contentKind: .text,
            rawText: "if value {\n    print(value)\n}",
            ocrConfidence: 0.73,
            source: .init(appName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode")
        )

        let snippet = appState.saveHistoryEntryAsSnippet(entry)

        XCTAssertEqual(snippet.captureMode, .code)
        XCTAssertEqual(snippet.outputPreset, .markdown)
        XCTAssertEqual(snippet.source?.bundleIdentifier, "com.apple.dt.Xcode")

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertEqual(restored.savedSnippets.first?.name, snippet.name)
        XCTAssertEqual(restored.savedSnippets.first?.outputPreset, .markdown)
        XCTAssertEqual(
            restored.savedSnippets.first?.tags,
            [CaptureMode.code.title, "Xcode", CaptureOutputPreset.markdown.title]
        )
    }

    func testSaveHistoryEntryAsSnippetRefreshesExistingMatch() {
        let appState = AppState(persistsUserPreferences: false)
        let entry = ClipboardHistoryEntry(
            text: "Ayni icerik",
            date: Date(timeIntervalSince1970: 10),
            captureMode: .standard,
            outputPreset: .cleaned,
            contentKind: .text,
            rawText: "Ayni icerik"
        )

        let first = appState.saveHistoryEntryAsSnippet(entry)
        let second = appState.saveHistoryEntryAsSnippet(entry)

        XCTAssertEqual(appState.savedSnippets.count, 1)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(second.name, first.name)
    }

    func testUpdateSavedSnippetTagsPersistsSelection() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        let entry = ClipboardHistoryEntry(
            text: "Fiyat listesi",
            date: Date(),
            captureMode: .table,
            outputPreset: .office,
            contentKind: .text,
            rawText: "Urun\tFiyat",
            source: .init(appName: "Excel", bundleIdentifier: "com.microsoft.Excel")
        )

        let snippet = appState.saveHistoryEntryAsSnippet(entry)
        appState.updateSavedSnippetTags(["Rapor", "Sik Kullanilan"], for: snippet)

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertEqual(restored.savedSnippets.first?.tags, ["Rapor", "Sik Kullanilan"])
    }

    func testUpdateSavedSnippetTagsNormalizesCustomTags() {
        let appState = AppState(persistsUserPreferences: false)
        let entry = ClipboardHistoryEntry(
            text: "Toplam\t42",
            date: Date(),
            captureMode: .table,
            outputPreset: .office,
            contentKind: .text,
            rawText: "Toplam\t42"
        )

        let snippet = appState.saveHistoryEntryAsSnippet(entry)
        appState.updateSavedSnippetTags(["  Rapor  ", "rapor", " Finans "], for: snippet)

        XCTAssertEqual(appState.savedSnippets.first?.tags, ["Rapor", "Finans"])
    }

    func testSaveSnippetCollectionPersistsFilters() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let appState = AppState(defaults: defaults, persistsUserPreferences: true)
        let collection = appState.saveSnippetCollection(
            named: "Excel Raporlari",
            selectedTag: "Rapor",
            searchQuery: "toplam"
        )

        XCTAssertEqual(collection?.selectedTag, "Rapor")
        XCTAssertEqual(collection?.searchQuery, "toplam")

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)
        XCTAssertEqual(restored.savedSnippetCollections.first?.name, "Excel Raporlari")
        XCTAssertEqual(restored.savedSnippetCollections.first?.selectedTag, "Rapor")
        XCTAssertEqual(restored.savedSnippetCollections.first?.searchQuery, "toplam")
    }

    func testSaveSnippetCollectionUpdatesExistingName() {
        let appState = AppState(persistsUserPreferences: false)

        let first = appState.saveSnippetCollection(
            named: "Kod Akisi",
            selectedTag: "Kod",
            searchQuery: ""
        )
        let second = appState.saveSnippetCollection(
            named: "kod akisi",
            selectedTag: nil,
            searchQuery: "swift"
        )

        XCTAssertEqual(appState.savedSnippetCollections.count, 1)
        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(appState.savedSnippetCollections.first?.selectedTag, nil)
        XCTAssertEqual(appState.savedSnippetCollections.first?.searchQuery, "swift")
    }

    func testSaveSnippetCollectionRejectsEmptyFilters() {
        let appState = AppState(persistsUserPreferences: false)

        let collection = appState.saveSnippetCollection(
            named: "Bos",
            selectedTag: nil,
            searchQuery: "   "
        )

        XCTAssertNil(collection)
        XCTAssertTrue(appState.savedSnippetCollections.isEmpty)
    }

    func testPresentSettingsForSavedSnippetCollectionQueuesRequest() {
        let appState = AppState(persistsUserPreferences: false)
        _ = appState.saveSnippetCollection(
            named: "Excel Raporlari",
            selectedTag: "Rapor",
            searchQuery: "toplam"
        )

        XCTAssertTrue(appState.presentSettingsForSavedSnippetCollection(named: "Excel Raporlari"))
        XCTAssertNotNil(appState.settingsPresentationToken)
        XCTAssertEqual(appState.consumePendingSnippetCollectionSelection()?.name, "Excel Raporlari")
        XCTAssertNil(appState.consumePendingSnippetCollectionSelection())
    }

    func testAvailableSnippetTagsDeduplicatesAndSortsTags() {
        let appState = AppState(persistsUserPreferences: false)
        appState.savedSnippets = [
            SavedSnippet(
                name: "Kod",
                text: "print('x')",
                captureMode: .code,
                outputPreset: .markdown,
                tags: ["Kod", "Xcode"]
            ),
            SavedSnippet(
                name: "Rapor",
                text: "Toplam",
                captureMode: .standard,
                outputPreset: .office,
                tags: ["Rapor", "kod"]
            )
        ]

        XCTAssertEqual(appState.availableSnippetTags, ["Kod", "Rapor", "Xcode"])
    }

    func testAppStateMigratesSavedSnippetsWithoutTags() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let legacyJSON = """
        [{
          "id":"E6D0BA2B-3A06-46BB-9E50-2B489B44A7E4",
          "name":"Kod parcasi",
          "text":"if value { print(value) }",
          "rawText":"if value { print(value) }",
          "captureMode":"code",
          "outputPreset":"markdown",
          "contentKind":"text",
          "ocrConfidence":0.73,
          "source":{"appName":"Xcode","bundleIdentifier":"com.apple.dt.Xcode"},
          "updatedAt":100
        }]
        """.data(using: .utf8)!
        defaults.set(legacyJSON, forKey: SavedSnippetStore.key)

        let restored = AppState(defaults: defaults, persistsUserPreferences: true)

        XCTAssertEqual(
            restored.savedSnippets.first?.tags,
            [CaptureMode.code.title, "Xcode", CaptureOutputPreset.markdown.title]
        )
    }

    func testSaveHistoryEntryAsSnippetRefreshPreservesExistingCustomTags() {
        let appState = AppState(persistsUserPreferences: false)
        let entry = ClipboardHistoryEntry(
            text: "for value in values { print(value) }",
            date: Date(),
            captureMode: .code,
            outputPreset: .markdown,
            contentKind: .text,
            rawText: "for value in values { print(value) }",
            source: .init(appName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode")
        )

        let snippet = appState.saveHistoryEntryAsSnippet(entry)
        appState.updateSavedSnippetTags(["Rapor", "Kod"], for: snippet)

        let refreshed = appState.saveHistoryEntryAsSnippet(entry)
        var expectedTags: [String] = []
        for tag in ["Rapor", "Kod", CaptureMode.code.title, "Xcode", CaptureOutputPreset.markdown.title] {
            if expectedTags.contains(where: {
                $0.compare(tag, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }) == false {
                expectedTags.append(tag)
            }
        }

        XCTAssertEqual(
            refreshed.tags,
            expectedTags
        )
    }

    func testSaveLastCopiedEntryAsSnippetUsesMostRecentHistoryEntry() {
        let appState = AppState(persistsUserPreferences: false)
        appState.recordCopiedText("Ilk kayit", captureMode: .standard, outputPreset: .plainText)
        appState.recordCopiedText("Ikinci kayit", captureMode: .table, outputPreset: .office, rawText: "Ikinci\tkayit")

        let snippet = appState.saveLastCopiedEntryAsSnippet()

        XCTAssertEqual(snippet?.text, "Ikinci kayit")
        XCTAssertEqual(snippet?.outputPreset, .office)
        XCTAssertEqual(appState.savedSnippets.first?.text, "Ikinci kayit")
    }

    func testAutomationCommandParsesCaptureArguments() {
        let command = AutomationCommand(
            arguments: [
                "/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab",
                "--capture",
                "--mode", "table",
                "--output", "office",
                "--languages", "tr,en",
                "--ocr-auto", "off"
            ]
        )

        XCTAssertEqual(
            command,
            .capture(
                AutomationCaptureOverrides(
                    captureMode: .table,
                    outputPreset: .office,
                    languagePreferences: [.turkish, .english],
                    automaticDetection: false
                )
            )
        )
    }

    func testAutomationCommandRejectsAmbiguousArguments() {
        let command = AutomationCommand(
            arguments: [
                "/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab",
                "--capture",
                "--repeat-last"
            ]
        )

        XCTAssertNil(command)
    }

    func testAutomationCommandParsesRepeatLastURL() {
        let url = URL(string: "stg://repeat-last?mode=code&output=markdown&ocr-auto=true")!

        XCTAssertEqual(
            AutomationCommand(url: url),
            .repeatLast(
                AutomationCaptureOverrides(
                    captureMode: .code,
                    outputPreset: .markdown,
                    automaticDetection: true
                )
            )
        )
    }

    func testAutomationCommandParsesSavedRegionArguments() {
        let command = AutomationCommand(
            arguments: [
                "/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab",
                "--saved-region",
                "--name", "Safari • Tablo",
                "--mode", "table",
                "--output", "office"
            ]
        )

        XCTAssertEqual(
            command,
            .savedRegion(
                "Safari • Tablo",
                AutomationCaptureOverrides(
                    captureMode: .table,
                    outputPreset: .office
                )
            )
        )
    }

    func testAutomationCommandParsesSavedRegionURL() {
        let url = URL(string: "stg://saved-region?name=Safari%20%E2%80%A2%20Tablo&mode=table&output=office")!

        XCTAssertEqual(
            AutomationCommand(url: url),
            .savedRegion(
                "Safari • Tablo",
                AutomationCaptureOverrides(
                    captureMode: .table,
                    outputPreset: .office
                )
            )
        )
    }

    func testAutomationCommandParsesSnippetArguments() {
        let command = AutomationCommand(
            arguments: [
                "/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab",
                "--snippet",
                "--name", "Fiyat listesi"
            ]
        )

        XCTAssertEqual(command, .snippet("Fiyat listesi"))
    }

    func testAutomationCommandParsesActiveSnippetArguments() {
        let command = AutomationCommand(
            arguments: [
                "/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab",
                "--active-snippet"
            ]
        )

        XCTAssertEqual(command, .activeSnippet)
    }

    func testAutomationCommandParsesSnippetURL() {
        let url = URL(string: "stg://snippet?name=Fiyat%20listesi")!

        XCTAssertEqual(AutomationCommand(url: url), .snippet("Fiyat listesi"))
    }

    func testAutomationCommandParsesActiveSnippetURL() {
        let url = URL(string: "stg://active-snippet")!

        XCTAssertEqual(AutomationCommand(url: url), .activeSnippet)
    }

    func testAutomationCommandParsesSnippetCollectionArguments() {
        let command = AutomationCommand(
            arguments: [
                "/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab",
                "--snippet-collection",
                "--name", "Excel Raporlari"
            ]
        )

        XCTAssertEqual(command, .snippetCollection("Excel Raporlari"))
    }

    func testAutomationCommandParsesSnippetCollectionURL() {
        let url = URL(string: "stg://snippet-collection?name=Excel%20Raporlari")!

        XCTAssertEqual(AutomationCommand(url: url), .snippetCollection("Excel Raporlari"))
    }

    func testAutomationCommandParsesIncomingImageFileURL() {
        XCTAssertEqual(
            AutomationCommand(incomingURL: URL(fileURLWithPath: "/tmp/example.png")),
            .imageFile(
                URL(fileURLWithPath: "/tmp/example.png"),
                AutomationCaptureOverrides()
            )
        )
    }

    func testAutomationCommandParsesIncomingPDFFileURL() {
        XCTAssertEqual(
            AutomationCommand(incomingURL: URL(fileURLWithPath: "/tmp/example.pdf")),
            .pdfFile(
                URL(fileURLWithPath: "/tmp/example.pdf"),
                AutomationCaptureOverrides()
            )
        )
    }

    func testAutomationCommandRejectsUnsupportedIncomingFileURL() {
        XCTAssertNil(
            AutomationCommand(incomingURL: URL(fileURLWithPath: "/tmp/example.txt"))
        )
    }

    func testAutomationCommandParsesClipboardImageArgument() {
        let command = AutomationCommand(
            arguments: [
                "/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab",
                "--clipboard-image",
                "--mode", "standard",
                "--output", "cleaned"
            ]
        )

        XCTAssertEqual(
            command,
            .clipboardImage(
                AutomationCaptureOverrides(
                    captureMode: .standard,
                    outputPreset: .cleaned
                )
            )
        )
    }

    func testAutomationCommandParsesImageFileArgument() {
        let command = AutomationCommand(
            arguments: [
                "/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab",
                "--image-file",
                "--path", "/tmp/example.png",
                "--mode", "table",
                "--output", "office"
            ]
        )

        XCTAssertEqual(
            command,
            .imageFile(
                URL(fileURLWithPath: "/tmp/example.png"),
                AutomationCaptureOverrides(
                    captureMode: .table,
                    outputPreset: .office
                )
            )
        )
    }

    func testAutomationCommandParsesPDFFileArgument() {
        let command = AutomationCommand(
            arguments: [
                "/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab",
                "--pdf-file",
                "--path", "/tmp/example.pdf",
                "--mode", "standard",
                "--output", "cleaned"
            ]
        )

        XCTAssertEqual(
            command,
            .pdfFile(
                URL(fileURLWithPath: "/tmp/example.pdf"),
                AutomationCaptureOverrides(
                    captureMode: .standard,
                    outputPreset: .cleaned
                )
            )
        )
    }

    func testAutomationCommandParsesSearchablePDFArgument() {
        let command = AutomationCommand(
            arguments: [
                "/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab",
                "--pdf-searchable",
                "--path", "/tmp/example.pdf",
                "--destination", "/tmp/example-searchable.pdf",
                "--mode", "table"
            ]
        )

        XCTAssertEqual(
            command,
            .searchablePDF(
                URL(fileURLWithPath: "/tmp/example.pdf"),
                URL(fileURLWithPath: "/tmp/example-searchable.pdf"),
                AutomationCaptureOverrides(
                    captureMode: .table
                )
            )
        )
    }

    func testAutomationURLBuilderRoundTripsToCommand() {
        let url = AutomationURLBuilder.capture(
            overrides: AutomationCaptureOverrides(
                captureMode: .subtitle,
                outputPreset: .cleaned,
                languagePreferences: [.english],
                automaticDetection: false
            )
        )

        XCTAssertEqual(
            AutomationCommand(url: url!),
            .capture(
                AutomationCaptureOverrides(
                    captureMode: .subtitle,
                    outputPreset: .cleaned,
                    languagePreferences: [.english],
                    automaticDetection: false
                )
            )
        )
    }

    func testClipboardImageURLBuilderRoundTripsToCommand() {
        let url = AutomationURLBuilder.clipboardImage(
            overrides: AutomationCaptureOverrides(
                captureMode: .code,
                outputPreset: .markdown
            )
        )

        XCTAssertEqual(
            AutomationCommand(url: url!),
            .clipboardImage(
                AutomationCaptureOverrides(
                    captureMode: .code,
                    outputPreset: .markdown
                )
            )
        )
    }

    func testSnippetURLBuilderRoundTripsToCommand() {
        let url = AutomationURLBuilder.snippet(name: "Fiyat listesi")

        XCTAssertEqual(AutomationCommand(url: url!), .snippet("Fiyat listesi"))
    }

    func testActiveSnippetURLBuilderRoundTripsToCommand() {
        let url = AutomationURLBuilder.activeSnippet()

        XCTAssertEqual(AutomationCommand(url: url!), .activeSnippet)
    }

    func testSnippetCollectionURLBuilderRoundTripsToCommand() {
        let url = AutomationURLBuilder.snippetCollection(name: "Excel Raporlari")

        XCTAssertEqual(AutomationCommand(url: url!), .snippetCollection("Excel Raporlari"))
    }

    func testImageFileURLBuilderRoundTripsToCommand() {
        let url = AutomationURLBuilder.imageFile(
            path: "/tmp/example.png",
            overrides: AutomationCaptureOverrides(
                captureMode: .standard,
                outputPreset: .cleaned
            )
        )

        XCTAssertEqual(
            AutomationCommand(url: url!),
            .imageFile(
                URL(fileURLWithPath: "/tmp/example.png"),
                AutomationCaptureOverrides(
                    captureMode: .standard,
                    outputPreset: .cleaned
                )
            )
        )
    }

    func testPDFFileURLBuilderRoundTripsToCommand() {
        let url = AutomationURLBuilder.pdfFile(
            path: "/tmp/example.pdf",
            overrides: AutomationCaptureOverrides(
                captureMode: .code,
                outputPreset: .markdown
            )
        )

        XCTAssertEqual(
            AutomationCommand(url: url!),
            .pdfFile(
                URL(fileURLWithPath: "/tmp/example.pdf"),
                AutomationCaptureOverrides(
                    captureMode: .code,
                    outputPreset: .markdown
                )
            )
        )
    }

    func testSearchablePDFURLBuilderRoundTripsToCommand() {
        let url = AutomationURLBuilder.searchablePDF(
            path: "/tmp/example.pdf",
            destination: "/tmp/example-searchable.pdf",
            overrides: AutomationCaptureOverrides(
                captureMode: .table
            )
        )

        XCTAssertEqual(
            AutomationCommand(url: url!),
            .searchablePDF(
                URL(fileURLWithPath: "/tmp/example.pdf"),
                URL(fileURLWithPath: "/tmp/example-searchable.pdf"),
                AutomationCaptureOverrides(
                    captureMode: .table
                )
            )
        )
    }

    func testImportedDocumentRouterResolvesImageFile() {
        XCTAssertEqual(
            ImportedDocumentRouter.resolve(URL(fileURLWithPath: "/tmp/example.png")),
            .image(URL(fileURLWithPath: "/tmp/example.png"))
        )
    }

    func testImportedDocumentRouterResolvesPDFFile() {
        XCTAssertEqual(
            ImportedDocumentRouter.resolve(URL(fileURLWithPath: "/tmp/example.pdf")),
            .pdf(URL(fileURLWithPath: "/tmp/example.pdf"))
        )
    }

    func testImportedDocumentRouterResolvesExtensionlessPNGFileFromSignature() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pngBytes: [UInt8] = [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
            0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
            0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
            0x00, 0x03, 0x01, 0x01, 0x00, 0xC9, 0xFE, 0x92,
            0xEF, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
            0x44, 0xAE, 0x42, 0x60, 0x82
        ]
        try Data(pngBytes).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(
            ImportedDocumentRouter.resolve(url),
            .image(url.standardizedFileURL)
        )
    }

    func testImportedDocumentRouterResolvesExtensionlessPDFFileFromSignature() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pdfData = Data("%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF".utf8)
        try pdfData.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(
            ImportedDocumentRouter.resolve(url),
            .pdf(url.standardizedFileURL)
        )
    }

    func testAutomationCommandResolveIncomingURLsAcceptsMultipleImportedFilesInOrder() {
        let urls = [
            URL(fileURLWithPath: "/tmp/example.png"),
            URL(fileURLWithPath: "/tmp/example.pdf")
        ]

        XCTAssertEqual(
            AutomationCommand.resolveIncomingURLs(urls),
            .commands([
                .imageFile(URL(fileURLWithPath: "/tmp/example.png"), AutomationCaptureOverrides()),
                .pdfFile(URL(fileURLWithPath: "/tmp/example.pdf"), AutomationCaptureOverrides())
            ])
        )
    }

    func testAutomationCommandQueueSerializesImportedFileCommandsUntilCaptureCompletes() {
        var queue = AutomationCommandQueue()
        let imageCommand = AutomationCommand.imageFile(
            URL(fileURLWithPath: "/tmp/example.png"),
            AutomationCaptureOverrides()
        )
        let pdfCommand = AutomationCommand.pdfFile(
            URL(fileURLWithPath: "/tmp/example.pdf"),
            AutomationCaptureOverrides()
        )

        queue.enqueue([imageCommand, pdfCommand])

        let first = queue.nextCommand(captureState: .idle)
        XCTAssertEqual(first, imageCommand)

        XCTAssertNil(queue.nextCommand(captureState: .preparing))

        queue.captureStateDidChange(.completed)

        let second = queue.nextCommand(captureState: .idle)
        XCTAssertEqual(second, pdfCommand)
        XCTAssertTrue(queue.isEmpty)
    }

    func testAutomationCommandQueueReleasesImportedFileGateWhenDispatchFailsImmediately() {
        var queue = AutomationCommandQueue()
        let imageCommand = AutomationCommand.imageFile(
            URL(fileURLWithPath: "/tmp/example.png"),
            AutomationCaptureOverrides()
        )
        let pdfCommand = AutomationCommand.pdfFile(
            URL(fileURLWithPath: "/tmp/example.pdf"),
            AutomationCaptureOverrides()
        )

        queue.enqueue([imageCommand, pdfCommand])

        let first = queue.nextCommand(captureState: .idle)
        XCTAssertEqual(first, imageCommand)
        queue.markDispatchResult(for: imageCommand, startedBusyWork: false)

        let second = queue.nextCommand(captureState: .idle)
        XCTAssertEqual(second, pdfCommand)
    }

    func testFinderImportServiceProviderReadsFileURLsFromPasteboard() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.writeObjects([
            NSURL(fileURLWithPath: "/tmp/example.png"),
            NSURL(fileURLWithPath: "/tmp/example.pdf")
        ])

        XCTAssertEqual(
            FinderImportServiceProvider.readFileURLs(from: pasteboard),
            [
                URL(fileURLWithPath: "/tmp/example.png"),
                URL(fileURLWithPath: "/tmp/example.pdf")
            ]
        )
    }

    func testFinderImportServiceProviderReturnsEmptyForUnsupportedPasteboardContent() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setString("desteklenmeyen", forType: NSPasteboard.PasteboardType.string)

        XCTAssertTrue(
            FinderImportServiceProvider.readFileURLs(from: pasteboard).isEmpty
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

    func testPreferredInstallDestinationUsesExistingInstalledBundlePathForUpgrade() throws {
        let sandbox = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let installedRoot = sandbox.appendingPathComponent("Applications", isDirectory: true)
        let downloadsRoot = sandbox.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: installedRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: downloadsRoot, withIntermediateDirectories: true)

        let installedApp = try makeFakeApp(
            named: "ScreenTextGrab Pro.app",
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

        let destination = InstalledAppLocator.preferredInstallDestination(
            currentURL: downloadedApp,
            bundleIdentifier: "dev.screentextgrab.app",
            searchRoots: [installedRoot]
        )

        XCTAssertEqual(destination?.lastPathComponent, installedApp.lastPathComponent)
    }

    func testPreferredInstallDestinationFallsBackToWritableUserApplicationsRoot() throws {
        let sandbox = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let lockedRoot = sandbox.appendingPathComponent("SystemApplications", isDirectory: true)
        let userRoot = sandbox.appendingPathComponent("UserApplications", isDirectory: true)
        let downloadsRoot = sandbox.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: lockedRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: userRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: downloadsRoot, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: lockedRoot.path)

        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: lockedRoot.path)
        }

        let downloadedApp = try makeFakeApp(
            named: "ScreenTextGrab.app",
            version: "3",
            bundleIdentifier: "dev.screentextgrab.app",
            in: downloadsRoot
        )

        let destination = InstalledAppLocator.preferredInstallDestination(
            currentURL: downloadedApp,
            bundleIdentifier: "dev.screentextgrab.app",
            searchRoots: [lockedRoot, userRoot]
        )

        XCTAssertEqual(destination, userRoot.appendingPathComponent("ScreenTextGrab.app", isDirectory: true))
    }

    func testInstalledAppRelocatorCopiesBundleIntoPreferredInstallDestination() throws {
        let sandbox = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let installedRoot = sandbox.appendingPathComponent("Applications", isDirectory: true)
        let downloadsRoot = sandbox.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: installedRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: downloadsRoot, withIntermediateDirectories: true)

        let downloadedApp = try makeFakeApp(
            named: "ScreenTextGrab.app",
            version: "7",
            bundleIdentifier: "dev.screentextgrab.app",
            in: downloadsRoot
        )

        let relocatedURL = try InstalledAppRelocator.installCurrentCopy(
            from: downloadedApp,
            bundleIdentifier: "dev.screentextgrab.app",
            searchRoots: [installedRoot]
        )

        XCTAssertEqual(relocatedURL.standardizedFileURL.path, installedRoot.appendingPathComponent("ScreenTextGrab.app", isDirectory: true).standardizedFileURL.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: relocatedURL.appendingPathComponent("Contents/Info.plist").path))
        XCTAssertEqual(Bundle(url: relocatedURL)?.bundleIdentifier, "dev.screentextgrab.app")
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

    private let defaultsSuiteName = "ScreenTextGrab.AppStatePreferencesTests.\(UUID().uuidString)"

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
