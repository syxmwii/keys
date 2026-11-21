import XCTest
@testable import Keys

final class InputEngineTests: XCTestCase {
    func testDoubleSpaceRequiresRecentPress() {
        var engine = InputEngine()
        XCTAssertEqual(engine.space(before: "hello", at: 1, enabled: true), .insertSpace)
        XCTAssertEqual(engine.space(before: "hello ", at: 1.25, enabled: true), .replaceWithPeriod)
        XCTAssertEqual(engine.space(before: "hello ", at: 2, enabled: true), .insertSpace)
    }

    func testResetDiscardsPreviousPress() {
        var engine = InputEngine()
        _ = engine.space(before: "hello", at: 1, enabled: true)
        engine.reset()
        XCTAssertEqual(engine.space(before: "hello ", at: 1.25, enabled: true), .insertSpace)
    }

    func testWordDeletionSkipsTrailingWhitespace() {
        XCTAssertEqual(InputEngine.wordDeletionCount(before: "hello мир  "), 5)
        XCTAssertEqual(InputEngine.wordDeletionCount(before: nil), 0)
        XCTAssertEqual(InputEngine.wordDeletionCount(before: String(repeating: "а", count: 40)), 32)
    }
}
