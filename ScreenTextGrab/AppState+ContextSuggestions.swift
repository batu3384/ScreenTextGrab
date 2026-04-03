import Foundation

extension AppState {
    var activeAppProfileSuggestion: ActiveAppProfileSuggestion? {
        ContextSuggestionService.activeAppProfileSuggestion(
            activeSourceApp: activeSourceApp,
            appProfiles: appProfiles,
            captureMode: captureMode,
            captureOutputPreset: captureOutputPreset,
            ocrLanguageSelection: ocrLanguageSelection
        )
    }

    var activeSavedCaptureRegionSuggestion: ActiveSavedCaptureRegionSuggestion? {
        ContextSuggestionService.activeSavedCaptureRegionSuggestion(
            activeSourceApp: activeSourceApp,
            savedCaptureRegions: savedCaptureRegions
        )
    }

    var activeSavedSnippetCollectionSuggestion: ActiveSavedSnippetCollectionSuggestion? {
        ContextSuggestionService.activeSavedSnippetCollectionSuggestion(
            activeSourceApp: activeSourceApp,
            savedSnippets: savedSnippets,
            savedSnippetCollections: savedSnippetCollections
        )
    }

    var activeSavedSnippetSuggestion: ActiveSavedSnippetSuggestion? {
        ContextSuggestionService.activeSavedSnippetSuggestion(
            collectionSuggestion: activeSavedSnippetCollectionSuggestion
        )
    }

    var activeSavedSnippetQuickPicks: [SavedSnippet] {
        ContextSuggestionService.activeSavedSnippetQuickPicks(
            collectionSuggestion: activeSavedSnippetCollectionSuggestion,
            activeSavedSnippetSuggestion: activeSavedSnippetSuggestion
        )
    }

    var primaryQuickStartRegion: SavedCaptureRegion? {
        guard savedCaptureRegionQuickStartEnabled else {
            return nil
        }

        return activeSavedCaptureRegionSuggestion?.primaryRegion
    }

    func preferredActiveSavedSnippetCollectionSelection(currentSelectionID: UUID?) -> SavedSnippetCollection? {
        ContextSuggestionService.preferredActiveSavedSnippetCollectionSelection(
            currentSelectionID: currentSelectionID,
            autoSyncEnabled: savedSnippetCollectionAutoSyncEnabled,
            suggestion: activeSavedSnippetCollectionSuggestion
        )
    }

    func savedCaptureRegions(for bundleIdentifier: String?) -> [SavedCaptureRegion] {
        ContextSuggestionService.savedCaptureRegions(
            for: bundleIdentifier,
            savedCaptureRegions: savedCaptureRegions
        )
    }

    func syncActiveAppProfileIfNeeded(
        for source: ClipboardHistoryEntry.SourceContext? = nil
    ) -> Bool {
        guard appProfilePanelAutoSyncEnabled,
              let source = source ?? activeSourceApp,
              let profile = appProfile(for: source.bundleIdentifier),
              !captureSettingsMatch(profile) else {
            return false
        }

        applyCaptureProfile(profile)
        return true
    }

    func captureSettingsMatch(_ profile: AppCaptureProfile) -> Bool {
        ContextSuggestionService.captureSettingsMatch(
            profile,
            captureMode: captureMode,
            captureOutputPreset: captureOutputPreset,
            ocrLanguageSelection: ocrLanguageSelection
        )
    }
}
