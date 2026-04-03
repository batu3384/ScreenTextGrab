import Foundation

enum SavedWorkflowLibrary {
    static func availableSnippetTags(from snippets: [SavedSnippet]) -> [String] {
        var seen = Set<String>()

        let tags = snippets
            .flatMap(\.tags)
            .filter { tag in
                let key = tag.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                guard !seen.contains(key) else {
                    return false
                }

                seen.insert(key)
                return true
            }

        return tags.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func upsertSnippetCollection(
        named name: String,
        selectedTag: String?,
        searchQuery: String,
        existing: [SavedSnippetCollection],
        updatedAt: Date = Date()
    ) -> (collections: [SavedSnippetCollection], saved: SavedSnippetCollection?) {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTag = selectedTag?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveTag = (normalizedTag?.isEmpty == false) ? normalizedTag : nil
        let normalizedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedName.isEmpty,
              effectiveTag != nil || !normalizedQuery.isEmpty else {
            return (existing, nil)
        }

        var collections = existing

        if let index = collections.firstIndex(where: {
            $0.name.compare(normalizedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            let existingCollection = collections[index]
            collections[index] = SavedSnippetCollection(
                id: existingCollection.id,
                name: normalizedName,
                selectedTag: effectiveTag,
                searchQuery: normalizedQuery,
                updatedAt: updatedAt
            )
            sortCollections(&collections)
            return (collections, collections.first(where: { $0.id == existingCollection.id }))
        }

        let collection = SavedSnippetCollection(
            name: normalizedName,
            selectedTag: effectiveTag,
            searchQuery: normalizedQuery,
            updatedAt: updatedAt
        )
        collections.insert(collection, at: 0)

        if collections.count > SavedSnippetCollectionStore.maximumEntries {
            collections.removeLast(collections.count - SavedSnippetCollectionStore.maximumEntries)
        }

        sortCollections(&collections)
        return (collections, collections.first(where: { $0.id == collection.id }))
    }

    static func removeSnippetCollection(
        _ collection: SavedSnippetCollection,
        from existing: [SavedSnippetCollection]
    ) -> [SavedSnippetCollection] {
        existing.filter { $0.id != collection.id }
    }

    static func upsertAppProfile(
        bundleIdentifier: String,
        appName: String,
        captureMode: CaptureMode,
        outputPreset: CaptureOutputPreset,
        ocrLanguageSelection: OCRLanguageSelection,
        existing: [AppCaptureProfile]
    ) -> [AppCaptureProfile] {
        var profiles = existing.filter { $0.bundleIdentifier != bundleIdentifier }
        profiles.append(
            AppCaptureProfile(
                bundleIdentifier: bundleIdentifier,
                appName: appName,
                captureMode: captureMode,
                outputPreset: outputPreset,
                ocrLanguageSelection: ocrLanguageSelection
            )
        )
        profiles.sort { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
        return profiles
    }

    static func removeAppProfile(
        _ profile: AppCaptureProfile,
        from existing: [AppCaptureProfile]
    ) -> [AppCaptureProfile] {
        existing.filter { $0.bundleIdentifier != profile.bundleIdentifier }
    }

    static func addSavedCaptureRegion(
        from selection: RecentCaptureSelection,
        existing: [SavedCaptureRegion]
    ) -> (regions: [SavedCaptureRegion], saved: SavedCaptureRegion) {
        var regions = existing
        let region = SavedCaptureRegion(
            name: nextSavedCaptureRegionName(for: selection, existing: regions),
            screenRect: selection.screenRect,
            preferredDisplayID: selection.preferredDisplayID,
            source: selection.source,
            sessionConfiguration: selection.sessionConfiguration
        )
        regions.insert(region, at: 0)

        if regions.count > SavedCaptureRegionStore.maximumEntries {
            regions.removeLast(regions.count - SavedCaptureRegionStore.maximumEntries)
        }

        return (regions, region)
    }

    static func refreshSavedCaptureRegion(
        _ region: SavedCaptureRegion,
        using selection: RecentCaptureSelection,
        existing: [SavedCaptureRegion],
        updatedAt: Date = Date()
    ) -> (regions: [SavedCaptureRegion], saved: SavedCaptureRegion?) {
        var regions = existing
        guard let index = regions.firstIndex(where: { $0.id == region.id }) else {
            return (regions, nil)
        }

        regions[index] = SavedCaptureRegion(
            id: region.id,
            name: region.name,
            screenRect: selection.screenRect,
            preferredDisplayID: selection.preferredDisplayID,
            source: selection.source,
            sessionConfiguration: selection.sessionConfiguration,
            updatedAt: updatedAt
        )

        return (regions, regions[index])
    }

    static func saveSnippet(
        from entry: ClipboardHistoryEntry,
        existing: [SavedSnippet],
        updatedAt: Date = Date()
    ) -> (snippets: [SavedSnippet], saved: SavedSnippet) {
        var snippets = existing
        let defaultTags = defaultSnippetTags(
            captureMode: entry.captureMode,
            outputPreset: entry.outputPreset,
            contentKind: entry.contentKind,
            source: entry.source
        )

        if let index = snippets.firstIndex(where: {
            $0.text == entry.text &&
            $0.rawText == entry.rawText &&
            $0.captureMode == entry.captureMode &&
            $0.outputPreset == entry.outputPreset &&
            $0.contentKind == entry.contentKind &&
            $0.source == entry.source
        }) {
            let existingSnippet = snippets[index]
            snippets[index] = SavedSnippet(
                id: existingSnippet.id,
                name: existingSnippet.name,
                text: entry.text,
                rawText: entry.rawText,
                captureMode: entry.captureMode,
                outputPreset: entry.outputPreset,
                contentKind: entry.contentKind,
                ocrConfidence: entry.ocrConfidence,
                source: entry.source,
                tags: mergeSnippetTags(existingSnippet.tags, with: defaultTags),
                updatedAt: updatedAt,
                lastUsedAt: existingSnippet.lastUsedAt
            )
            sortSnippets(&snippets)
            return (snippets, snippets.first(where: { $0.id == existingSnippet.id }) ?? snippets[index])
        }

        let snippet = SavedSnippet(
            entry: entry,
            name: nextSavedSnippetName(for: entry, existing: snippets),
            tags: defaultTags,
            updatedAt: updatedAt
        )

        snippets.insert(snippet, at: 0)
        if snippets.count > SavedSnippetStore.maximumEntries {
            snippets.removeLast(snippets.count - SavedSnippetStore.maximumEntries)
        }
        sortSnippets(&snippets)
        return (snippets, snippets.first(where: { $0.id == snippet.id }) ?? snippet)
    }

    static func removeSnippet(_ snippet: SavedSnippet, from existing: [SavedSnippet]) -> [SavedSnippet] {
        existing.filter { $0.id != snippet.id }
    }

    static func updateSnippetTags(
        _ tags: [String],
        for snippet: SavedSnippet,
        existing: [SavedSnippet]
    ) -> [SavedSnippet] {
        var snippets = existing
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else {
            return snippets
        }

        let existingSnippet = snippets[index]
        snippets[index] = SavedSnippet(
            id: existingSnippet.id,
            name: existingSnippet.name,
            text: existingSnippet.text,
            rawText: existingSnippet.rawText,
            captureMode: existingSnippet.captureMode,
            outputPreset: existingSnippet.outputPreset,
            contentKind: existingSnippet.contentKind,
            ocrConfidence: existingSnippet.ocrConfidence,
            source: existingSnippet.source,
            tags: tags,
            updatedAt: existingSnippet.updatedAt,
            lastUsedAt: existingSnippet.lastUsedAt
        )
        sortSnippets(&snippets)
        return snippets
    }

    static func noteSnippetUsed(
        _ snippet: SavedSnippet,
        usedAt: Date = Date(),
        existing: [SavedSnippet]
    ) -> (snippets: [SavedSnippet], updated: SavedSnippet?) {
        var snippets = existing
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else {
            return (snippets, nil)
        }

        let existingSnippet = snippets[index]
        let updated = SavedSnippet(
            id: existingSnippet.id,
            name: existingSnippet.name,
            text: existingSnippet.text,
            rawText: existingSnippet.rawText,
            captureMode: existingSnippet.captureMode,
            outputPreset: existingSnippet.outputPreset,
            contentKind: existingSnippet.contentKind,
            ocrConfidence: existingSnippet.ocrConfidence,
            source: existingSnippet.source,
            tags: existingSnippet.tags,
            updatedAt: existingSnippet.updatedAt,
            lastUsedAt: usedAt
        )
        snippets[index] = updated
        return (snippets, updated)
    }

    static func suggestedTags(for snippet: SavedSnippet) -> [String] {
        mergeSnippetTags(
            snippet.tags,
            with: defaultSnippetTags(
                captureMode: snippet.captureMode,
                outputPreset: snippet.outputPreset,
                contentKind: snippet.contentKind,
                source: snippet.source
            )
        )
    }

    static func defaultSnippetTags(
        captureMode: CaptureMode,
        outputPreset: CaptureOutputPreset,
        contentKind: ClipboardHistoryEntry.ContentKind,
        source: ClipboardHistoryEntry.SourceContext?
    ) -> [String] {
        var tags: [String] = [captureMode.title]

        if let sourceName = source?.displayName, !sourceName.isEmpty {
            tags.append(sourceName)
        }

        if contentKind != .text {
            tags.append(contentKind.title)
        }

        if outputPreset != .smart {
            tags.append(outputPreset.title)
        }

        return tags
    }

    private static func sortSnippets(_ snippets: inout [SavedSnippet]) {
        snippets.sort { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func sortCollections(_ collections: inout [SavedSnippetCollection]) {
        collections.sort { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func nextSavedCaptureRegionName(
        for selection: RecentCaptureSelection,
        existing: [SavedCaptureRegion]
    ) -> String {
        let sourceName = selection.source?.appName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName: String

        if let sourceName, !sourceName.isEmpty {
            baseName = "\(sourceName) • \(selection.sessionConfiguration.captureMode.title)"
        } else {
            baseName = "Alan • \(selection.sessionConfiguration.captureMode.title)"
        }

        guard existing.contains(where: {
            $0.name.compare(baseName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) == false else {
            var suffix = 2
            while existing.contains(where: {
                $0.name.compare("\(baseName) \(suffix)", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }) {
                suffix += 1
            }

            return "\(baseName) \(suffix)"
        }

        return baseName
    }

    private static func nextSavedSnippetName(
        for entry: ClipboardHistoryEntry,
        existing: [SavedSnippet]
    ) -> String {
        let previewBase = entry.previewText
        let baseName: String

        if !previewBase.isEmpty {
            baseName = String(previewBase.prefix(34))
        } else if let sourceName = entry.source?.appName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !sourceName.isEmpty {
            baseName = "\(sourceName) • \(entry.captureMode.title)"
        } else {
            baseName = "Snippet • \(entry.captureMode.title)"
        }

        guard existing.contains(where: {
            $0.name.compare(baseName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) == false else {
            var suffix = 2
            while existing.contains(where: {
                $0.name.compare("\(baseName) \(suffix)", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }) {
                suffix += 1
            }

            return "\(baseName) \(suffix)"
        }

        return baseName
    }

    private static func mergeSnippetTags(_ existing: [String], with additions: [String]) -> [String] {
        var merged = existing

        for tag in additions where !merged.contains(where: {
            $0.compare(tag, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            merged.append(tag)
        }

        return merged
    }
}
