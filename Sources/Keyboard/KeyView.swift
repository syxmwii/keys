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
    private var settings = KeysSettings()

    private let face = KeycapFace()

    private var longPressTimer: Timer?
    private var repeatTimer: Timer?
    private var longPressFired = false
    private var touchTracking = false
    private var didSwipe = false
    private var swipeConsumed = false
    private var startPoint: CGPoint = .zero

    // MARK: - Инициализация

    init(spec: KeySpec) {
        self.spec = spec
        super.init(frame: .zero)
        isAccessibilityElement = true
        accessibilityTraits = .button
        addSubview(face)
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
        self.settings = settings
        face.configure(spec, settings: settings, theme: theme)
        accessibilityLabel = spec.symbol != nil ? spec.keyID : spec.label
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        face.frame = bounds
    }

    private func setPressed(_ pressed: Bool) {
        face.setPressed(pressed)
    }

    private func animateDown() {
        guard settings.bounce, !UIAccessibility.isReduceMotionEnabled else {
            face.transform = .identity
            return
        }
        UIView.animate(withDuration: 0.06, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.face.transform = self.settings.usesPlainLetters(for: self.spec) ? .identity : self.settings.design.pressedTransform
        }
    }

    private func animateUp() {
        guard settings.bounce, !UIAccessibility.isReduceMotionEnabled else {
            face.transform = .identity
            return
        }
        UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.face.transform = .identity
        }
    }

    // MARK: - Касания

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        touchTracking = true
        didSwipe = false
        swipeConsumed = false
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
        let handlesSwipe = (spec.action == .space && settings.spaceCursor)
            || (spec.action == .backspace && settings.swipeBackspace && dx < 0)
            || spec.action == .layout
        if handlesSwipe, abs(dx) > 18, abs(dx) > abs(dy) {
            cancelTimers()
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

        if !didSwipe, !bounds.insetBy(dx: -24, dy: -24).contains(point) {
            // Палец ушёл далеко от клавиши — отменяем нажатие, как в системной клавиатуре.
            touchTracking = false
            cancelTimers()
            setPressed(false)
            animateUp()
            onPressEnd?(spec)
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
        let repeatsDeletion = settings.deleteRepeat && spec.action == .backspace
        guard repeatsDeletion || !spec.alternates.isEmpty else { return }
        let timer = Timer(timeInterval: 0.42, repeats: false) { [weak self] _ in
            guard let self, self.touchTracking else { return }
            self.longPressFired = true
            KeyFeedback.longPress(haptics: self.settings.haptics)
            self.onLongPress?(self.spec, self)
            if repeatsDeletion {
                self.startRepeat()
                self.onRepeat?(self.spec)
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