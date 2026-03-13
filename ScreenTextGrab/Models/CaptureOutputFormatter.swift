import Foundation

enum CaptureOutputFormatter {
    static func format(
        rawText: String,
        captureMode: CaptureMode,
        contentKind: ClipboardHistoryEntry.ContentKind,
        preset: CaptureOutputPreset,
        source: ClipboardHistoryEntry.SourceContext? = nil
    ) -> String {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }

        switch preset {
        case .smart:
            return trimmed
        case .plainText:
            return plainText(trimmed, captureMode: captureMode)
        case .cleaned:
            return cleanedText(trimmed, captureMode: captureMode)
        case .office:
            return officeText(trimmed, captureMode: captureMode)
        case .markdown:
            return markdownText(trimmed, captureMode: captureMode)
        case .json:
            return jsonText(
                trimmed,
                captureMode: captureMode,
                contentKind: contentKind,
                source: source
            )
        }
    }

    static func clipboardPayload(
        rawText: String,
        captureMode: CaptureMode,
        contentKind: ClipboardHistoryEntry.ContentKind,
        preset: CaptureOutputPreset,
        source: ClipboardHistoryEntry.SourceContext? = nil
    ) -> ClipboardPayload {
        let formattedText = format(
            rawText: rawText,
            captureMode: captureMode,
            contentKind: contentKind,
            preset: preset,
            source: source
        )

        guard !formattedText.isEmpty else {
            return ClipboardPayload(string: "")
        }

        guard preset == .office else {
            return ClipboardPayload(string: formattedText)
        }

        let officeTableText = captureMode == .table
            ? preferredOfficeTableText(primary: formattedText, fallback: rawText)
            : nil
        let targetProfile = ClipboardTargetProfile.resolve(for: source?.bundleIdentifier)

        return ClipboardPayload(
            string: officeTableText ?? formattedText,
            html: officeHTML(officeTableText ?? formattedText, captureMode: captureMode),
            tabularText: officeTableText,
            targetProfile: targetProfile
        )
    }

    private static func plainText(_ text: String, captureMode: CaptureMode) -> String {
        switch captureMode {
        case .table:
            return text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { row in
                    row
                        .split(separator: "\t", omittingEmptySubsequences: false)
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                        .joined(separator: " | ")
                }
                .joined(separator: "\n")
        default:
            return normalizeLineSpacing(in: text)
        }
    }

    private static func cleanedText(_ text: String, captureMode: CaptureMode) -> String {
        switch captureMode {
        case .subtitle:
            return cleanedSubtitleText(text)
        case .standard:
            return normalizeParagraphs(in: text)
        case .code, .table:
            return text
        }
    }

    private static func officeText(_ text: String, captureMode: CaptureMode) -> String {
        switch captureMode {
        case .standard:
            return normalizeParagraphs(in: text)
        case .subtitle:
            return cleanedSubtitleText(text)
        case .code, .table:
            return text
        }
    }

    private static func markdownText(_ text: String, captureMode: CaptureMode) -> String {
        switch captureMode {
        case .code:
            return "```text\n\(text)\n```"
        case .table:
            if let table = markdownTable(fromTSV: text) {
                return table
            }
            return "```text\n\(text)\n```"
        case .subtitle:
            return text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { line in
                    let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.isEmpty ? ">" : "> \(value)"
                }
                .joined(separator: "\n")
        case .standard:
            return normalizeParagraphs(in: text)
        }
    }

    private static func jsonText(
        _ text: String,
        captureMode: CaptureMode,
        contentKind: ClipboardHistoryEntry.ContentKind,
        source: ClipboardHistoryEntry.SourceContext?
    ) -> String {
        struct Payload: Encodable {
            let mode: String
            let contentKind: String
            let text: String
            let rows: [[String]]?
            let sourceApp: String?
            let sourceBundleIdentifier: String?
        }

        let rows = captureMode == .table ? tableRows(fromTSV: text) : nil
        let payload = Payload(
            mode: captureMode.rawValue,
            contentKind: contentKind.rawValue,
            text: text,
            rows: (rows?.count ?? 0) > 1 ? rows : nil,
            sourceApp: source?.appName,
            sourceBundleIdentifier: source?.bundleIdentifier
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload),
              let string = String(data: data, encoding: .utf8) else {
            return text
        }

        return string
    }

    private static func normalizeLineSpacing(in text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                line
                    .split(whereSeparator: \.isWhitespace)
                    .joined(separator: " ")
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeParagraphs(in text: String) -> String {
        text
            .components(separatedBy: "\n")
            .map { line in
                line
                    .split(whereSeparator: \.isWhitespace)
                    .joined(separator: " ")
            }
            .joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanedSubtitleText(_ text: String) -> String {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        var groups: [String] = []
        var currentGroup: [String] = []

        for line in lines {
            if line.isEmpty {
                if !currentGroup.isEmpty {
                    groups.append(currentGroup.joined(separator: " "))
                    currentGroup.removeAll()
                }
                continue
            }

            currentGroup.append(line)
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup.joined(separator: " "))
        }

        return groups
            .map { $0.replacingOccurrences(of: "  ", with: " ") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func officeHTML(_ text: String, captureMode: CaptureMode) -> String? {
        let body: String
        let metadata: String

        switch captureMode {
        case .table:
            body = officeHTMLTable(fromTSV: text) ?? officeHTMLPreformatted(text)
            metadata = """
            <meta name="ProgId" content="Excel.Sheet">
            <meta name="Generator" content="ScreenTextGrab">
            """
        case .code:
            body = officeHTMLPreformatted(text)
            metadata = "<meta name=\"Generator\" content=\"ScreenTextGrab\">"
        case .standard, .subtitle:
            body = officeHTMLParagraphs(text)
            metadata = "<meta name=\"Generator\" content=\"ScreenTextGrab\">"
        }

        return """
        <html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns:w="urn:schemas-microsoft-com:office:word">
          <head>
            <meta charset="utf-8">
            <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
            \(metadata)
          </head>
          <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; font-size: 13px; color: #111827;">
            \(body)
          </body>
        </html>
        """
    }

    private static func preferredOfficeTableText(primary: String, fallback rawText: String) -> String? {
        if let normalizedPrimary = normalizedOfficeTableText(from: primary) {
            return normalizedPrimary
        }

        return normalizedOfficeTableText(from: rawText)
    }

    private static func normalizedOfficeTableText(from text: String) -> String? {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return nil
        }

        let rows = normalized
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard rows.count >= 2 else {
            return nil
        }

        if normalized.contains("\t") {
            let tableRows = collapsedContinuationRows(tableRows(fromTSV: normalized))
            if tableRows.count >= 2, (tableRows.map(\.count).max() ?? 0) >= 2 {
                return tableRows
                    .map { $0.joined(separator: "\t") }
                    .joined(separator: "\n")
            }
        }

        if let pipeTable = normalizedOfficeTableText(fromRows: rows, separatorPattern: #"\s*\|\s*"#) {
            return pipeTable
        }

        if let wideSpaceTable = normalizedOfficeTableText(fromRows: rows, separatorPattern: #"\s{2,}"#) {
            return wideSpaceTable
        }

        let tokenRows = rows.map { row in
            row
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
        }

        return normalizedOfficeTableText(fromTokenRows: tokenRows)
    }

    private static func normalizedOfficeTableText(
        fromRows rows: [String],
        separatorPattern: String
    ) -> String? {
        guard let regex = try? NSRegularExpression(pattern: separatorPattern) else {
            return nil
        }

        let tokenRows = rows.map { row in
            split(row: row, using: regex)
        }

        return normalizedOfficeTableText(fromTokenRows: tokenRows)
    }

    private static func normalizedOfficeTableText(fromTokenRows rows: [[String]]) -> String? {
        let candidateRows = rows.filter { (2...6).contains($0.count) }
        guard candidateRows.count >= 2 else {
            return nil
        }

        let widthCounts = candidateRows.reduce(into: [Int: Int]()) { result, row in
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
            normalizeOfficeTableRow(row, to: targetWidth)
        })

        let multiColumnRows = normalizedRows.filter { row in
            row.filter { !$0.isEmpty }.count >= 2
        }
        guard multiColumnRows.count >= 2 else {
            return nil
        }

        return normalizedRows
            .map { $0.joined(separator: "\t") }
            .joined(separator: "\n")
    }

    private static func split(row: String, using regex: NSRegularExpression) -> [String] {
        let range = NSRange(row.startIndex..<row.endIndex, in: row)
        let matches = regex.matches(in: row, options: [], range: range)
        guard !matches.isEmpty else {
            return [row.trimmingCharacters(in: .whitespacesAndNewlines)]
        }

        let nsString = row as NSString
        var values: [String] = []
        var location = 0

        for match in matches {
            let length = match.range.location - location
            let segment = nsString.substring(with: NSRange(location: location, length: max(0, length)))
            values.append(segment.trimmingCharacters(in: .whitespacesAndNewlines))
            location = match.range.location + match.range.length
        }

        let tail = nsString.substring(from: location)
        values.append(tail.trimmingCharacters(in: .whitespacesAndNewlines))
        return values
    }

    private static func normalizeOfficeTableRow(_ row: [String], to width: Int) -> [String] {
        let trimmed = row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard trimmed.count != width else {
            return trimmed
        }

        if trimmed.count > width {
            let head = Array(trimmed.prefix(width - 1))
            let tail = trimmed.dropFirst(width - 1).joined(separator: " ")
            return head + [tail]
        }

        return trimmed + Array(repeating: "", count: width - trimmed.count)
    }

    private static func collapsedContinuationRows(_ rows: [[String]]) -> [[String]] {
        let width = rows.map(\.count).max() ?? 0
        guard rows.count >= 3, width >= 2 else {
            return rows
        }

        let normalizedRows = rows.map { row in
            row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } +
                Array(repeating: "", count: max(0, width - row.count))
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
                    previous[index] = mergeOfficeCellText(previous[index], with: value)
                }
                collapsed[lastIndex] = previous
            } else {
                collapsed.append(row)
            }
        }

        return collapsed
    }

    private static func shouldMergeContinuationRow(
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

    private static func mergeOfficeCellText(_ existing: String, with continuation: String) -> String {
        let existingTrimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let continuationTrimmed = continuation.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !existingTrimmed.isEmpty else {
            return continuationTrimmed
        }

        guard !continuationTrimmed.isEmpty else {
            return existingTrimmed
        }

        return existingTrimmed + " " + continuationTrimmed
    }

    private static func looksLikeSparseSummaryRow(
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

        return !first.element.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func looksLikeStandaloneTableValue(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        return trimmed.range(
            of: #"^[\p{Sc}]?[-+]?[\d.,]+(?:[%]|[A-Za-z]{0,3})?$"#,
            options: .regularExpression
        ) != nil
    }

    private static func officeHTMLParagraphs(_ text: String) -> String {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        return lines.map { line in
            if line.isEmpty {
                return "<p style=\"margin: 0 0 10px 0;\">&nbsp;</p>"
            }

            return "<p style=\"margin: 0 0 10px 0;\">\(escapeHTML(line))</p>"
        }
        .joined(separator: "\n")
    }

    private static func officeHTMLPreformatted(_ text: String) -> String {
        "<pre style=\"margin: 0; white-space: pre-wrap; font-family: Menlo, Consolas, 'SFMono-Regular', monospace; font-size: 12px; line-height: 1.45;\">\(escapeHTML(text))</pre>"
    }

    private static func officeHTMLTable(fromTSV text: String) -> String? {
        guard let layout = OfficeTableLayout.fromTSV(text) else {
            return nil
        }

        let width = layout.width
        guard width >= 2 else {
            return nil
        }

        let normalizedRows = layout.rows

        let headerRow = layout.renderCells(forRowAt: 0)
        let bodyRows = Array(normalizedRows.dropFirst())

        let header = headerRow.map { cell in
            htmlCell(
                tag: "th",
                value: cell.value,
                colspan: cell.colspan,
                style: "border: 1px solid #cbd5e1; background: #f8fafc; padding: 6px 8px; text-align: left; font-weight: 600;"
            )
        }.joined()

        let bodySourceRows: [[OfficeTableRenderCell]] = bodyRows.isEmpty
            ? [headerRow]
            : bodyRows.enumerated().map { index, _ in
                layout.renderCells(forRowAt: index + 1)
            }

        let body = bodySourceRows.map { row in
            let cells = row.map { cell in
                htmlCell(
                    tag: "td",
                    value: cell.value,
                    colspan: cell.colspan,
                    style: "border: 1px solid #cbd5e1; padding: 6px 8px; vertical-align: top;"
                )
            }.joined()

            return "<tr>\(cells)</tr>"
        }.joined(separator: "\n")

        return """
        <table border="1" cellpadding="0" cellspacing="0" style="border-collapse: collapse; border-spacing: 0; border: 1px solid #cbd5e1; font-size: 12px; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
          <thead>
            <tr>\(header)</tr>
          </thead>
          <tbody>
            \(body)
          </tbody>
        </table>
        """
    }

    private static func markdownTable(fromTSV text: String) -> String? {
        let rows = tableRows(fromTSV: text)
        guard rows.count >= 2 else {
            return nil
        }

        let width = rows.map(\.count).max() ?? 0
        guard width >= 2 else {
            return nil
        }

        let normalizedRows = rows.map { row in
            row + Array(repeating: "", count: max(0, width - row.count))
        }

        let header = normalizedRows[0]
        let divider = Array(repeating: "---", count: width)
        let body = normalizedRows.dropFirst()

        return ([header, divider] + body)
            .map { row in
                "| " + row.map(escapeMarkdownCell).joined(separator: " | ") + " |"
            }
            .joined(separator: "\n")
    }

    private static func tableRows(fromTSV text: String) -> [[String]] {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { row in
                row
                    .split(separator: "\t", omittingEmptySubsequences: false)
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            .filter { !$0.isEmpty }
    }

    private static func escapeMarkdownCell(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|")
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func htmlCell(
        tag: String,
        value: String,
        colspan: Int,
        style: String
    ) -> String {
        let attributes = colspan > 1 ? " colspan=\"\(colspan)\"" : ""
        let content = value.isEmpty ? "&nbsp;" : escapeHTML(value)
        return "<\(tag)\(attributes) style=\"\(style)\">\(content)</\(tag)>"
    }
}

struct OfficeTableRenderCell: Equatable, Sendable {
    let column: Int
    let value: String
    let colspan: Int
}

struct OfficeTableLayout: Equatable, Sendable {
    let rows: [[String]]
    let width: Int

    static func fromTSV(_ text: String) -> OfficeTableLayout? {
        let rows = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { row in
                row
                    .split(separator: "\t", omittingEmptySubsequences: false)
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            .filter { !$0.isEmpty }

        guard !rows.isEmpty else {
            return nil
        }

        let width = rows.map(\.count).max() ?? 0
        guard width >= 2 else {
            return nil
        }

        let normalizedRows = rows.map { row in
            row + Array(repeating: "", count: max(0, width - row.count))
        }

        return OfficeTableLayout(rows: normalizedRows, width: width)
    }

    func renderCells(forRowAt index: Int) -> [OfficeTableRenderCell] {
        guard rows.indices.contains(index) else {
            return []
        }

        return Self.renderCells(for: rows[index], width: width)
    }

    func physicalCells(forRowAt index: Int) -> [OfficeTablePhysicalCell] {
        guard rows.indices.contains(index) else {
            return []
        }

        let renderCells = renderCells(forRowAt: index)
        var physicalCells = Array(
            repeating: OfficeTablePhysicalCell(value: "", state: .normal),
            count: width
        )

        for cell in renderCells {
            physicalCells[cell.column] = OfficeTablePhysicalCell(
                value: cell.value,
                state: cell.colspan > 1 ? .mergeStart : .normal
            )

            guard cell.colspan > 1 else {
                continue
            }

            for offset in 1..<cell.colspan {
                let column = cell.column + offset
                guard physicalCells.indices.contains(column) else {
                    continue
                }
                physicalCells[column] = OfficeTablePhysicalCell(value: "", state: .mergeContinuation)
            }
        }

        return physicalCells
    }

    private static func renderCells(for row: [String], width: Int) -> [OfficeTableRenderCell] {
        let normalizedRow = row + Array(repeating: "", count: max(0, width - row.count))
        let nonEmptyIndices = normalizedRow.enumerated().compactMap { index, value in
            value.isEmpty ? nil : index
        }

        guard !nonEmptyIndices.isEmpty else {
            return (0..<width).map { OfficeTableRenderCell(column: $0, value: "", colspan: 1) }
        }

        if nonEmptyIndices.count == 1, let start = nonEmptyIndices.first {
            return sparseCells(
                for: normalizedRow,
                width: width,
                startColumn: start,
                nextColumn: width
            )
        }

        if nonEmptyIndices.count == 2,
           let start = nonEmptyIndices.first,
           let end = nonEmptyIndices.last,
           end == width - 1,
           end - start > 1 {
            return sparseCells(
                for: normalizedRow,
                width: width,
                startColumn: start,
                nextColumn: end
            ) + [
                OfficeTableRenderCell(column: end, value: normalizedRow[end], colspan: 1)
            ]
        }

        return (0..<width).map { column in
            OfficeTableRenderCell(column: column, value: normalizedRow[column], colspan: 1)
        }
    }

    private static func sparseCells(
        for row: [String],
        width: Int,
        startColumn: Int,
        nextColumn: Int
    ) -> [OfficeTableRenderCell] {
        let leadingCells = (0..<startColumn).map { column in
            OfficeTableRenderCell(column: column, value: row[column], colspan: 1)
        }
        let colspan = max(1, nextColumn - startColumn)
        let mergedCell = OfficeTableRenderCell(
            column: startColumn,
            value: row[startColumn],
            colspan: colspan
        )

        return leadingCells + [mergedCell]
    }
}

struct OfficeTablePhysicalCell: Equatable, Sendable {
    enum MergeState: Equatable, Sendable {
        case normal
        case mergeStart
        case mergeContinuation
    }

    let value: String
    let state: MergeState
}
