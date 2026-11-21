import UIKit

public enum KeycapDesign: String, Codable, CaseIterable {
    case orbit, mechanical, classic

    var title: String {
        switch self {
        case .orbit: return "Орбита"
        case .mechanical: return "Механика"
        case .classic: return "Классика"
        }
    }

    var pressedTransform: CGAffineTransform {
        switch self {
        case .orbit: return CGAffineTransform(scaleX: 0.92, y: 0.96)
        case .mechanical: return CGAffineTransform(translationX: 0, y: 2)
        case .classic: return CGAffineTransform(scaleX: 0.94, y: 0.94)
        }
    }
}

/// Одна и та же поверхность в системной клавиатуре и в предпросмотре.
final class KeycapFace: UIView {
    private let label = UILabel()
    private let icon = UIImageView()
    private let surface = UIView()
    private var design = KeycapDesign.classic
    private var radius: CGFloat = 8
    private var depth: CGFloat = 0
    private var fill = UIColor.clear
    private var highlight = UIColor.clear
    private var pressed = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        surface.layer.cornerCurve = .continuous
        layer.cornerCurve = .continuous
        addSubview(surface)
        surface.addSubview(label)
        surface.addSubview(icon)
        icon.contentMode = .scaleAspectFit
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
    }

    required init?(coder: NSCoder) { return nil }

    func configure(_ key: KeySpec, settings: KeysSettings, theme: ThemeColors) {
        design = settings.design
        let accent = key.style == .accent
        let modifier = key.style == .modifier
        let base = CGFloat(settings.cornerRadius)
        switch design {
        case .classic: radius = base
        case .orbit: radius = modifier || accent || key.action == .space ? 100 : base + 6
        case .mechanical: radius = max(2, base * 0.55)
        }
        depth = design == .mechanical ? 3 : 0
        fill = accent ? theme.uiAccent : (modifier ? theme.uiModifier : theme.uiKey)
        if design == .orbit && modifier {
            fill = fill.keysBlended(with: theme.uiAccent, amount: 0.18)
        }
        highlight = fill.keysBlended(with: theme.uiKeyPressed, amount: 0.65)
        backgroundColor = depth > 0 ? fill.keysBlended(with: .black, amount: 0.42) : .clear
        let ink = accent ? fill.keysContrastingText : theme.uiText
        let size = CGFloat(settings.fontSize) * (accent ? 0.82 : (modifier ? 0.76 : 1))
        let font = UIFont.systemFont(ofSize: size, weight: design == .classic && !modifier && !accent ? .regular : .medium)
        switch design {
        case .orbit:
            label.font = font.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? font
        case .mechanical: label.font = .monospacedSystemFont(ofSize: size, weight: .medium)
        case .classic: label.font = font
        }
        label.text = key.symbol == nil ? key.label : nil
        label.textColor = ink
        icon.image = key.symbol.flatMap { UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .medium)) }
        icon.tintColor = ink
        surface.layer.borderColor = theme.uiBorder.cgColor
        surface.layer.borderWidth = settings.showBorders ? 1 : 0
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        layer.shadowOpacity = settings.showShadow && design != .orbit ? 0.22 : 0
        setPressed(pressed)
        setNeedsLayout()
    }

    func setPressed(_ value: Bool) {
        pressed = value
        surface.backgroundColor = value ? highlight : fill
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        surface.frame = bounds.inset(by: UIEdgeInsets(top: 0, left: 0, bottom: depth, right: 0))
        let rounded = min(radius, min(surface.bounds.height, surface.bounds.width) / 2)
        surface.layer.cornerRadius = rounded
        layer.cornerRadius = rounded
        label.frame = surface.bounds.insetBy(dx: 2, dy: 1)
        let side = min(surface.bounds.width, surface.bounds.height) * 0.54
        icon.frame = CGRect(x: surface.bounds.midX - side / 2, y: surface.bounds.midY - side / 2,
                            width: side, height: side)
    }
}
