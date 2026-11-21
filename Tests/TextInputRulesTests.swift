import XCTest
@testable import Keys

final class TextInputRulesTests: XCTestCase {
    func testShiftAndCapsLockTiming() {
        var gesture = ShiftGesture()
        XCTAssertFalse(gesture.tap(at: 1, shifted: true, locked: false).shift)
        XCTAssertTrue(gesture.tap(at: 1.25, shifted: false, locked: false).caps)
        XCTAssertFalse(gesture.tap(at: 2, shifted: false, locked: true).caps)
        XCTAssertTrue(gesture.tap(at: 3, shifted: false, locked: false).shift)
        XCTAssertFalse(gesture.tap(at: 4, shifted: true, locked: false).caps)
    }

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
