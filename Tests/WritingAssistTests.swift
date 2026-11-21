import XCTest
@testable import Keys

final class WritingAssistTests: XCTestCase {
    func testCorrectionPreservesInitialCapitalAndWordBoundary() {
        XCTAssertEqual(WritingAssist.correction(in: "Скажи Првиет"), "Привет")
        XCTAssertEqual(WritingAssist.correction(in: "teh"), "the")
        for context in ["", "hello", "TEH", "tEh", "@teh", "my_teh", "https://teh"] {
            XCTAssertNil(WritingAssist.correction(in: context), context)
        }
    }

    func testAcceptedSuggestionRespectsAdjacentText() {
        XCTAssertEqual(WritingAssist.suggestionText("Morning", before: "Hello!", after: nil), " Morning ")
        XCTAssertEqual(WritingAssist.suggestionText("tomorrow", before: "tom", after: ","), "tomorrow")
        XCTAssertEqual(WritingAssist.suggestionText("утро", before: "доброе ", after: " уже"), "утро")
    }

    func testContextLanguageUsesNearestAlphabet() {
        XCTAssertEqual(WritingAssist.nearbyLanguage(in: "hello, привет! "), "ru")
        XCTAssertEqual(WritingAssist.nearbyLanguage(in: "привет, hello! "), "en")
        XCTAssertNil(WritingAssist.nearbyLanguage(in: "123 🙂"))
        XCTAssertNil(WritingAssist.nearbyLanguage(in: "hello 世界"))
    }

    func testWordBoundaryAndNextWordSuggestions() {
        XCTAssertEqual(WritingAssist.word(before: "🙂 привет"), "привет")
        XCTAssertEqual(WritingAssist.word(before: "🙂 привет "), "")
        XCTAssertEqual(WritingAssist.nextWords(before: "Ну как ", russian: true).first, "дела")
        XCTAssertEqual(WritingAssist.nextWords(before: "Thank ", russian: false).first, "you")
    }
}
