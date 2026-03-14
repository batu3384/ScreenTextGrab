import Foundation

extension AppState {
    var activeAppProfileSuggestion: ActiveAppProfileSuggestion? {
        guard let activeSourceApp,
              let profile = appProfile(for: activeSourceApp.bundleIdentifier),
              !captureSettingsMatch(profile) else {
            return nil
        }

        return ActiveAppProfileSuggestion(source: activeSourceApp, profile: profile)
    }

    var activeSavedCaptureRegionSuggestion: ActiveSavedCaptureRegionSuggestion? {
        guard let activeSourceApp else {
            return nil
        }

        let appMatchedRegions = savedCaptureRegions(for: activeSourceApp.bundleIdentifier)
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
        if let windowTitle = activeSourceApp.windowTitle,
           !windowMatchedRegions.isEmpty {
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

    var activeSavedSnippetCollectionSuggestion: ActiveSavedSnippetCollectionSuggestion? {
        guard let activeSourceApp else {
            return nil
        }

        let suggestions = savedSnippetCollections.compactMap {
            makeActiveSavedSnippetCollectionSuggestion(for: $0, activeSourceApp: activeSourceApp)
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

    var activeSavedSnippetSuggestion: ActiveSavedSnippetSuggestion? {
        guard let collectionSuggestion = activeSavedSnippetCollectionSuggestion,
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

    var activeSavedSnippetQuickPicks: [SavedSnippet] {
        guard let collectionSuggestion = activeSavedSnippetCollectionSuggestion,
              activeSavedSnippetSuggestion == nil else {
            return []
        }

        return Array(collectionSuggestion.matchingSnippets.prefix(3))
    }

    var primaryQuickStartRegion: SavedCaptureRegion? {
        guard savedCaptureRegionQuickStartEnabled else {
            return nil
        }

        return activeSavedCaptureRegionSuggestion?.primaryRegion
    }

    func preferredActiveSavedSnippetCollectionSelection(currentSelectionID: UUID?) -> SavedSnippetCollection? {
        guard savedSnippetCollectionAutoSyncEnabled,
              let suggestion = activeSavedSnippetCollectionSuggestion,
              suggestion.collection.id != currentSelectionID else {
            return nil
        }

        return suggestion.collection
    }

    func savedCaptureRegions(for bundleIdentifier: String?) -> [SavedCaptureRegion] {
        guard let bundleIdentifier,
              !bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        return savedCaptureRegions.filter {
            $0.source?.bundleIdentifier?.compare(bundleIdentifier, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
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
        captureMode == profile.captureMode &&
        captureOutputPreset == profile.outputPreset &&
        ocrLanguageSelection == profile.ocrLanguageSelection
    }
}

private extension AppState {
    func makeActiveSavedSnippetCollectionSuggestion(
        for collection: SavedSnippetCollection,
        activeSourceApp: ClipboardHistoryEntry.SourceContext
    ) -> ActiveSavedSnippetCollectionSuggestion? {
        let collectionMatches = savedSnippetsMatching(collection)
        guard !collectionMatches.isEmpty else {
            return nil
        }

        let appMatchedSnippets = collectionMatches.filter {
            sourceContext($0.source, matches: activeSourceApp)
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
        if let windowTitle = activeSourceApp.windowTitle,
           !windowMatchedSnippets.isEmpty {
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

    func savedSnippetsMatching(_ collection: SavedSnippetCollection) -> [SavedSnippet] {
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

    func prioritizeActiveSnippetMatches(_ snippets: [SavedSnippet]) -> [SavedSnippet] {
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

    func preferredLearnedSnippet(
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

    func sourceContext(
        _ source: ClipboardHistoryEntry.SourceContext?,
        matches activeSourceApp: ClipboardHistoryEntry.SourceContext
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

    func normalizedComparisonValue(_ value: String?) -> String? {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        guard let normalized, !normalized.isEmpty else {
            return nil
        }

        return normalized
    }
}
