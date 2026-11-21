import AudioToolbox
import UIKit

// MARK: - Тактильный отклик и звук

public enum KeyFeedback {
    private static let impact = UIImpactFeedbackGenerator(style: .light)
    private static let selection = UISelectionFeedbackGenerator()

    public static func prepare() {
        impact.prepare()
    }

    /// Отклик на нажатие: вибрация + системный клик.
    public static func press(haptics: Bool, sound: Bool) {
        if haptics {
            impact.impactOccurred(intensity: 0.7)
            impact.prepare()
        }
        if sound {
            UIDevice.current.playInputClick()
        }
    }

    public static func longPress(haptics: Bool) {
        guard haptics else { return }
        selection.selectionChanged()
    }

    public static func error() {
        AudioServicesPlaySystemSound(1053)
    }
}

// MARK: - Цветовые утилиты

public extension UIColor {
    /// Относительная яркость по Rec. 709.
    var keysLuminance: CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return 1 }
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    /// Читаемый цвет текста поверх этого фона.
    var keysContrastingText: UIColor {
        keysLuminance > 0.5 ? UIColor.black : UIColor.white
    }

    func keysBlended(with other: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        guard getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        else { return self }
        let t = min(max(amount, 0), 1)
        return UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }
}

// MARK: - Подпись клавиши возврата

public enum ReturnKeyTitle {
    public static func title(for type: UIReturnKeyType) -> String {
        switch type {
        case .go: return "Go"
        case .google: return "Google"
        case .join: return "Join"
        case .next: return "Next"
        case .route: return "Route"
        case .search: return "Search"
        case .send: return "Send"
        case .yahoo: return "Yahoo"
        case .done: return "Done"
        case .emergencyCall: return "Call"
        case .continue: return "Cont."
        case .default: return "return"
        @unknown default: return "return"
        }
    }
}