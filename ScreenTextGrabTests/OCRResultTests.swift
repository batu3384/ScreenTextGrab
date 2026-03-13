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
}
