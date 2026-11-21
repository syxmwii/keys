import SwiftUI
import UIKit

// MARK: - Цвета темы

/// Палитра одной темы. Цвета хранятся строками `#RRGGBB`, чтобы настройки
/// одинаково хорошо переживали JSON, UserDefaults и App Group.
public struct ThemeColors: Codable, Equatable, Hashable {
    public var background: String
    public var key: String
    public var keyPressed: String
    public var modifier: String
    public var text: String
    public var accent: String
    public var border: String

    public init(
        background: String,
        key: String,
        keyPressed: String,
        modifier: String,
        text: String,
        accent: String,
        border: String
    ) {
        self.background = background
        self.key = key
        self.keyPressed = keyPressed
        self.modifier = modifier
        self.text = text
        self.accent = accent
        self.border = border
    }

    // UIKit (клавиатура)
    public var uiBackground: UIColor { UIColor(hex: background) ?? .black }
    public var uiKey: UIColor { UIColor(hex: key) ?? .darkGray }
    public var uiKeyPressed: UIColor { UIColor(hex: keyPressed) ?? .gray }
    public var uiModifier: UIColor { UIColor(hex: modifier) ?? .darkGray }
    public var uiText: UIColor { UIColor(hex: text) ?? .white }
    public var uiAccent: UIColor { UIColor(hex: accent) ?? .systemBlue }
    public var uiBorder: UIColor { UIColor(hex: border) ?? .clear }

    // SwiftUI (приложение)
    public var swiftBackground: Color { Color(hex: background) }
    public var swiftKey: Color { Color(hex: key) }
    public var swiftKeyPressed: Color { Color(hex: keyPressed) }
    public var swiftModifier: Color { Color(hex: modifier) }
    public var swiftText: Color { Color(hex: text) }
    public var swiftAccent: Color { Color(hex: accent) }
    public var swiftBorder: Color { Color(hex: border) }
}

// MARK: - Пресеты

public enum ThemePreset: String, Codable, CaseIterable, Identifiable, Hashable {
    case midnight
    case graphite
    case nord
    case latte
    case sakura
    case matrix
    case ocean
    case sunset
    case custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .midnight: return "Midnight"
        case .graphite: return "Graphite"
        case .nord: return "Nord"
        case .latte: return "Latte"
        case .sakura: return "Sakura"
        case .matrix: return "Matrix"
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .custom: return "Custom"
        }
    }

    /// Светлая тема — приложению нужно знать, какой цвет текста ставить в UI.
    public var isLight: Bool {
        self == .latte || self == .sakura
    }

    public var colors: ThemeColors {
        switch self {
        case .midnight:
            return ThemeColors(
                background: "#11141F",
                key: "#272C3E",
                keyPressed: "#3D4459",
                modifier: "#1B2030",
                text: "#F4F6FF",
                accent: "#FF6B57",
                border: "#343B52"
            )
        case .graphite:
            return ThemeColors(
                background: "#1C1C1E",
                key: "#3A3A3C",
                keyPressed: "#565659",
                modifier: "#2C2C2E",
                text: "#FFFFFF",
                accent: "#0A84FF",
                border: "#48484A"
            )
        case .nord:
            return ThemeColors(
                background: "#2E3440",
                key: "#434C5E",
                keyPressed: "#4C566A",
                modifier: "#3B4252",
                text: "#ECEFF4",
                accent: "#88C0D0",
                border: "#4C566A"
            )
        case .latte:
            return ThemeColors(
                background: "#EFE7DC",
                key: "#FFFFFF",
                keyPressed: "#DCD3C7",
                modifier: "#E3D9CC",
                text: "#3A322C",
                accent: "#C97B4A",
                border: "#D8CCBC"
            )
        case .sakura:
            return ThemeColors(
                background: "#FFF1F4",
                key: "#FFFFFF",
                keyPressed: "#FFD9E1",
                modifier: "#FFE6EC",
                text: "#4A2C35",
                accent: "#FF7A9C",
                border: "#F5D2DB"
            )
        case .matrix:
            return ThemeColors(
                background: "#060B08",
                key: "#12241A",
                keyPressed: "#1C3A28",
                modifier: "#0C1A12",
                text: "#7BFFA8",
                accent: "#22E06A",
                border: "#1D4230"
            )
        case .ocean:
            return ThemeColors(
                background: "#0B1B2B",
                key: "#16324A",
                keyPressed: "#1F4666",
                modifier: "#0F2637",
                text: "#E4F3FF",
                accent: "#38BDF8",
                border: "#244866"
            )
        case .sunset:
            return ThemeColors(
                background: "#1E1220",
                key: "#34203A",
                keyPressed: "#482A50",
                modifier: "#291830",
                text: "#FFEDF7",
                accent: "#FF9E64",
                border: "#43284B"
            )
        case .custom:
            return ThemeColors(
                background: "#141826",
                key: "#2B3247",
                keyPressed: "#3E4862",
                modifier: "#1E2438",
                text: "#EDF1FF",
                accent: "#FF6B57",
                border: "#39415A"
            )
        }
    }
}

// MARK: - Хекс

public extension UIColor {
    convenience init?(hex: String) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }
        if string.lowercased().hasPrefix("0x") { string.removeFirst(2) }
        guard string.count == 6 || string.count == 8, let value = UInt64(string, radix: 16) else {
            return nil
        }

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        if string.count == 6 {
            red = CGFloat((value & 0xFF0000) >> 16) / 255
            green = CGFloat((value & 0x00FF00) >> 8) / 255
            blue = CGFloat(value & 0x0000FF) / 255
            alpha = 1
        } else {
            red = CGFloat((value & 0xFF000000) >> 24) / 255
            green = CGFloat((value & 0x00FF0000) >> 16) / 255
            blue = CGFloat((value & 0x0000FF00) >> 8) / 255
            alpha = CGFloat(value & 0x000000FF) / 255
        }

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

public extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex) ?? .clear)
    }

    var hexString: String {
        let color = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#000000"
        }
        return String(
            format: "#%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
    }
}