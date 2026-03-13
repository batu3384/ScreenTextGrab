import Foundation
import CoreGraphics

/// OCR sonuç modeli — tanınan her metin bloğu için
struct OCRTextBlock: Identifiable, Sendable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

/// Tüm OCR sonuçlarını kapsayan model
struct OCRResult: Sendable {
    let blocks: [OCRTextBlock]
    let captureDate: Date
    let sourceRect: CGRect
    let tableGuides: [CGFloat]

    init(
        blocks: [OCRTextBlock],
        captureDate: Date,
        sourceRect: CGRect,
        tableGuides: [CGFloat] = []
    ) {
        self.blocks = blocks
        self.captureDate = captureDate
        self.sourceRect = sourceRect
        self.tableGuides = tableGuides
    }

    var fullText: String {
        fullText(for: .standard)
    }

    func fullText(for captureMode: CaptureMode) -> String {
        switch captureMode {
        case .code:
            return codeFormattedText
        case .table:
            return tableFormattedText
        case .standard, .subtitle:
            return standardFormattedText
        }
    }

    private var standardFormattedText: String {
        groupedLines(lineThreshold: 0.03)
            .map { line in
                line.sorted { $0.boundingBox.midX < $1.boundingBox.midX }
                    .map(\.text)
                    .joined(separator: " ")
            }
            .joined(separator: "\n")
    }

    private var codeFormattedText: String {
        let sortedLines = groupedLines(lineThreshold: 0.024).map {
            $0.sorted { $0.boundingBox.midX < $1.boundingBox.midX }
        }

        guard !sortedLines.isEmpty else {
            return ""
        }

        let baseX = sortedLines.compactMap { $0.first?.boundingBox.minX }.min() ?? 0
        let indentOffsets = sortedLines.compactMap { line -> CGFloat? in
            guard let first = line.first else { return nil }
            let offset = first.boundingBox.minX - baseX
            return (0.012...0.18).contains(offset) ? offset : nil
        }
        let indentUnit = max(indentOffsets.min() ?? 0.035, 0.018)

        return sortedLines
            .map { line in
                codeLineText(line, baseX: baseX, indentUnit: indentUnit)
            }
            .joined(separator: "\n")
    }

    private var tableFormattedText: String {
        let rows = groupedLines(lineThreshold: 0.028).map {
            $0.sorted { $0.boundingBox.midX < $1.boundingBox.midX }
        }

        guard rows.count >= 2 else {
            return standardFormattedText
        }

        if let structuredText = structuredTableText(from: rows) {
            return structuredText
        }

        if let heuristicText = heuristicTableText(from: rows) {
            return heuristicText
        }

        return standardFormattedText
    }

    private func structuredTableText(from rows: [[OCRTextBlock]]) -> String? {
        let separators = resolvedTableSeparators(from: rows)
        guard !separators.isEmpty else {
            return nil
        }

        let rowCells = collapsedContinuationRows(rows.map { tableCells(for: $0, separators: separators) })
        let multiColumnRows = rowCells.filter { row in
            row.filter { !$0.isEmpty }.count >= 2
        }

        guard multiColumnRows.count >= 2 else {
            return nil
        }

        return rowCells
            .map { row in
                row.map(trimTrailingSpaces).joined(separator: "\t")
            }
            .joined(separator: "\n")
    }

    private func resolvedTableSeparators(from rows: [[OCRTextBlock]]) -> [CGFloat] {
        let inferredSeparators = inferredTableSeparators(from: rows)
        let explicitGuides = normalizedTableGuides()

        guard !explicitGuides.isEmpty else {
            return inferredSeparators
        }

        let widths = rows.flatMap { $0.map(\.boundingBox.width) }.sorted()
        let medianWidth = widths.isEmpty ? CGFloat(0.08) : widths[widths.count / 2]
        let tolerance = max(0.026, min(0.065, medianWidth * 0.85))

        var merged = inferredSeparators
        for guide in explicitGuides {
            if let index = merged.firstIndex(where: { abs($0 - guide) <= tolerance }) {
                merged[index] = (merged[index] + guide) / 2
            } else {
                merged.append(guide)
            }
        }

        return merged.sorted()
    }

    private func heuristicTableText(from rows: [[OCRTextBlock]]) -> String? {
        let segmentedRows = rows.map(segmentedCells)
        if let text = normalizedTableText(from: segmentedRows) {
            return text
        }

        let textRows = rows.map { row in
            row
                .map(\.text)
                .map(trimTrailingSpaces)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return whitespaceTokenTableText(from: textRows)
    }

    private func groupedLines(lineThreshold: CGFloat) -> [[OCRTextBlock]] {
        let byY = blocks.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        var lines: [[OCRTextBlock]] = []
        for block in byY {
            if let lastInLine = lines.last?.last,
               abs(block.boundingBox.midY - lastInLine.boundingBox.midY) < lineThreshold {
                lines[lines.count - 1].append(block)
            } else {
                lines.append([block])
            }
        }
        return lines
    }

    private func codeLineText(_ line: [OCRTextBlock], baseX: CGFloat, indentUnit: CGFloat) -> String {
        guard let first = line.first else {
            return ""
        }

        let indentLevel = max(0, min(8, Int(((first.boundingBox.minX - baseX) / indentUnit).rounded())))
        var text = String(repeating: "    ", count: indentLevel)

        for (index, block) in line.enumerated() {
            let token = sanitizeCodeToken(block.text)

            if index > 0 {
                let previous = line[index - 1]
                if shouldInsertCodeSpace(after: previous, before: block) {
                    text.append(" ")
                }
            }

            text.append(token)
        }

        return trimTrailingSpaces(text)
    }

    private func inferredTableSeparators(from rows: [[OCRTextBlock]]) -> [CGFloat] {
        struct GapCluster {
            var center: CGFloat
            var totalGap: CGFloat
            var supportRows: Set<Int>

            var averageGap: CGFloat {
                guard !supportRows.isEmpty else { return 0 }
                return totalGap / CGFloat(supportRows.count)
            }
        }

        let widths = rows.flatMap { $0.map(\.boundingBox.width) }.sorted()
        let medianWidth = widths.isEmpty ? CGFloat(0.08) : widths[widths.count / 2]
        let tolerance = max(0.024, min(0.08, medianWidth * 0.9))
        let minimumSupport = max(2, Int(ceil(Double(rows.count) * 0.5)))

        var clusters: [GapCluster] = []
        for (rowIndex, row) in rows.enumerated() {
            let sortedRow = row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            guard sortedRow.count >= 2 else {
                continue
            }

            let gaps = zip(sortedRow, sortedRow.dropFirst()).map { previous, current in
                (
                    center: (previous.boundingBox.maxX + current.boundingBox.minX) / 2,
                    width: max(0, current.boundingBox.minX - previous.boundingBox.maxX)
                )
            }
            let maxGap = gaps.map(\.width).max() ?? 0
            let rowThreshold = max(0.024, maxGap * 0.45)

            for gap in gaps where gap.width >= rowThreshold {
                if let index = clusters.firstIndex(where: { abs($0.center - gap.center) <= tolerance }) {
                    let existing = clusters[index]
                    var updatedRows = existing.supportRows
                    updatedRows.insert(rowIndex)
                    let newSupport = max(1, updatedRows.count)
                    clusters[index] = GapCluster(
                        center: ((existing.center * CGFloat(existing.supportRows.count)) + gap.center) / CGFloat(newSupport),
                        totalGap: existing.totalGap + gap.width,
                        supportRows: updatedRows
                    )
                } else {
                    clusters.append(
                        GapCluster(
                            center: gap.center,
                            totalGap: gap.width,
                            supportRows: [rowIndex]
                        )
                    )
                }
            }
        }

        let supportedClusters = clusters.filter { $0.supportRows.count >= minimumSupport }
        guard let strongestGap = supportedClusters.map(\.averageGap).max() else {
            return []
        }

        return supportedClusters
            .filter { $0.averageGap >= max(0.024, strongestGap * 0.4) }
            .sorted { $0.center < $1.center }
            .map(\.center)
    }

    private func normalizedTableGuides() -> [CGFloat] {
        let filtered = tableGuides
            .filter { (0.05...0.95).contains($0) }
            .sorted()

        guard !filtered.isEmpty else {
            return []
        }

        var normalized: [CGFloat] = []
        for guide in filtered {
            if let last = normalized.last, abs(last - guide) <= 0.028 {
                normalized[normalized.count - 1] = (last + guide) / 2
            } else {
                normalized.append(guide)
            }
        }

        return normalized
    }

    private func tableCells(for row: [OCRTextBlock], separators: [CGFloat]) -> [String] {
        guard !separators.isEmpty else {
            return []
        }

        var cells = Array(repeating: "", count: separators.count + 1)

        for block in row {
            let index = separators.firstIndex(where: { block.boundingBox.midX < $0 }) ?? separators.count
            let token = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { continue }

            if cells[index].isEmpty {
                cells[index] = token
            } else {
                cells[index].append(" ")
                cells[index].append(token)
            }
        }

        return cells.map(trimTrailingSpaces)
    }

    private func segmentedCells(for row: [OCRTextBlock]) -> [String] {
        let sortedRow = row.sorted { $0.boundingBox.midX < $1.boundingBox.midX }
        guard !sortedRow.isEmpty else {
            return []
        }

        if sortedRow.count == 1 {
            return splitSingleBlockRowText(sortedRow[0].text)
        }

        let gaps = zip(sortedRow, sortedRow.dropFirst()).map { current, next in
            max(0, next.boundingBox.minX - current.boundingBox.maxX)
        }
        let positiveGaps = gaps.filter { $0 > 0.003 }.sorted()
        let medianGap = positiveGaps.isEmpty ? CGFloat(0) : positiveGaps[positiveGaps.count / 2]
        let boundaryThreshold = max(0.028, medianGap * 1.9)

        var cells: [String] = []
        var currentCell = trimTrailingSpaces(sortedRow[0].text)

        for (index, block) in sortedRow.dropFirst().enumerated() {
            let token = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { continue }

            if gaps[index] >= boundaryThreshold {
                cells.append(currentCell)
                currentCell = token
                continue
            }

            if currentCell.isEmpty {
                currentCell = token
            } else {
                currentCell.append(" ")
                currentCell.append(token)
            }
        }

        if !currentCell.isEmpty {
            cells.append(trimTrailingSpaces(currentCell))
        }

        if cells.count >= 2 {
            return cells
        }

        return splitSingleBlockRowText(cells.first ?? sortedRow[0].text)
    }

    private func splitSingleBlockRowText(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        if trimmed.contains("\t") {
            let tabCells = trimmed
                .split(separator: "\t", omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            if tabCells.count >= 2 {
                return tabCells
            }
        }

        let multiSpacePattern = #"\s{2,}"#
        if let regex = try? NSRegularExpression(pattern: multiSpacePattern) {
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            let matches = regex.matches(in: trimmed, options: [], range: range)
            if !matches.isEmpty {
                let nsString = trimmed as NSString
                var cells: [String] = []
                var location = 0

                for match in matches {
                    let segment = nsString.substring(with: NSRange(location: location, length: match.range.location - location))
                    cells.append(segment.trimmingCharacters(in: .whitespacesAndNewlines))
                    location = match.range.location + match.range.length
                }

                let tail = nsString.substring(from: location)
                cells.append(tail.trimmingCharacters(in: .whitespacesAndNewlines))

                let filtered = cells.filter { !$0.isEmpty }
                if filtered.count >= 2 {
                    return filtered
                }
            }
        }

        return [trimmed]
    }

    private func normalizedTableText(from rows: [[String]]) -> String? {
        let multiColumnRows = rows.filter { row in
            row.filter { !$0.isEmpty }.count >= 2
        }

        guard multiColumnRows.count >= 2 else {
            return nil
        }

        let widthCounts = multiColumnRows.reduce(into: [Int: Int]()) { result, row in
            result[row.count, default: 0] += 1
        }
        guard let targetWidth = widthCounts.max(by: { lhs, rhs in
            lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value < rhs.value
        })?.key,
              targetWidth >= 2,
              let support = widthCounts[targetWidth],
              support >= 2 else {
            return nil
        }

        let normalizedRows = collapsedContinuationRows(rows.map { row in
            normalize(row: row, to: targetWidth)
        })

        let normalizedMultiColumnRows = normalizedRows.filter { row in
            row.filter { !$0.isEmpty }.count >= 2
        }
        guard normalizedMultiColumnRows.count >= 2 else {
            return nil
        }

        return normalizedRows
            .map { $0.joined(separator: "\t") }
            .joined(separator: "\n")
    }

    private func whitespaceTokenTableText(from rows: [String]) -> String? {
        let tokenRows = rows.map { row in
            row
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
        }

        let candidateRows = tokenRows.filter { (2...4).contains($0.count) }
        guard candidateRows.count >= 2 else {
            return nil
        }

        let widthCounts = candidateRows.reduce(into: [Int: Int]()) { result, row in
            result[row.count, default: 0] += 1
        }
        guard let targetWidth = widthCounts.max(by: { lhs, rhs in
            lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value < rhs.value
        })?.key,
              let support = widthCounts[targetWidth],
              support >= max(2, candidateRows.count - 1) else {
            return nil
        }

        return collapsedContinuationRows(tokenRows.map { normalize(row: $0, to: targetWidth) })
            .map { $0.joined(separator: "\t") }
            .joined(separator: "\n")
    }

    private func normalize(row: [String], to width: Int) -> [String] {
        guard width > 0 else {
            return row
        }

        let trimmedRow = row.map(trimTrailingSpaces)
        guard trimmedRow.count != width else {
            return trimmedRow
        }

        if trimmedRow.count > width {
            let head = Array(trimmedRow.prefix(width - 1))
            let tail = trimmedRow.dropFirst(width - 1).joined(separator: " ")
            return head + [tail]
        }

        return trimmedRow + Array(repeating: "", count: width - trimmedRow.count)
    }

    private func collapsedContinuationRows(_ rows: [[String]]) -> [[String]] {
        let width = rows.map(\.count).max() ?? 0
        guard rows.count >= 3, width >= 2 else {
            return rows
        }

        let normalizedRows = rows.map { row in
            row.map(trimTrailingSpaces) + Array(repeating: "", count: max(0, width - row.count))
        }

        var collapsed: [[String]] = []
        for row in normalizedRows {
            let nonEmptyCells = row.enumerated().filter { !$0.element.isEmpty }
            if let lastIndex = collapsed.indices.last,
               collapsed.count >= 2,
               shouldMergeContinuationRow(
                   row,
                   nonEmptyCells: nonEmptyCells,
                   into: collapsed[lastIndex],
                   width: width
               ) {
                var previous = collapsed[lastIndex]
                for (index, value) in nonEmptyCells {
                    previous[index] = mergedTableCellText(previous[index], with: value)
                }
                collapsed[lastIndex] = previous
            } else {
                collapsed.append(row)
            }
        }

        return collapsed
    }

    private func shouldMergeContinuationRow(
        _ row: [String],
        nonEmptyCells: [(offset: Int, element: String)],
        into previous: [String],
        width: Int
    ) -> Bool {
        let sparseThreshold = width >= 4 ? 2 : 1
        guard !nonEmptyCells.isEmpty,
              nonEmptyCells.count <= sparseThreshold else {
            return false
        }

        let previousNonEmptyCells = previous.enumerated().filter { !$0.element.isEmpty }
        guard previousNonEmptyCells.count >= 2,
              nonEmptyCells.count < previousNonEmptyCells.count else {
            return false
        }

        let previousColumns = Set(previousNonEmptyCells.map(\.offset))
        let candidateColumns = Set(nonEmptyCells.map(\.offset))
        guard candidateColumns.isSubset(of: previousColumns) else {
            return false
        }

        if looksLikeSparseSummaryRow(nonEmptyCells, width: width) {
            return false
        }

        if nonEmptyCells.count == 1,
           let cell = nonEmptyCells.first,
           cell.offset == width - 1,
           looksLikeStandaloneTableValue(cell.element) {
            return false
        }

        return true
    }

    private func mergedTableCellText(_ existing: String, with continuation: String) -> String {
        let existingTrimmed = trimTrailingSpaces(existing)
        let continuationTrimmed = trimTrailingSpaces(continuation)

        guard !existingTrimmed.isEmpty else {
            return continuationTrimmed
        }

        guard !continuationTrimmed.isEmpty else {
            return existingTrimmed
        }

        return trimTrailingSpaces(existingTrimmed + " " + continuationTrimmed)
    }

    private func looksLikeSparseSummaryRow(
        _ nonEmptyCells: [(offset: Int, element: String)],
        width: Int
    ) -> Bool {
        guard nonEmptyCells.count == 2,
              let first = nonEmptyCells.first,
              let last = nonEmptyCells.last,
              first.offset < last.offset,
              last.offset == width - 1,
              last.offset - first.offset > 1,
              looksLikeStandaloneTableValue(last.element) else {
            return false
        }

        return !trimTrailingSpaces(first.element).isEmpty
    }

    private func looksLikeStandaloneTableValue(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        return trimmed.range(
            of: #"^[\p{Sc}]?[-+]?[\d.,]+(?:[%]|[A-Za-z]{0,3})?$"#,
            options: .regularExpression
        ) != nil
    }

    private func shouldInsertCodeSpace(after previous: OCRTextBlock, before current: OCRTextBlock) -> Bool {
        let previousText = sanitizeCodeToken(previous.text)
        let currentText = sanitizeCodeToken(current.text)
        guard !previousText.isEmpty, !currentText.isEmpty else {
            return false
        }

        let gap = current.boundingBox.minX - previous.boundingBox.maxX
        if gap < 0.006 {
            return false
        }

        let noSpaceAfterCharacters = CharacterSet(charactersIn: "([{")
        let noSpaceBeforeCharacters = CharacterSet(charactersIn: "),.;:]}")

        if previousText.unicodeScalars.last.map(noSpaceAfterCharacters.contains) == true {
            return false
        }

        if currentText == "(" {
            let keywordsRequiringSpaceBeforeParen: Set<String> = ["if", "while", "switch", "for", "guard", "catch"]
            return keywordsRequiringSpaceBeforeParen.contains(previousText)
        }

        if currentText.unicodeScalars.first.map(noSpaceBeforeCharacters.contains) == true {
            return false
        }

        if currentText == "." || previousText == "." || currentText == "::" || previousText == "::" {
            return false
        }

        return true
    }

    private func sanitizeCodeToken(_ token: String) -> String {
        token
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "•", with: "*")
    }

    private func trimTrailingSpaces(_ value: String) -> String {
        var scalars = value.unicodeScalars
        while let last = scalars.last, CharacterSet.whitespaces.contains(last) {
            scalars.removeLast()
        }
        return String(String.UnicodeScalarView(scalars))
    }

    /// Ortalama güven skoru
    var averageConfidence: Float {
        guard !blocks.isEmpty else { return 0 }
        return blocks.reduce(0) { $0 + $1.confidence } / Float(blocks.count)
    }
}
