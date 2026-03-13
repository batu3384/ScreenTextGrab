import XCTest
@testable import ScreenTextGrab

final class SmartActionBuilderTests: XCTestCase {
    func testURLProducesOpenAction() {
        let actions = SmartActionBuilder.actions(for: "https://openai.com")

        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions.first?.title, "Bağlantıyı Aç")
        XCTAssertEqual(actions.first?.url?.absoluteString, "https://openai.com")
    }

    func testEmailProducesComposeAction() {
        let actions = SmartActionBuilder.actions(for: "hello@example.com")

        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions.first?.title, "Mail Yaz")
        XCTAssertEqual(actions.first?.url?.absoluteString, "mailto:hello@example.com")
    }

    func testPlainShortTextProducesSearchAction() {
        let actions = SmartActionBuilder.actions(for: "swift vision ocr")

        XCTAssertEqual(actions.count, 2)
        XCTAssertEqual(actions.first?.title, "Türkçeye Çevir")
        XCTAssertEqual(actions.last?.title, "Web'de Ara")
        XCTAssertTrue(actions.last?.url?.absoluteString.contains("google.com/search") == true)
    }

    func testTurkishTextPrefersEnglishTranslation() {
        let actions = SmartActionBuilder.actions(for: "ekrandaki metni kopyala")

        XCTAssertEqual(actions.first?.title, "İngilizceye Çevir")
        XCTAssertTrue(actions.first?.url?.absoluteString.contains("tl=en") == true)
    }

    func testCodeLikeTextDoesNotProduceTranslation() {
        let actions = SmartActionBuilder.actions(for: "func copyText() {\n    print(\"ok\")\n}")

        XCTAssertTrue(actions.isEmpty)
    }

    func testReadAloudEligibilityMatchesContent() {
        XCTAssertTrue(SmartActionBuilder.shouldOfferReadAloud(for: "Merhaba dunya"))
        XCTAssertFalse(SmartActionBuilder.shouldOfferReadAloud(for: "https://openai.com"))
        XCTAssertFalse(SmartActionBuilder.shouldOfferReadAloud(for: "let value = items.first"))
    }

    func testCodeEntrySuggestsMarkdownCopyPreset() {
        let entry = ClipboardHistoryEntry(
            text: "if (value) {\n    print(value)\n}",
            date: Date(),
            captureMode: .code,
            outputPreset: .smart,
            contentKind: .text,
            rawText: "if (value) {\n    print(value)\n}"
        )

        let actions = SmartActionBuilder.actions(for: entry)

        XCTAssertEqual(actions.first?.title, "Markdown Kod")
        XCTAssertEqual(actions.first?.kind, .copyAsPreset(.markdown))
    }

    func testStructuredOutputSuppressesTranslationAndSearch() {
        let entry = ClipboardHistoryEntry(
            text: "```text\nswift vision ocr\n```",
            date: Date(),
            captureMode: .code,
            outputPreset: .markdown,
            contentKind: .text,
            rawText: "swift vision ocr"
        )

        let actions = SmartActionBuilder.actions(for: entry)

        XCTAssertFalse(actions.contains { $0.title == "Türkçeye Çevir" || $0.title == "Web'de Ara" })
        XCTAssertTrue(actions.contains { $0.title == "Ham Çıktı" })
    }
}
