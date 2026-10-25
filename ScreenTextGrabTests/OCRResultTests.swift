import XCTest
@testable import ScreenTextGrab

final class OCRResultTests: XCTestCase {
    func testCodeModePreservesIndentationAndCodeSpacing() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "if", confidence: 0.95, boundingBox: CGRect(x: 0.10, y: 0.82, width: 0.05, height: 0.04)),
                OCRTextBlock(text: "(", confidence: 0.95, boundingBox: CGRect(x: 0.17, y: 0.82, width: 0.01, height: 0.04)),
                OCRTextBlock(text: "value", confidence: 0.95, boundingBox: CGRect(x: 0.19, y: 0.82, width: 0.12, height: 0.04)),
                OCRTextBlock(text: ")", confidence: 0.95, boundingBox: CGRect(x: 0.32, y: 0.82, width: 0.01, height: 0.04)),
                OCRTextBlock(text: "{", confidence: 0.95, boundingBox: CGRect(x: 0.35, y: 0.82, width: 0.01, height: 0.04)),
                OCRTextBlock(text: "print", confidence: 0.95, boundingBox: CGRect(x: 0.20, y: 0.72, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "(", confidence: 0.95, boundingBox: CGRect(x: 0.31, y: 0.72, width: 0.01, height: 0.04)),
                OCRTextBlock(text: "value", confidence: 0.95, boundingBox: CGRect(x: 0.33, y: 0.72, width: 0.12, height: 0.04)),
                OCRTextBlock(text: ")", confidence: 0.95, boundingBox: CGRect(x: 0.46, y: 0.72, width: 0.01, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        XCTAssertEqual(result.fullText(for: .code), "if (value) {\n    print(value)")
    }

    func testTableModeProducesTabSeparatedRows() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "Urun", confidence: 0.95, boundingBox: CGRect(x: 0.10, y: 0.82, width: 0.16, height: 0.04)),
                OCRTextBlock(text: "Fiyat", confidence: 0.95, boundingBox: CGRect(x: 0.56, y: 0.82, width: 0.12, height: 0.04)),
                OCRTextBlock(text: "Elma", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.72, width: 0.14, height: 0.04)),
                OCRTextBlock(text: "12.99", confidence: 0.95, boundingBox: CGRect(x: 0.57, y: 0.72, width: 0.12, height: 0.04)),
                OCRTextBlock(text: "Armut", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.62, width: 0.16, height: 0.04)),
                OCRTextBlock(text: "9.50", confidence: 0.95, boundingBox: CGRect(x: 0.58, y: 0.62, width: 0.10, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        XCTAssertEqual(result.fullText(for: .table), "Urun\tFiyat\nElma\t12.99\nArmut\t9.50")
    }

    func testTableModeFallsBackForSingleBlockRowsWithWideSpacing() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "Urun    Fiyat", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.82, width: 0.64, height: 0.04)),
                OCRTextBlock(text: "Elma    12.99", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.72, width: 0.64, height: 0.04)),
                OCRTextBlock(text: "Armut    9.50", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.62, width: 0.64, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        XCTAssertEqual(result.fullText(for: .table), "Urun\tFiyat\nElma\t12.99\nArmut\t9.50")
    }

    func testTableModeFallsBackForConsistentWhitespaceTokens() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "Urun Fiyat", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.82, width: 0.54, height: 0.04)),
                OCRTextBlock(text: "Elma 12.99", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.72, width: 0.54, height: 0.04)),
                OCRTextBlock(text: "Armut 9.50", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.62, width: 0.54, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        XCTAssertEqual(result.fullText(for: .table), "Urun\tFiyat\nElma\t12.99\nArmut\t9.50")
    }

    func testTableModeKeepsMultiWordCellsInSameColumn() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "Urun", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.82, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Adi", confidence: 0.95, boundingBox: CGRect(x: 0.20, y: 0.82, width: 0.08, height: 0.04)),
                OCRTextBlock(text: "Fiyat", confidence: 0.95, boundingBox: CGRect(x: 0.60, y: 0.82, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Elma", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.72, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Suyu", confidence: 0.95, boundingBox: CGRect(x: 0.20, y: 0.72, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "12.99", confidence: 0.95, boundingBox: CGRect(x: 0.60, y: 0.72, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Portakal", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.62, width: 0.15, height: 0.04)),
                OCRTextBlock(text: "Suyu", confidence: 0.95, boundingBox: CGRect(x: 0.25, y: 0.62, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "9.50", confidence: 0.95, boundingBox: CGRect(x: 0.60, y: 0.62, width: 0.09, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        XCTAssertEqual(
            result.fullText(for: .table),
            "Urun Adi\tFiyat\nElma Suyu\t12.99\nPortakal Suyu\t9.50"
        )
    }

    func testTableModeUsesDetectedGuideSeparatorsForTightColumns() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "Urun", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.82, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Adi", confidence: 0.95, boundingBox: CGRect(x: 0.20, y: 0.82, width: 0.08, height: 0.04)),
                OCRTextBlock(text: "Kategori", confidence: 0.95, boundingBox: CGRect(x: 0.55, y: 0.82, width: 0.12, height: 0.04)),
                OCRTextBlock(text: "Fiyat", confidence: 0.95, boundingBox: CGRect(x: 0.72, y: 0.82, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Elma", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.72, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Suyu", confidence: 0.95, boundingBox: CGRect(x: 0.20, y: 0.72, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Meyve", confidence: 0.95, boundingBox: CGRect(x: 0.56, y: 0.72, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "12.99", confidence: 0.95, boundingBox: CGRect(x: 0.72, y: 0.72, width: 0.10, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero,
            tableGuides: [0.69]
        )

        XCTAssertEqual(
            result.fullText(for: .table),
            "Urun Adi\tKategori\tFiyat\nElma Suyu\tMeyve\t12.99"
        )
    }

    func testTableModeMergesSparseContinuationRowsIntoPreviousCell() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "Urun", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.82, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Aciklama", confidence: 0.95, boundingBox: CGRect(x: 0.32, y: 0.82, width: 0.18, height: 0.04)),
                OCRTextBlock(text: "Fiyat", confidence: 0.95, boundingBox: CGRect(x: 0.72, y: 0.82, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Kahve", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.72, width: 0.12, height: 0.04)),
                OCRTextBlock(text: "Cok", confidence: 0.95, boundingBox: CGRect(x: 0.32, y: 0.72, width: 0.08, height: 0.04)),
                OCRTextBlock(text: "iyi", confidence: 0.95, boundingBox: CGRect(x: 0.42, y: 0.72, width: 0.06, height: 0.04)),
                OCRTextBlock(text: "12.99", confidence: 0.95, boundingBox: CGRect(x: 0.72, y: 0.72, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Premium", confidence: 0.95, boundingBox: CGRect(x: 0.32, y: 0.64, width: 0.16, height: 0.04)),
                OCRTextBlock(text: "Karisim", confidence: 0.95, boundingBox: CGRect(x: 0.50, y: 0.64, width: 0.14, height: 0.04)),
                OCRTextBlock(text: "Cay", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.54, width: 0.08, height: 0.04)),
                OCRTextBlock(text: "Hafif", confidence: 0.95, boundingBox: CGRect(x: 0.32, y: 0.54, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "8.50", confidence: 0.95, boundingBox: CGRect(x: 0.72, y: 0.54, width: 0.08, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        XCTAssertEqual(
            result.fullText(for: .table),
            "Urun\tAciklama\tFiyat\nKahve\tCok iyi Premium Karisim\t12.99\nCay\tHafif\t8.50"
        )
    }

    func testTableModeDoesNotMergeSparseNumericSummaryRow() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "Urun", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.82, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Aciklama", confidence: 0.95, boundingBox: CGRect(x: 0.32, y: 0.82, width: 0.18, height: 0.04)),
                OCRTextBlock(text: "Fiyat", confidence: 0.95, boundingBox: CGRect(x: 0.72, y: 0.82, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Kahve", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.72, width: 0.12, height: 0.04)),
                OCRTextBlock(text: "Cok", confidence: 0.95, boundingBox: CGRect(x: 0.32, y: 0.72, width: 0.08, height: 0.04)),
                OCRTextBlock(text: "iyi", confidence: 0.95, boundingBox: CGRect(x: 0.42, y: 0.72, width: 0.06, height: 0.04)),
                OCRTextBlock(text: "12.99", confidence: 0.95, boundingBox: CGRect(x: 0.72, y: 0.72, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "22.49", confidence: 0.95, boundingBox: CGRect(x: 0.72, y: 0.62, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Cay", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.52, width: 0.08, height: 0.04)),
                OCRTextBlock(text: "Hafif", confidence: 0.95, boundingBox: CGRect(x: 0.32, y: 0.52, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "8.50", confidence: 0.95, boundingBox: CGRect(x: 0.72, y: 0.52, width: 0.08, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        XCTAssertEqual(
            result.fullText(for: .table),
            "Urun\tAciklama\tFiyat\nKahve\tCok iyi\t12.99\n\t\t22.49\nCay\tHafif\t8.50"
        )
    }

    func testTableModeKeepsSparseLabelAndTrailingSummaryValueAsSeparateRow() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "Kategori", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.82, width: 0.16, height: 0.04)),
                OCRTextBlock(text: "Ocak", confidence: 0.95, boundingBox: CGRect(x: 0.36, y: 0.82, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Subat", confidence: 0.95, boundingBox: CGRect(x: 0.54, y: 0.82, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Mart", confidence: 0.95, boundingBox: CGRect(x: 0.74, y: 0.82, width: 0.08, height: 0.04)),
                OCRTextBlock(text: "Icekler", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.72, width: 0.14, height: 0.04)),
                OCRTextBlock(text: "12", confidence: 0.95, boundingBox: CGRect(x: 0.38, y: 0.72, width: 0.04, height: 0.04)),
                OCRTextBlock(text: "14", confidence: 0.95, boundingBox: CGRect(x: 0.56, y: 0.72, width: 0.04, height: 0.04)),
                OCRTextBlock(text: "16", confidence: 0.95, boundingBox: CGRect(x: 0.74, y: 0.72, width: 0.04, height: 0.04)),
                OCRTextBlock(text: "Toplam", confidence: 0.95, boundingBox: CGRect(x: 0.08, y: 0.62, width: 0.14, height: 0.04)),
                OCRTextBlock(text: "42", confidence: 0.95, boundingBox: CGRect(x: 0.74, y: 0.62, width: 0.04, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        XCTAssertEqual(
            result.fullText(for: .table),
            "Kategori\tOcak\tSubat\tMart\nIcekler\t12\t14\t16\nToplam\t\t\t42"
        )
    }

    // MARK: - Monospace Alignment

    func testMonospaceAlignedTextPreservesHorizontalPosition() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "Name", confidence: 0.95, boundingBox: CGRect(x: 0.10, y: 0.80, width: 0.08, height: 0.04)),
                OCRTextBlock(text: "Value", confidence: 0.95, boundingBox: CGRect(x: 0.50, y: 0.80, width: 0.10, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        let output = result.monospaceAlignedText()
        // col = Int(0.10 * 120) = 12, so "Name" starts after 12 spaces
        XCTAssertTrue(output.hasPrefix(String(repeating: " ", count: 12) + "Name"))
        // col = Int(0.50 * 120) = 60, so "Value" starts at position 60
        let valueIndex = output.index(output.startIndex, offsetBy: 60)
        XCTAssertEqual(output[valueIndex...], "Value")
        XCTAssertEqual(output.components(separatedBy: "\n").count, 1)
    }

    func testMonospaceAlignedTextProducesMultipleLines() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "Hello", confidence: 0.95, boundingBox: CGRect(x: 0.10, y: 0.80, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "World", confidence: 0.95, boundingBox: CGRect(x: 0.10, y: 0.72, width: 0.10, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        let output = result.monospaceAlignedText()
        let lines = output.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasSuffix("Hello"))
        XCTAssertTrue(lines[1].hasSuffix("World"))
    }

    func testMonospaceAlignedTextInsertsBlankLinesForLargeVerticalGap() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "Top", confidence: 0.95, boundingBox: CGRect(x: 0.10, y: 0.80, width: 0.06, height: 0.04)),
                OCRTextBlock(text: "Bottom", confidence: 0.95, boundingBox: CGRect(x: 0.10, y: 0.60, width: 0.12, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        let output = result.monospaceAlignedText()
        let lines = output.components(separatedBy: "\n")
        XCTAssertTrue(lines.first?.hasSuffix("Top") == true)
        XCTAssertTrue(lines.last?.hasSuffix("Bottom") == true)
        XCTAssertGreaterThan(lines.count, 2)
        XCTAssertTrue(lines.dropFirst().dropLast().allSatisfy { $0.isEmpty })
    }

    func testMonospaceAlignedTextEmptyBlocksReturnsEmpty() {
        let result = OCRResult(
            blocks: [],
            captureDate: Date(),
            sourceRect: .zero
        )

        XCTAssertEqual(result.monospaceAlignedText(), "")
    }

    func testMonospaceAlignedTextSingleBlock() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "Hello", confidence: 0.95, boundingBox: CGRect(x: 0.10, y: 0.80, width: 0.10, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        let output = result.monospaceAlignedText()
        XCTAssertTrue(output.hasSuffix("Hello"))
    }

    func testMonospaceAlignedTextSortsBlocksByXWithinLine() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "Right", confidence: 0.95, boundingBox: CGRect(x: 0.50, y: 0.80, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Left", confidence: 0.95, boundingBox: CGRect(x: 0.10, y: 0.80, width: 0.08, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        let output = result.monospaceAlignedText()
        let leftRange = output.range(of: "Left")!
        let rightRange = output.range(of: "Right")!
        XCTAssertLessThan(leftRange.lowerBound, rightRange.lowerBound)
    }

    func testMonospaceAlignedTextWithExplicitColumns() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "A", confidence: 0.95, boundingBox: CGRect(x: 0.10, y: 0.80, width: 0.02, height: 0.04)),
                OCRTextBlock(text: "B", confidence: 0.95, boundingBox: CGRect(x: 0.50, y: 0.80, width: 0.02, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        // With 40 columns: A at col 4, B at col 20
        let output40 = result.monospaceAlignedText(columns: 40)
        let indexB40 = output40.index(output40.startIndex, offsetBy: 20)
        XCTAssertEqual(output40[indexB40], "B")

        // With 200 columns: A at col 20, B at col 100
        let output200 = result.monospaceAlignedText(columns: 200)
        let indexB200 = output200.index(output200.startIndex, offsetBy: 100)
        XCTAssertEqual(output200[indexB200], "B")
    }

    func testMonospaceAlignedTextClampsColumnCount() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "Test", confidence: 0.95, boundingBox: CGRect(x: 0.10, y: 0.80, width: 0.08, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        // Columns below 20 should be clamped to 20, above 300 to 300
        let outputLow = result.monospaceAlignedText(columns: 5)
        let outputHigh = result.monospaceAlignedText(columns: 500)
        // Both should produce valid output with "Test" at the clamped column position
        XCTAssertTrue(outputLow.hasSuffix("Test"))
        XCTAssertTrue(outputHigh.hasSuffix("Test"))
    }

    // MARK: - Gap Tree Multi-column Sorting

    func testReadingOrderSortedTwoColumns() {
        // Sol sütun: 3 satır, sağ sütun: 3 satır
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "L1", confidence: 0.95, boundingBox: CGRect(x: 0.05, y: 0.85, width: 0.06, height: 0.04)),
                OCRTextBlock(text: "L2", confidence: 0.95, boundingBox: CGRect(x: 0.05, y: 0.75, width: 0.06, height: 0.04)),
                OCRTextBlock(text: "L3", confidence: 0.95, boundingBox: CGRect(x: 0.05, y: 0.65, width: 0.06, height: 0.04)),
                OCRTextBlock(text: "R1", confidence: 0.95, boundingBox: CGRect(x: 0.60, y: 0.85, width: 0.06, height: 0.04)),
                OCRTextBlock(text: "R2", confidence: 0.95, boundingBox: CGRect(x: 0.60, y: 0.75, width: 0.06, height: 0.04)),
                OCRTextBlock(text: "R3", confidence: 0.95, boundingBox: CGRect(x: 0.60, y: 0.65, width: 0.06, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        let sorted = result.readingOrderSortedBlocks()
        let texts = sorted.map(\.text)

        // Sol sütun tamamen önce, sonra sağ sütun
        XCTAssertEqual(texts, ["L1", "L2", "L3", "R1", "R2", "R3"])
    }

    func testReadingOrderSortedSingleColumnReturnsOriginal() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "A", confidence: 0.95, boundingBox: CGRect(x: 0.10, y: 0.80, width: 0.04, height: 0.04)),
                OCRTextBlock(text: "B", confidence: 0.95, boundingBox: CGRect(x: 0.10, y: 0.70, width: 0.04, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        let sorted = result.readingOrderSortedBlocks()
        XCTAssertEqual(sorted.map(\.text), ["A", "B"])
    }

    func testMonospaceWithMulticolumnSorting() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "Left1", confidence: 0.95, boundingBox: CGRect(x: 0.05, y: 0.85, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Left2", confidence: 0.95, boundingBox: CGRect(x: 0.05, y: 0.75, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Right1", confidence: 0.95, boundingBox: CGRect(x: 0.60, y: 0.85, width: 0.12, height: 0.04)),
                OCRTextBlock(text: "Right2", confidence: 0.95, boundingBox: CGRect(x: 0.60, y: 0.75, width: 0.12, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        let output = result.monospaceAlignedText(columns: 120, multicolumnSorting: true)
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

        // Sol sütun satırları önce, sonra sağ sütun satırları
        XCTAssertTrue(lines[0].contains("Left1"))
        XCTAssertTrue(lines[1].contains("Left2"))
        XCTAssertTrue(lines[2].contains("Right1"))
        XCTAssertTrue(lines[3].contains("Right2"))
    }

    func testMonospaceWithoutMulticolumnSortingInterleavesRows() {
        let result = OCRResult(
            blocks: [
                OCRTextBlock(text: "Left1", confidence: 0.95, boundingBox: CGRect(x: 0.05, y: 0.85, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Left2", confidence: 0.95, boundingBox: CGRect(x: 0.05, y: 0.75, width: 0.10, height: 0.04)),
                OCRTextBlock(text: "Right1", confidence: 0.95, boundingBox: CGRect(x: 0.60, y: 0.85, width: 0.12, height: 0.04)),
                OCRTextBlock(text: "Right2", confidence: 0.95, boundingBox: CGRect(x: 0.60, y: 0.75, width: 0.12, height: 0.04))
            ],
            captureDate: Date(),
            sourceRect: .zero
        )

        let output = result.monospaceAlignedText(columns: 120, multicolumnSorting: false)
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

        // Sıralama kapalıyken aynı y'deki bloklar aynı satırda birleşir
        XCTAssertTrue(lines[0].contains("Left1"))
        XCTAssertTrue(lines[0].contains("Right1"))
        XCTAssertTrue(lines[1].contains("Left2"))
        XCTAssertTrue(lines[1].contains("Right2"))
    }
}
