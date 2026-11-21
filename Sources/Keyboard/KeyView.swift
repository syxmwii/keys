import UIKit

/// Одна клавиша. Сама обрабатывает нажатие, удержание, повтор и свайпы,
/// поэтому не конфликтует с распознавателями жестов клавиатуры.
final class KeyView: UIControl {
    enum Swipe {
        case left
        case right
        case up
        case down
    }

    var onTap: ((KeySpec) -> Void)?
    var onLongPress: ((KeySpec, KeyView) -> Void)?
    var onSwipe: ((KeySpec, Swipe) -> Void)?
    var onRepeat: ((KeySpec) -> Void)?
    var onPressStart: ((KeySpec, KeyView) -> Void)?
    var onPressEnd: ((KeySpec) -> Void)?

    private(set) var spec: KeySpec
    private var theme: ThemeColors = ThemePreset.midnight.colors
    private var settings = KeysSettings()

    private let titleLabel = UILabel()
    private let iconView = UIImageView()

    private var longPressTimer: Timer?
    private var repeatTimer: Timer?
    private var longPressFired = false
    private var touchTracking = false
    private var didSwipe = false
    private var swipeConsumed = false
    private var verticalConsumed = false
    private var startPoint: CGPoint = .zero

    // MARK: - Инициализация

    init(spec: KeySpec) {
        self.spec = spec
        super.init(frame: .zero)
        isAccessibilityElement = true
        accessibilityTraits = .button
        titleLabel.textAlignment = .center
        titleLabel.isUserInteractionEnabled = false
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.6
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        addSubview(titleLabel)
        addSubview(iconView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            cancelTimers()
        }
    }

    // MARK: - Конфигурация

    func configure(spec: KeySpec, theme: ThemeColors, settings: KeysSettings) {
        self.spec = spec
        self.theme = theme
        self.settings = settings

        layer.cornerRadius = CGFloat(settings.cornerRadius)
        layer.cornerCurve = .continuous
        layer.masksToBounds = false
        layer.borderWidth = settings.showBorders ? (1 / UIScreen.main.scale) * 2 : 0
        layer.borderColor = theme.uiBorder.cgColor

        if settings.showShadow && themeBackgroundFor(style: spec.style).keysLuminance > 0.2 {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.22
            layer.shadowRadius = 0
            layer.shadowOffset = CGSize(width: 0, height: 1)
        } else {
            layer.shadowOpacity = 0
        }

        titleLabel.font = font(for: spec)
        titleLabel.text = spec.symbol == nil ? spec.label : nil
        titleLabel.textColor = textColor()
        titleLabel.isHidden = spec.symbol != nil

        if let symbol = spec.symbol {
            let config = UIImage.SymbolConfiguration(pointSize: symbolPointSize(), weight: .medium)
            iconView.image = UIImage(systemName: symbol, withConfiguration: config)
            iconView.tintColor = textColor()
            iconView.isHidden = false
        } else {
            iconView.image = nil
            iconView.isHidden = true
        }

        accessibilityLabel = spec.symbol != nil ? (spec.keyID) : spec.label
        backgroundColor = themeBackgroundFor(style: spec.style)
        setPressed(false)
        setNeedsLayout()
    }

    private func themeBackgroundFor(style: KeySpec.Style) -> UIColor {
        switch style {
        case .normal: return theme.uiKey
        case .modifier: return theme.uiModifier
        case .accent: return theme.uiAccent
        }
    }

    private func textColor() -> UIColor {
        spec.style == .accent ? theme.uiAccent.keysContrastingText : theme.uiText
    }

    private func font(for spec: KeySpec) -> UIFont {
        let base = CGFloat(settings.fontSize)
        switch spec.style {
        case .normal:
            return UIFont.systemFont(ofSize: base, weight: .regular)
        case .modifier:
            return UIFont.systemFont(ofSize: max(base * 0.72, 11), weight: .medium)
        case .accent:
            return UIFont.systemFont(ofSize: max(base * 0.78, 12), weight: .semibold)
        }
    }

    private func symbolPointSize() -> CGFloat {
        switch spec.style {
        case .normal: return CGFloat(settings.fontSize)
        case .modifier: return CGFloat(settings.fontSize) * 0.9
        case .accent: return CGFloat(settings.fontSize) * 0.85
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset: CGFloat = 2
        titleLabel.frame = bounds.insetBy(dx: inset, dy: inset)
        let side = min(bounds.height, bounds.width) * 0.52
        iconView.frame = CGRect(
            x: (bounds.width - side) / 2,
            y: (bounds.height - side) / 2,
            width: side,
            height: side
        )
    }

    // MARK: - Состояние

    private func setPressed(_ pressed: Bool) {
        backgroundColor = pressed
            ? themeBackgroundFor(style: spec.style).keysBlended(with: theme.uiKeyPressed, amount: 0.55)
            : themeBackgroundFor(style: spec.style)
        alpha = pressed ? 0.95 : 1
    }

    private func animateDown() {
        guard settings.bounce else { return }
        UIView.animate(withDuration: 0.06, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        }
    }

    private func animateUp() {
        guard settings.bounce else { return }
        UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.transform = .identity
        }
    }

    // MARK: - Касания

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        touchTracking = true
        didSwipe = false
        swipeConsumed = false
        verticalConsumed = false
        longPressFired = false
        startPoint = touch.location(in: self)
        setPressed(true)
        animateDown()
        KeyFeedback.press(haptics: settings.haptics, sound: settings.sound)
        onPressStart?(spec, self)
        startLongPressTimer()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard touchTracking, let touch = touches.first else { return }
        let point = touch.location(in: self)
        let dx = point.x - startPoint.x
        let dy = point.y - startPoint.y

        // Горизонтальный свайп: у пробела повторяется по мере движения пальца,
        // у остальных клавиш срабатывает один раз.
        if abs(dx) > 18, abs(dx) > abs(dy) {
            longPressTimer?.invalidate()
            didSwipe = true
            if spec.action == .space {
                onSwipe?(spec, dx < 0 ? .left : .right)
                startPoint = point
            } else if !swipeConsumed {
                swipeConsumed = true
                onSwipe?(spec, dx < 0 ? .left : .right)
                startPoint = point
            }
            return
        }

        // Вертикальный свайп — один раз на касание.
        if abs(dy) > 26, abs(dy) > abs(dx) {
            longPressTimer?.invalidate()
            didSwipe = true
            if !verticalConsumed {
                verticalConsumed = true
                onSwipe?(spec, dy < 0 ? .up : .down)
            }
            return
        }

        if !didSwipe, !bounds.insetBy(dx: -24, dy: -24).contains(point) {
            // Палец ушёл далеко от клавиши — отменяем нажатие, как в системной клавиатуре.
            touchTracking = false
            cancelTimers()
            setPressed(false)
            animateUp()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard touchTracking else {
            setPressed(false)
            animateUp()
            return
        }
        touchTracking = false
        cancelTimers()
        setPressed(false)
        animateUp()
        onPressEnd?(spec)
        if !didSwipe && !longPressFired {
            onTap?(spec)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        touchTracking = false
        cancelTimers()
        setPressed(false)
        animateUp()
        onPressEnd?(spec)
    }

    // MARK: - Таймеры

    private func startLongPressTimer() {
        longPressTimer?.invalidate()
        let timer = Timer(timeInterval: 0.42, repeats: false) { [weak self] _ in
            guard let self, self.touchTracking else { return }
            self.longPressFired = true
            KeyFeedback.longPress(haptics: self.settings.haptics)
            self.onLongPress?(self.spec, self)
            if self.settings.deleteRepeat, self.spec.action == .backspace {
                self.startRepeat()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        longPressTimer = timer
    }

    private func startRepeat() {
        repeatTimer?.invalidate()
        let timer = Timer(timeInterval: 0.085, repeats: true) { [weak self] _ in
            guard let self, self.touchTracking else { return }
            self.onRepeat?(self.spec)
        }
        RunLoop.main.add(timer, forMode: .common)
        repeatTimer = timer
    }

    private func cancelTimers() {
        longPressTimer?.invalidate()
        longPressTimer = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}