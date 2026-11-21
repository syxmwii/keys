import XCTest
@testable import Keys

final class TextInputRulesTests: XCTestCase {
    func testDoubleSpaceRequiresTextBeforeSpace() {
        XCTAssertTrue(TextInputRules.canReplaceSpace(in: "Привет "))
        XCTAssertFalse(TextInputRules.canReplaceSpace(in: nil))
        XCTAssertFalse(TextInputRules.canReplaceSpace(in: "Привет"))
        XCTAssertFalse(TextInputRules.canReplaceSpace(in: "Привет  "))
        XCTAssertFalse(TextInputRules.canReplaceSpace(in: "Привет! "))
        XCTAssertFalse(TextInputRules.canReplaceSpace(in: " "))
    }

    func testSentenceCapitalizationAfterNewlineOrPunctuation() {
        XCTAssertTrue(TextInputRules.shouldCapitalize(before: "Привет\n ", mode: .sentences))
        XCTAssertTrue(TextInputRules.shouldCapitalize(before: "Привет! ", mode: .sentences))
        XCTAssertFalse(TextInputRules.shouldCapitalize(before: "Привет ", mode: .sentences))
    }

    func testCapitalizationUsesFieldMode() {
        XCTAssertTrue(TextInputRules.shouldCapitalize(before: "hello ", mode: .words))
        XCTAssertFalse(TextInputRules.shouldCapitalize(before: "hello", mode: .words))
        XCTAssertFalse(TextInputRules.shouldCapitalize(before: nil, mode: .none))
        XCTAssertTrue(TextInputRules.shouldCapitalize(before: "hello", mode: .allCharacters))
    }
}
