import Foundation
import SwiftUI

// MARK: - Раскладки

public enum KeyboardLayoutID: String, Codable, CaseIterable, Identifiable, Hashable {
    case english
    case russian

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .english: return "English"
        case .russian: return "Русский"
        }
    }

    /// Подпись на клавише переключения раскладки.
    public var badge: String {
        switch self {
        case .english: return "EN"
        case .russian: return "РУ"
        }
    }

    /// Подпись пробела.
    public var spaceTitle: String {
        switch self {
        case .english: return "space"
        case .russian: return "пробел"
        }
    }

    public var letters: [[String]] {
        switch self {
        case .english:
            return [
                ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                ["z", "x", "c", "v", "b", "n", "m"]
            ]
        case .russian:
            return [
                ["й", "ц", "у", "к", "е", "н", "г", "ш", "щ", "з", "х"],
                ["ф", "ы", "в", "а", "п", "р", "о", "л", "д", "ж", "э"],
                ["я", "ч", "с", "м", "и", "т", "ь", "б", "ю"]
            ]
        }
    }

    /// Варианты символов на долгое нажатие.
    public var alternates: [String: [String]] {
        switch self {
        case .english:
            return [
                "a": ["á", "à", "â", "ä", "å", "ã"],
                "e": ["é", "è", "ê", "ë", "ę"],
                "i": ["í", "ì", "î", "ï"],
                "o": ["ó", "ò", "ô", "ö", "õ", "ø"],
                "u": ["ú", "ù", "û", "ü"],
                "c": ["ç", "ć"],
                "n": ["ñ", "ń"],
                "s": ["ß", "ś", "š"],
                "y": ["ý", "ÿ"],
                "z": ["ž", "ź", "ż"],
                "l": ["ł"]
            ]
        case .russian:
            return ["е": ["ё"], "ь": ["ъ"]]
        }
    }
}

// MARK: - Клавиши

/// Плоскость клавиатуры: буквы / цифры / символы.
public enum KeyPlane: String, Codable, CaseIterable, Hashable {
    case letters
    case numbers
    case symbols
}

/// Что делает клавиша.
public enum KeyAction: Equatable, Hashable {
    case character(String)
    case shift
    case backspace
    case space
    case newline
    case globe
    case emoji
    case plane(KeyPlane)
    case layout
    case dismiss
    case none
}

public struct KeySpec: Equatable, Hashable {
    public enum Style: Equatable, Hashable {
        case normal
        case modifier
        case accent
    }

    public var label: String
    public var action: KeyAction
    /// Вес ширины клавиши (1.0 — обычная буква).
    public var width: CGFloat
    public var style: Style
    /// SF Symbol вместо текста.
    public var symbol: String?
    /// Символы на долгое нажатие.
    public var alternates: [String]
    /// Стабильный идентификатор для переиспользования вью.
    public var keyID: String

    var isLetter: Bool {
        guard case .character(let value) = action, value.count == 1 else { return false }
        return value.first?.isLetter == true
    }

    public init(
        label: String,
        action: KeyAction,
        width: CGFloat = 1,
        style: Style = .normal,
        symbol: String? = nil,
        alternates: [String] = [],
        keyID: String? = nil
    ) {
        self.label = label
        self.action = action
        self.width = width
        self.style = style
        self.symbol = symbol
        self.alternates = alternates
        self.keyID = keyID ?? "\(action)-\(label)"
    }
}

// MARK: - Движок раскладки

public enum KeyboardRows {
    public static let sidePadding: CGFloat = 3
    public static let verticalGap: CGFloat = 6
    public static let topPadding: CGFloat = 6
    public static let bottomPadding: CGFloat = 4

    /// Собирает строки клавиш под текущее состояние.
    public static func rows(
        layout: KeyboardLayoutID,
        plane: KeyPlane,
        shift: Bool,
        caps: Bool,
        settings: KeysSettings,
        enabledLayouts: [KeyboardLayoutID],
        showGlobe: Bool,
        returnKey: String
    ) -> [[KeySpec]] {
        var result: [[KeySpec]] = []

        if settings.numberRow && plane == .letters {
            result.append(numberRow())
        }

        switch plane {
        case .letters:
            let source = layout.letters
            for (rowIndex, letters) in source.enumerated() {
                var row: [KeySpec] = []
                let isLastRow = rowIndex == source.count - 1

                if isLastRow {
                    row.append(
                        KeySpec(
                            label: "",
                            action: .shift,
                            width: layout == .russian ? 1 : 1.55,
                            style: .modifier,
                            symbol: shiftSymbol(shift: shift, caps: caps),
                            keyID: "shift"
                        )
                    )
                }

                for letter in letters {
                    let shown = (shift || caps) ? letter.uppercased() : letter
                    row.append(
                        KeySpec(
                            label: shown,
                            action: .character(letter),
                            width: 1,
                            style: .normal,
                            alternates: layout.alternates[letter] ?? [],
                            keyID: "char-\(letter)"
                        )
                    )
                }

                if isLastRow {
                    row.append(
                        KeySpec(
                            label: "",
                            action: .backspace,
                            width: layout == .russian ? 1 : 1.55,
                            style: .modifier,
                            symbol: "delete.left",
                            keyID: "backspace"
                        )
                    )
                }

                result.append(row)
            }

            result.append(
                bottomRow(
                    layout: layout,
                    settings: settings,
                    enabledLayouts: enabledLayouts,
                    showGlobe: showGlobe,
                    returnKey: returnKey
                )
            )

        case .numbers:
            result.append(contentsOf: numberPlaneRows(settings: settings))
            result.append(
                planeBottomRow(
                    layout: layout,
                    planeKey: KeySpec(label: "#+=", action: .plane(.symbols), width: 1.55, style: .modifier, keyID: "plane-symbols"),
                    settings: settings,
                    enabledLayouts: enabledLayouts,
                    showGlobe: showGlobe,
                    returnKey: returnKey
                )
            )

        case .symbols:
            result.append(contentsOf: symbolPlaneRows())
            result.append(
                planeBottomRow(
                    layout: layout,
                    planeKey: KeySpec(label: "123", action: .plane(.numbers), width: 1.55, style: .modifier, keyID: "plane-numbers"),
                    settings: settings,
                    enabledLayouts: enabledLayouts,
                    showGlobe: showGlobe,
                    returnKey: returnKey
                )
            )
        }

        return result
    }

    // MARK: - Строки

    private static func numberRow() -> [KeySpec] {
        "1234567890".map { digit in
            KeySpec(label: String(digit), action: .character(String(digit)), width: 1, style: .normal, keyID: "num-\(digit)")
        }
    }

    private static func numberPlaneRows(settings: KeysSettings) -> [[KeySpec]] {
        let first = "1234567890".map { KeySpec(label: String($0), action: .character(String($0)), keyID: "n-\($0)") }
        let second = ["-", "/", ":", ";", "(", ")", "₽", "&", "@", "\""].map {
            KeySpec(label: $0, action: .character($0), keyID: "s-\($0)")
        }
        let third: [KeySpec] = [
            KeySpec(label: ".", action: .character("."), keyID: "d-dot"),
            KeySpec(label: ",", action: .character(","), keyID: "d-comma"),
            KeySpec(label: "?", action: .character("?"), keyID: "d-question"),
            KeySpec(label: "!", action: .character("!"), keyID: "d-bang"),
            KeySpec(label: "'", action: .character("'"), keyID: "d-quote")
        ]
        _ = settings
        return [first, second, third]
    }

    private static func symbolPlaneRows() -> [[KeySpec]] {
        let first = ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="].map {
            KeySpec(label: $0, action: .character($0), keyID: "y-\($0)")
        }
        let second = ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"].map {
            KeySpec(label: $0, action: .character($0), keyID: "z-\($0)")
        }
        let third = [".", ",", "?", "!", "`"].map {
            KeySpec(label: $0, action: .character($0), keyID: "w-\($0)")
        }
        return [first, second, third]
    }

    private static func bottomRow(
        layout: KeyboardLayoutID,
        settings: KeysSettings,
        enabledLayouts: [KeyboardLayoutID],
        showGlobe: Bool,
        returnKey: String
    ) -> [KeySpec] {
        var row: [KeySpec] = [
            KeySpec(label: "123", action: .plane(.numbers), width: 1.5, style: .modifier, keyID: "plane-numbers")
        ]

        if showGlobe {
            row.append(KeySpec(label: "", action: .globe, width: 1.2, style: .modifier, symbol: "globe", keyID: "globe"))
        }
        if settings.showEmojiKey {
            row.append(KeySpec(label: "", action: .emoji, width: 1.2, style: .modifier, symbol: "face.smiling", keyID: "emoji"))
        }
        if enabledLayouts.count > 1 {
            row.append(KeySpec(label: layout.badge, action: .layout, width: 1.25, style: .modifier, keyID: "layout"))
        }

        row.append(KeySpec(label: layout.spaceTitle, action: .space, width: 4.2, style: .normal, keyID: "space"))
        row.append(KeySpec(label: returnKey, action: .newline, width: 1.9, style: .accent, keyID: "return"))

        if settings.showDismissKey {
            row.append(KeySpec(label: "", action: .dismiss, width: 1.1, style: .modifier, symbol: "keyboard.chevron.compact.down", keyID: "dismiss"))
        }

        return row
    }

    private static func planeBottomRow(
        layout: KeyboardLayoutID,
        planeKey: KeySpec,
        settings: KeysSettings,
        enabledLayouts: [KeyboardLayoutID],
        showGlobe: Bool,
        returnKey: String
    ) -> [KeySpec] {
        var row: [KeySpec] = [
            KeySpec(label: layout == .russian ? "АБВ" : "ABC", action: .plane(.letters), width: 1.6, style: .modifier, keyID: "plane-letters"),
            planeKey
        ]
        if showGlobe {
            row.append(KeySpec(label: "", action: .globe, width: 1.1, style: .modifier, symbol: "globe", keyID: "globe"))
        }
        if enabledLayouts.count > 1 {
            row.append(KeySpec(label: layout.badge, action: .layout, width: 1.1, style: .modifier, keyID: "layout"))
        }
        row.append(KeySpec(label: layout.spaceTitle, action: .space, width: 3.4, style: .normal, keyID: "space"))
        row.append(KeySpec(label: returnKey, action: .newline, width: 1.9, style: .accent, keyID: "return"))
        return row
    }

    private static func shiftSymbol(shift: Bool, caps: Bool) -> String {
        if caps { return "capslock.fill" }
        return shift ? "shift.fill" : "shift"
    }

    /// Высота клавиатуры в точках для текущих настроек.
    public static func contentHeight(rowCount: Int, settings: KeysSettings) -> CGFloat {
        let rows = CGFloat(max(rowCount, 1))
        return topPadding
            + rows * CGFloat(settings.keyHeight)
            + CGFloat(max(rowCount - 1, 0)) * verticalGap
            + bottomPadding
    }
}