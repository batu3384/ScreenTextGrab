import AppKit
import SwiftUI

struct TableReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var document = TableReviewDocument(rows: [[""]])
    @State private var feedback: InlineFeedback?

    private let cellWidth: CGFloat = 176

    private var session: TableReviewSession? {
        appState.activeTableReview
    }

    private var currentPreset: CaptureOutputPreset? {
        guard let session else {
            return nil
        }

        return session.entry.outputPreset == .office ? nil : session.entry.outputPreset
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if let session {
                content(for: session)
            } else {
                emptyState
            }
        }
        .background(
            LinearGradient(
                colors: [Color.surfaceTop.opacity(0.10), Color.surfaceBottom.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear(perform: loadCurrentSession)
        .onChange(of: appState.activeTableReview?.id, initial: false) {
            loadCurrentSession()
        }
        .onDisappear {
            appState.clearTableReview()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.pair("Tablo Duzenleyici", "Table Editor"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(L10n.pair("OCR ile cikan tabloyu hucre bazinda duzelt, sonra Office uyumlu sekilde yeniden kopyala.", "Fix the OCR table cell by cell, then copy it again in an Office-friendly format."))
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            if let session {
                VStack(alignment: .trailing, spacing: 8) {
                    tableReviewBadge(session.entry.captureMode.title, tint: .accentWarm)
                    tableReviewBadge(session.entry.outputPreset.title, tint: .accentMint)

                    if let source = session.entry.source?.displayName {
                        tableReviewBadge(source, tint: .accentNeutral)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.96))
    }

    private func content(for session: TableReviewSession) -> some View {
        VStack(spacing: 0) {
            tableToolbar

            Divider()

            tableGrid

            Divider()

            tableFooter
        }
    }

    private var tableToolbar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                tableReviewBadge(L10n.usesEnglish ? "\(document.rowCount) Rows" : "\(document.rowCount) Satir", tint: .accentCool)
                tableReviewBadge(L10n.usesEnglish ? "\(document.columnCount) Columns" : "\(document.columnCount) Sutun", tint: .accentMint)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    tableReviewToolButton(title: L10n.pair("Satir Ekle", "Add Row"), icon: "plus", tint: .accentCool, action: addRow)
                    tableReviewToolButton(title: L10n.pair("Sutun Ekle", "Add Column"), icon: "rectangle.split.3x1", tint: .accentCool, action: addColumn)
                    tableReviewToolButton(title: L10n.pair("Son Satiri Sil", "Remove Last Row"), icon: "minus", tint: .accentRose, action: removeLastRow)
                }

                HStack(spacing: 10) {
                    tableReviewToolButton(title: L10n.pair("Son Sutunu Sil", "Remove Last Column"), icon: "rectangle.split.3x1.fill", tint: .accentRose, action: removeLastColumn)
                    tableReviewToolButton(title: L10n.pair("Bos Kenarlari Temizle", "Trim Empty Edges"), icon: "wand.and.stars", tint: .accentWarm, action: trimEmptyEdges)
                    tableReviewToolButton(title: L10n.pair("Sifirla", "Reset"), icon: "arrow.counterclockwise", tint: .accentNeutral, action: resetDocument)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var tableGrid: some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .topLeading, horizontalSpacing: 10, verticalSpacing: 10) {
                tableHeaderRow

                ForEach(0..<document.rowCount, id: \.self) { rowIndex in
                    tableDataRow(rowIndex)
                }
            }
            .padding(24)
        }
    }

    private var tableHeaderRow: some View {
        GridRow {
            Text("")
                .frame(width: 48)

            ForEach(0..<document.columnCount, id: \.self) { columnIndex in
                Text("S\(columnIndex + 1)")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: cellWidth, alignment: .leading)
            }
        }
    }

    private func tableDataRow(_ rowIndex: Int) -> some View {
        GridRow {
            Text("\(rowIndex + 1)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            ForEach(0..<document.columnCount, id: \.self) { columnIndex in
                tableCell(rowIndex: rowIndex, columnIndex: columnIndex)
            }
        }
    }

    private func tableCell(rowIndex: Int, columnIndex: Int) -> some View {
        TextField(
            rowIndex == 0 ? L10n.pair("Baslik", "Header") : L10n.pair("Hucre", "Cell"),
            text: cellBinding(row: rowIndex, column: columnIndex),
            axis: .vertical
        )
        .textFieldStyle(.plain)
        .font(.system(size: 12.5, weight: rowIndex == 0 ? .semibold : .medium, design: .rounded))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: cellWidth, alignment: .topLeading)
        .frame(minHeight: rowIndex == 0 ? 52 : 46, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(rowIndex == 0 ? Color.accentCool.opacity(0.26) : Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var tableFooter: some View {
        HStack(alignment: .center, spacing: 12) {
            if let feedback {
                Text(feedback.message)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(feedback.tint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if let preset = currentPreset {
                tableReviewPrimaryButton(
                    title: L10n.usesEnglish ? "Copy as \(preset.title)" : "\(preset.title) ile Kopyala",
                    icon: "doc.on.doc",
                    tint: .accentNeutral
                ) {
                    copyReviewedTable(as: preset)
                }
            }

            tableReviewPrimaryButton(
                title: L10n.pair("Office Olarak Kopyala", "Copy as Office"),
                icon: "tablecells",
                tint: .accentCool
            ) {
                copyReviewedTable(as: .office)
            }

            tableReviewPrimaryButton(
                title: L10n.pair("Kapat", "Close"),
                icon: "xmark",
                tint: .accentRose
            ) {
                closeWindow()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "tablecells")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.secondary)

            Text(L10n.pair("Duzeltilecek aktif bir tablo secili degil.", "No active table is selected for review."))
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Text(L10n.pair("Menu bar'dan son tabloyu ya da Gecmis sekmesindeki bir tablo kaydini acabilirsin.", "Open the latest table from the menu bar or a table entry from the History tab."))
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            tableReviewPrimaryButton(
                title: L10n.pair("Kapat", "Close"),
                icon: "xmark",
                tint: .accentNeutral
            ) {
                closeWindow()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func loadCurrentSession() {
        guard let session else {
            document = TableReviewDocument(rows: [[""]])
            feedback = nil
            return
        }

        document = TableReviewDocument(sourceText: session.sourceText)
        feedback = nil
    }

    private func cellBinding(row: Int, column: Int) -> Binding<String> {
        Binding(
            get: { document.cellValue(row: row, column: column) },
            set: { document.setCell(row: row, column: column, value: $0) }
        )
    }

    private func addRow() {
        document.appendRow()
        feedback = InlineFeedback(
            message: L10n.pair("Yeni satir eklendi.", "A new row was added."),
            tint: .accentCool
        )
    }

    private func addColumn() {
        document.appendColumn()
        feedback = InlineFeedback(
            message: L10n.pair("Yeni sutun eklendi.", "A new column was added."),
            tint: .accentCool
        )
    }

    private func removeLastRow() {
        document.removeLastRow()
        feedback = InlineFeedback(
            message: L10n.pair("Son satir kaldirildi.", "The last row was removed."),
            tint: .accentNeutral
        )
    }

    private func removeLastColumn() {
        document.removeLastColumn()
        feedback = InlineFeedback(
            message: L10n.pair("Son sutun kaldirildi.", "The last column was removed."),
            tint: .accentNeutral
        )
    }

    private func trimEmptyEdges() {
        document.trimEmptyEdges()
        feedback = InlineFeedback(
            message: L10n.pair("Bos kenarlar temizlendi.", "Empty edges were trimmed."),
            tint: .accentWarm
        )
    }

    private func resetDocument() {
        guard let session else {
            return
        }

        document.reset(from: session.sourceText)
        feedback = InlineFeedback(
            message: L10n.pair("Tablo ilk yakalanan haline dondu.", "The table was reset to its original captured state."),
            tint: .accentNeutral
        )
    }

    private func copyReviewedTable(as preset: CaptureOutputPreset) {
        guard let session else {
            return
        }

        let reviewedText = document.tsvText
        guard !reviewedText.isEmpty else {
            feedback = InlineFeedback(
                message: L10n.pair("Kopyalanacak tablo verisi bos.", "There is no table data to copy."),
                tint: .accentRose
            )
            return
        }

        guard let result = appState.coordinator?.copyCapturedText(
            rawText: reviewedText,
            captureMode: .table,
            contentKind: session.entry.contentKind,
            source: session.entry.source,
            outputPreset: preset,
            targetBundleIdentifier: appState.activeTargetBundleIdentifier
        ) else {
            feedback = InlineFeedback(
                message: L10n.pair("Kopyalama servisi su anda hazir degil.", "The copy service is not ready right now."),
                tint: .accentRose
            )
            return
        }

        switch result {
        case .success:
            feedback = InlineFeedback(
                message: L10n.usesEnglish ? "\(preset.title) output was copied to the clipboard." : "\(preset.title) cikti panoya kopyalandi.",
                tint: .accentCool
            )
        case .failedWrite, .failedReadback:
            feedback = InlineFeedback(
                message: L10n.pair("Duzenlenen tablo panoya yazilamadi.", "The reviewed table could not be written to the clipboard."),
                tint: .accentRose
            )
        }
    }

    private func closeWindow() {
        appState.clearTableReview()
        dismiss()
    }

    private func tableReviewBadge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule(style: .continuous))
    }

    private func tableReviewToolButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func tableReviewPrimaryButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.9))
            )
        }
        .buttonStyle(.plain)
    }
}
