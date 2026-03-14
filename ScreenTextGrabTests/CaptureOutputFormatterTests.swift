import XCTest
import AppKit
@testable import ScreenTextGrab

final class CaptureOutputFormatterTests: XCTestCase {
    func testMarkdownPresetWrapsCodeBlock() {
        let output = CaptureOutputFormatter.format(
            rawText: "if (value) {\n    print(value)\n}",
            captureMode: .code,
            contentKind: .text,
            preset: .markdown
        )

        XCTAssertEqual(output, "```text\nif (value) {\n    print(value)\n}\n```")
    }

    func testMarkdownPresetBuildsMarkdownTableFromTSV() {
        let output = CaptureOutputFormatter.format(
            rawText: "Urun\tFiyat\nElma\t12.99",
            captureMode: .table,
            contentKind: .text,
            preset: .markdown
        )

        XCTAssertEqual(output, "| Urun | Fiyat |\n| --- | --- |\n| Elma | 12.99 |")
    }

    func testCleanedPresetFlattensSubtitleLines() {
        let output = CaptureOutputFormatter.format(
            rawText: "Merhaba\nDunya\n\nNasilsin",
            captureMode: .subtitle,
            contentKind: .text,
            preset: .cleaned
        )

        XCTAssertEqual(output, "Merhaba Dunya\nNasilsin")
    }

    func testJSONPresetIncludesMetadataAndRows() {
        let output = CaptureOutputFormatter.format(
            rawText: "Urun\tFiyat\nElma\t12.99",
            captureMode: .table,
            contentKind: .text,
            preset: .json,
            source: .init(appName: "Safari", bundleIdentifier: "com.apple.Safari")
        )

        XCTAssertTrue(output.contains("\"mode\""))
        XCTAssertTrue(output.contains("\"rows\""))
        XCTAssertTrue(output.contains("com.apple.Safari"))
    }

    func testOfficePresetBuildsRichTablePayload() {
        let payload = CaptureOutputFormatter.clipboardPayload(
            rawText: "Urun\tFiyat\nElma\t12.99",
            captureMode: .table,
            contentKind: .text,
            preset: .office
        )

        XCTAssertEqual(payload.string, "Urun\tFiyat\nElma\t12.99")
        XCTAssertEqual(payload.tabularText, "Urun\tFiyat\nElma\t12.99")
        XCTAssertTrue(payload.html?.contains("<table") == true)
        XCTAssertTrue(payload.html?.contains("<th") == true)
        XCTAssertTrue(payload.html?.contains("Elma") == true)
    }

    func testOfficePresetRecoversTableFromWhitespaceSeparatedRows() {
        let payload = CaptureOutputFormatter.clipboardPayload(
            rawText: "Urun Fiyat\nElma 12.99\nArmut 9.50",
            captureMode: .table,
            contentKind: .text,
            preset: .office
        )

        XCTAssertEqual(payload.string, "Urun\tFiyat\nElma\t12.99\nArmut\t9.50")
        XCTAssertEqual(payload.tabularText, "Urun\tFiyat\nElma\t12.99\nArmut\t9.50")
        XCTAssertTrue(payload.html?.contains("<table") == true)
    }

    func testOfficePresetMergesSparseContinuationRowsIntoPreviousCell() {
        let payload = CaptureOutputFormatter.clipboardPayload(
            rawText: "Urun\tAciklama\tFiyat\nKahve\tCok iyi\t12.99\n\tPremium Karisim\t\nCay\tHafif\t8.50",
            captureMode: .table,
            contentKind: .text,
            preset: .office
        )

        XCTAssertEqual(
            payload.tabularText,
            "Urun\tAciklama\tFiyat\nKahve\tCok iyi Premium Karisim\t12.99\nCay\tHafif\t8.50"
        )
        XCTAssertTrue(payload.html?.contains("Cok iyi Premium Karisim") == true)
    }

    func testOfficePresetBuildsMergedCellsForSparseSubtotalRows() {
        let payload = CaptureOutputFormatter.clipboardPayload(
            rawText: "Kategori\tOcak\tSubat\tMart\nIcekler\t12\t14\t16\nToplam\t\t\t42",
            captureMode: .table,
            contentKind: .text,
            preset: .office
        )

        XCTAssertEqual(payload.tabularText, "Kategori\tOcak\tSubat\tMart\nIcekler\t12\t14\t16\nToplam\t\t\t42")
        XCTAssertTrue(payload.html?.contains("colspan=\"3\"") == true)
        XCTAssertTrue(payload.html?.contains(">Toplam<") == true)
    }

    func testOfficePresetBuildsWordFriendlyCodePayload() {
        let payload = CaptureOutputFormatter.clipboardPayload(
            rawText: "if (value) {\n    print(value)\n}",
            captureMode: .code,
            contentKind: .text,
            preset: .office
        )

        XCTAssertEqual(payload.string, "if (value) {\n    print(value)\n}")
        XCTAssertNil(payload.tabularText)
        XCTAssertTrue(payload.html?.contains("<pre") == true)
        XCTAssertTrue(payload.html?.contains("print(value)") == true)
    }

    func testOfficeTablePasteboardItemIncludesExcelFriendlyRepresentations() {
        let payload = CaptureOutputFormatter.clipboardPayload(
            rawText: "Urun\tFiyat\nElma\t12.99",
            captureMode: .table,
            contentKind: .text,
            preset: .office
        )

        let item = ClipboardManager.pasteboardItem(for: payload)

        XCTAssertNil(item.string(forType: .string))
        XCTAssertEqual(item.string(forType: .tabularText), "Urun\tFiyat\r\nElma\t12.99")
        XCTAssertEqual(item.string(forType: ClipboardManager.commaSeparatedValuesType), "Urun,Fiyat\r\nElma,12.99")
        XCTAssertTrue(item.string(forType: .html)?.contains("<table") == true)
        let rtfData = item.data(forType: .rtf)
        XCTAssertNotNil(rtfData)
        let rtfString = rtfData.flatMap { String(data: $0, encoding: .utf8) }
        XCTAssertTrue(rtfString?.contains("\\trowd") == true)
        XCTAssertTrue(rtfString?.contains("\\cellx") == true)
        XCTAssertEqual(
            item.types,
            [.html, .rtf, .tabularText, ClipboardManager.commaSeparatedValuesType]
        )
    }

    func testOfficeTablePasteboardItemPreservesMergedCellsInRTF() {
        let payload = CaptureOutputFormatter.clipboardPayload(
            rawText: "Kategori\tOcak\tSubat\tMart\nIcekler\t12\t14\t16\nToplam\t\t\t42",
            captureMode: .table,
            contentKind: .text,
            preset: .office,
            source: .init(appName: "Microsoft Word", bundleIdentifier: "com.microsoft.Word")
        )

        let item = ClipboardManager.pasteboardItem(for: payload)
        let rtfString = item.data(forType: .rtf).flatMap { String(data: $0, encoding: .utf8) }

        XCTAssertTrue(rtfString?.contains("\\clmgf") == true)
        XCTAssertTrue(rtfString?.contains("\\clmrg") == true)
        XCTAssertTrue(item.string(forType: .html)?.contains("colspan=\"3\"") == true)
    }

    func testOfficeTablePasteboardItemUsesSpreadsheetProfileForExcelTargets() {
        let payload = CaptureOutputFormatter.clipboardPayload(
            rawText: "Urun\tFiyat\nElma\t12.99",
            captureMode: .table,
            contentKind: .text,
            preset: .office,
            source: .init(appName: "Microsoft Excel", bundleIdentifier: "com.microsoft.Excel")
        )

        let item = ClipboardManager.pasteboardItem(for: payload)

        XCTAssertEqual(payload.targetProfile, .spreadsheet)
        XCTAssertEqual(item.string(forType: .tabularText), "Urun\tFiyat\r\nElma\t12.99")
        XCTAssertEqual(item.string(forType: ClipboardManager.commaSeparatedValuesType), "Urun,Fiyat\r\nElma,12.99")
        XCTAssertTrue(item.string(forType: .html)?.contains("<table") == true)
        XCTAssertNil(item.data(forType: .rtf))
        XCTAssertEqual(item.types, [.tabularText, ClipboardManager.commaSeparatedValuesType, .html])
    }

    func testOfficeTablePasteboardItemUsesWordProfileForWordTargets() {
        let payload = CaptureOutputFormatter.clipboardPayload(
            rawText: "Urun\tFiyat\nElma\t12.99",
            captureMode: .table,
            contentKind: .text,
            preset: .office,
            source: .init(appName: "Microsoft Word", bundleIdentifier: "com.microsoft.Word")
        )

        let item = ClipboardManager.pasteboardItem(for: payload)

        XCTAssertEqual(payload.targetProfile, .wordProcessor)
        XCTAssertTrue(item.data(forType: .rtf).flatMap { String(data: $0, encoding: .utf8) }?.contains("\\trowd") == true)
        XCTAssertTrue(item.string(forType: .html)?.contains("<table") == true)
        XCTAssertEqual(item.string(forType: .tabularText), "Urun\tFiyat\r\nElma\t12.99")
        XCTAssertNil(item.string(forType: ClipboardManager.commaSeparatedValuesType))
        XCTAssertEqual(item.types, [.rtf, .html, .tabularText])
    }

    func testOfficePayloadUsesExplicitTargetBundleIdentifierOverride() {
        let payload = CaptureOutputFormatter.clipboardPayload(
            rawText: "Urun\tFiyat\nElma\t12.99",
            captureMode: .table,
            contentKind: .text,
            preset: .office,
            source: .init(appName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
            targetBundleIdentifier: "com.microsoft.Word"
        )

        XCTAssertEqual(payload.targetProfile, .wordProcessor)
    }

    func testOfficeCodePasteboardItemKeepsPlainTextLineEndings() {
        let payload = CaptureOutputFormatter.clipboardPayload(
            rawText: "if (value) {\n    print(value)\n}",
            captureMode: .code,
            contentKind: .text,
            preset: .office
        )

        let item = ClipboardManager.pasteboardItem(for: payload)

        XCTAssertEqual(item.string(forType: .string), "if (value) {\n    print(value)\n}")
        XCTAssertNil(item.string(forType: .tabularText))
        XCTAssertNil(item.string(forType: ClipboardManager.commaSeparatedValuesType))
        XCTAssertTrue(item.string(forType: .html)?.contains("<pre") == true)
        XCTAssertEqual(item.types, [.html, .rtf, .string])
    }

    func testReadbackFallsBackToTabularTextForOfficeTables() {
        let pasteboard = NSPasteboard.withUniqueName()
        let payload = CaptureOutputFormatter.clipboardPayload(
            rawText: "Urun\tFiyat\nElma\t12.99",
            captureMode: .table,
            contentKind: .text,
            preset: .office
        )

        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([ClipboardManager.pasteboardItem(for: payload)]))
        XCTAssertEqual(
            ClipboardManager.readbackString(from: pasteboard, payload: payload),
            "Urun\tFiyat\r\nElma\t12.99"
        )
        XCTAssertEqual(
            ClipboardManager.readbackExpectation(for: payload),
            "Urun\tFiyat\r\nElma\t12.99"
        )
    }
}
