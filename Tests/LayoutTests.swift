import UIKit
import XCTest
@testable import Keys

final class LayoutTests: XCTestCase {
    private var settings: KeysSettings { KeysSettings() }

    func testRussianLetterRows() {
        let rows = KeyboardRows.rows(
            layout: .russian,
            plane: .letters,
            shift: false,
            caps: false,
            settings: settings,
            enabledLayouts: [.english, .russian],
            showGlobe: true,
            returnKey: "return"
        )

        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows[0].count, 12)
        XCTAssertEqual(rows[1].count, 11)
        XCTAssertEqual(rows[2].count, 11) // 9 букв + shift + backspace
        XCTAssertEqual(rows[0].first?.label, "й")
    }

    func testShiftUppercasesLabels() {
        let rows = KeyboardRows.rows(
            layout: .english,
            plane: .letters,
            shift: true,
            caps: false,
            settings: settings,
            enabledLayouts: [.english],
            showGlobe: false,
            returnKey: "return"
        )
        XCTAssertEqual(rows[0].first?.label, "Q")
        XCTAssertEqual(rows[0].first?.action, .character("q"))
    }

    func testLayoutKeyOnlyWithSeveralLayouts() {
        let single = KeyboardRows.rows(
            layout: .english,
            plane: .letters,
            shift: false,
            caps: false,
            settings: settings,
            enabledLayouts: [.english],
            showGlobe: false,
            returnKey: "return"
        )
        XCTAssertFalse(single[3].contains { $0.action == .layout })

        let double = KeyboardRows.rows(
            layout: .english,
            plane: .letters,
            shift: false,
            caps: false,
            settings: settings,
            enabledLayouts: [.english, .russian],
            showGlobe: false,
            returnKey: "return"
        )
        XCTAssertTrue(double[3].contains { $0.action == .layout })
    }

    func testNumberRowAddsRow() {
        var settings = KeysSettings()
        settings.numberRow = true
        let rows = KeyboardRows.rows(
            layout: .english,
            plane: .letters,
            shift: false,
            caps: false,
            settings: settings,
            enabledLayouts: [.english],
            showGlobe: false,
            returnKey: "return"
        )
        XCTAssertEqual(rows.count, 5)
        XCTAssertEqual(rows[0].count, 10)
        XCTAssertEqual(rows[0].first?.action, .character("1"))
    }

    func testSymbolPlaneHasBackspaceEquivalentRows() {
        let rows = KeyboardRows.rows(
            layout: .english,
            plane: .numbers,
            shift: false,
            caps: false,
            settings: settings,
            enabledLayouts: [.english],
            showGlobe: false,
            returnKey: "return"
        )
        XCTAssertEqual(rows.count, 4)
        XCTAssertTrue(rows[3].contains { $0.action == .space })
        XCTAssertTrue(rows[3].contains { $0.action == .plane(.letters) })
    }

    func testContentHeightGrowsWithRows() {
        let three = KeyboardRows.contentHeight(rowCount: 3, settings: settings)
        let four = KeyboardRows.contentHeight(rowCount: 4, settings: settings)
        XCTAssertGreaterThan(four, three)
    }

    func testHexParsing() {
        let color = UIColor(hex: "#FF6B57")
        XCTAssertNotNil(color)
        XCTAssertEqual(color?.keysLuminance ?? 0, 0.537, accuracy: 0.02)
        XCTAssertNil(UIColor(hex: "nope"))
    }

    func testTolerantDecoding() {
        let json = Data(#"{"theme":"nord"}"#.utf8)
        let decoded = try? JSONDecoder().decode(KeysSettings.self, from: json)
        XCTAssertEqual(decoded?.theme, .nord)
        XCTAssertEqual(decoded?.keyHeight, KeysSettings().keyHeight)
    }

    func testDesignMigrationAndRoundTrip() throws {
        XCTAssertEqual(KeysSettings().design, .orbit)
        let legacy = try JSONDecoder().decode(KeysSettings.self, from: Data(#"{"theme":"nord"}"#.utf8))
        XCTAssertEqual(legacy.design, .classic)
        XCTAssertEqual(legacy.theme, .nord)
        for design in KeycapDesign.allCases {
            var updated = legacy
            updated.design = design
            let data = try JSONEncoder().encode(updated)
            XCTAssertEqual(try JSONDecoder().decode(KeysSettings.self, from: data), updated)
        }
    }

    func testCustomThemeColors() {
        var settings = KeysSettings()
        settings.theme = .custom
        settings.custom.accent = "#123456"
        XCTAssertEqual(settings.colors.accent, "#123456")
    }
}