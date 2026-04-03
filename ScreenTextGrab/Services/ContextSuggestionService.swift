import Foundation

enum ContextSuggestionService {
    static func activeAppProfileSuggestion(
        activeSourceApp: ClipboardHistoryEntry.SourceContext?,
        appProfiles: [AppCaptureProfile],
        captureMode: CaptureMode,
        captureOutputPreset: CaptureOutputPreset,
        ocrLanguageSelection: OCRLanguageSelection
    ) -> ActiveAppProfileSuggestion? {
        guard let activeSourceApp,
              let profile = appProfile(for: activeSourceApp.bundleIdentifier, appProfiles: appProfiles),
              !captureSettingsMatch(
                profile,
                captureMode: captureMode,
                captureOutputPreset: captureOutputPreset,
                ocrLanguageSelection: ocrLanguageSelection
              ) else {
            return nil
        }

        return ActiveAppProfileSuggestion(source: activeSourceApp, profile: profile)
    }

    static func activeSavedCaptureRegionSuggestion(
        activeSourceApp: ClipboardHistoryEntry.SourceContext?,
        savedCaptureRegions regions: [SavedCaptureRegion]
    ) -> ActiveSavedCaptureRegionSuggestion? {
        guard let activeSourceApp else {
            return nil
        }

        let appMatchedRegions = savedCaptureRegions(
            for: activeSourceApp.bundleIdentifier,
            savedCaptureRegions: regions
        )
        guard !appMatchedRegions.isEmpty else {
            return nil
        }

        let windowMatchedRegions = appMatchedRegions.filter {
            $0.source?.matchesWindowTitle(activeSourceApp.windowTitle) == true
        }
        let preferredRegions = windowMatchedRegions.isEmpty ? appMatchedRegions : windowMatchedRegions
        guard let primaryRegion = preferredRegions.first else {
            return nil
        }

        let matchKind: ActiveSavedCaptureRegionSuggestion.MatchKind
        if let windowTitle = activeSourceApp.windowTitle, !windowMatchedRegions.isEmpty {
            matchKind = .windowTitle(windowTitle)
        } else {
            matchKind = .application
        }

        return ActiveSavedCaptureRegionSuggestion(
            source: activeSourceApp,
            primaryRegion: primaryRegion,
            matchingRegions: preferredRegions,
            totalAppMatchingRegions: appMatchedRegions.count,
            matchKind: matchKind
        )
    }

    static func activeSavedSnippetCollectionSuggestion(
        activeSourceApp: ClipboardHistoryEntry.SourceContext?,
        savedSnippets: [SavedSnippet],
        savedSnippetCollections: [SavedSnippetCollection]
    ) -> ActiveSavedSnippetCollectionSuggestion? {
        guard let activeSourceApp else {
            return nil
        }

        let suggestions = savedSnippetCollections.compactMap {
            makeActiveSavedSnippetCollectionSuggestion(
                for: $0,
                activeSourceApp: activeSourceApp,
                savedSnippets: savedSnippets
            )
        }

        return suggestions.sorted { lhs, rhs in
            if lhs.prefersWindowMatch != rhs.prefersWindowMatch {
                return lhs.prefersWindowMatch && !rhs.prefersWindowMatch
            }

            if lhs.snippetCount != rhs.snippetCount {
                return lhs.snippetCount > rhs.snippetCount
            }

            if lhs.collection.updatedAt != rhs.collection.updatedAt {
                return lhs.collection.updatedAt > rhs.collection.updatedAt
            }

            return lhs.collection.name.localizedCaseInsensitiveCompare(rhs.collection.name) == .orderedAscending
        }.first
    }

    static func activeSavedSnippetSuggestion(
        collectionSuggestion: ActiveSavedSnippetCollectionSuggestion?
    ) -> ActiveSavedSnippetSuggestion? {
        guard let collectionSuggestion,
              let snippet = collectionSuggestion.matchingSnippets.first else {
            return nil
        }

        let selectionKind: ActiveSavedSnippetSuggestion.SelectionKind
        if collectionSuggestion.snippetCount == 1 {
            selectionKind = .onlyMatch
        } else if preferredLearnedSnippet(from: collectionSuggestion) != nil {
            selectionKind = .learnedPreference
        } else {
            return nil
        }

        return ActiveSavedSnippetSuggestion(
            source: collectionSuggestion.source,
            collection: collectionSuggestion.collection,
            snippet: snippet,
            totalAppMatchingSnippets: collectionSuggestion.totalAppMatchingSnippets,
            matchKind: collectionSuggestion.matchKind,
            selectionKind: selectionKind
        )
    }

    static func activeSavedSnippetQuickPicks(
        collectionSuggestion: ActiveSavedSnippetCollectionSuggestion?,
        activeSavedSnippetSuggestion: ActiveSavedSnippetSuggestion?
    ) -> [SavedSnippet] {
        guard let collectionSuggestion, activeSavedSnippetSuggestion == nil else {
            return []
        }

        return Array(collectionSuggestion.matchingSnippets.prefix(3))
    }

    static func preferredActiveSavedSnippetCollectionSelection(
        currentSelectionID: UUID?,
        autoSyncEnabled: Bool,
        suggestion: ActiveSavedSnippetCollectionSuggestion?
    ) -> SavedSnippetCollection? {
        guard autoSyncEnabled,
              let suggestion,
              suggestion.collection.id != currentSelectionID else {
            return nil
        }

        return suggestion.collection
    }

    static func savedCaptureRegions(
        for bundleIdentifier: String?,
        savedCaptureRegions: [SavedCaptureRegion]
    ) -> [SavedCaptureRegion] {
        guard let bundleIdentifier = normalizedComparisonValue(bundleIdentifier) else {
            return []
        }

        return savedCaptureRegions.filter {
            normalizedComparisonValue($0.source?.bundleIdentifier) == bundleIdentifier
        }
    }

    static func captureSettingsMatch(
        _ profile: AppCaptureProfile,
        captureMode: CaptureMode,
        captureOutputPreset: CaptureOutputPreset,
        ocrLanguageSelection: OCRLanguageSelection
    ) -> Bool {
        captureMode == profile.captureMode &&
        captureOutputPreset == profile.outputPreset &&
        ocrLanguageSelection == profile.ocrLanguageSelection
    }

    static func sourceContextMatches(
        _ source: ClipboardHistoryEntry.SourceContext?,
        activeSourceApp: ClipboardHistoryEntry.SourceContext
    ) -> Bool {
        guard let source else {
            return false
        }

        if let sourceBundleIdentifier = normalizedComparisonValue(source.bundleIdentifier),
           let activeBundleIdentifier = normalizedComparisonValue(activeSourceApp.bundleIdentifier),
           sourceBundleIdentifier == activeBundleIdentifier {
            return true
        }

        if let sourceAppName = normalizedComparisonValue(source.appName),
           let activeAppName = normalizedComparisonValue(activeSourceApp.appName),
           sourceAppName == activeAppName {
            return true
        }

        if let sourceDisplayName = normalizedComparisonValue(source.displayName),
           let activeDisplayName = normalizedComparisonValue(activeSourceApp.displayName) {
            return sourceDisplayName == activeDisplayName
        }

        return false
    }

    static func normalizedComparisonValue(_ value: String?) -> String? {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        guard let normalized, !normalized.isEmpty else {
            return nil
        }

        return normalized
    }

    private static func appProfile(
        for bundleIdentifier: String?,
        appProfiles: [AppCaptureProfile]
    ) -> AppCaptureProfile? {
        guard let normalizedBundleIdentifier = normalizedComparisonValue(bundleIdentifier) else {
            return nil
        }

        return appProfiles.first {
            normalizedComparisonValue($0.bundleIdentifier) == normalizedBundleIdentifier
        }
    }

    private static func makeActiveSavedSnippetCollectionSuggestion(
        for collection: SavedSnippetCollection,
        activeSourceApp: ClipboardHistoryEntry.SourceContext,
        savedSnippets: [SavedSnippet]
    ) -> ActiveSavedSnippetCollectionSuggestion? {
        let collectionMatches = savedSnippetsMatching(collection, savedSnippets: savedSnippets)
        guard !collectionMatches.isEmpty else {
            return nil
        }

        let appMatchedSnippets = collectionMatches.filter {
            sourceContextMatches($0.source, activeSourceApp: activeSourceApp)
        }
        guard !appMatchedSnippets.isEmpty else {
            return nil
        }

        let windowMatchedSnippets = appMatchedSnippets.filter {
            $0.source?.matchesWindowTitle(activeSourceApp.windowTitle) == true
        }
        let preferredSnippets = prioritizeActiveSnippetMatches(
            windowMatchedSnippets.isEmpty ? appMatchedSnippets : windowMatchedSnippets
        )

        let matchKind: ActiveSavedSnippetCollectionSuggestion.MatchKind
        if let windowTitle = activeSourceApp.windowTitle, !windowMatchedSnippets.isEmpty {
            matchKind = .windowTitle(windowTitle)
        } else {
            matchKind = .application
        }

        return ActiveSavedSnippetCollectionSuggestion(
            source: activeSourceApp,
            collection: collection,
            matchingSnippets: preferredSnippets,
            totalAppMatchingSnippets: appMatchedSnippets.count,
            matchKind: matchKind
        )
    }

    private static func savedSnippetsMatching(
        _ collection: SavedSnippetCollection,
        savedSnippets: [SavedSnippet]
    ) -> [SavedSnippet] {
        savedSnippets.filter { snippet in
            let matchesTag: Bool
            if let selectedTag = collection.selectedTag {
                matchesTag = snippet.tags.contains {
                    $0.compare(selectedTag, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                }
            } else {
                matchesTag = true
            }

            let normalizedQuery = collection.searchQuery
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let matchesQuery: Bool
            if normalizedQuery.isEmpty {
                matchesQuery = true
            } else {
                let haystacks = [
                    snippet.name,
                    snippet.text,
                    snippet.source?.displayName ?? "",
                    snippet.source?.windowTitle ?? ""
                ] + snippet.tags

                matchesQuery = haystacks.contains { candidate in
                    candidate
                        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                        .contains(normalizedQuery)
                }
            }

            return matchesTag && matchesQuery
        }
    }

    private static func prioritizeActiveSnippetMatches(_ snippets: [SavedSnippet]) -> [SavedSnippet] {
        snippets.sorted { lhs, rhs in
            switch (lhs.lastUsedAt, rhs.lastUsedAt) {
            case let (left?, right?) where left != right:
                return left > right
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                break
            }

            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func preferredLearnedSnippet(
        from suggestion: ActiveSavedSnippetCollectionSuggestion
    ) -> SavedSnippet? {
        guard suggestion.matchingSnippets.count > 1,
              let primary = suggestion.matchingSnippets.first,
              let primaryLastUsedAt = primary.lastUsedAt else {
            return nil
        }

        let competingLastUsedAt = suggestion.matchingSnippets
            .dropFirst()
            .compactMap(\.lastUsedAt)
            .max()

        if let competingLastUsedAt, competingLastUsedAt >= primaryLastUsedAt {
            return nil
        }

        return primary
    }
}
