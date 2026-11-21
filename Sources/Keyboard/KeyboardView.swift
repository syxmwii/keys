import UIKit

/// Полотно клавиатуры: держит строки клавиш и раскладывает их вручную,
/// чтобы не зависеть от автолейаута на 50+ вью.
final class KeyboardView: UIView {
    var onAction: ((KeyAction) -> Void)?
    var onLongPress: ((KeySpec, KeyView) -> Void)?
    var onSwipe: ((KeySpec, KeyView.Swipe) -> Void)?

    private var specs: [[KeySpec]] = []
    private var keys: [[KeyView]] = []
    private var theme: ThemeColors = ThemePreset.midnight.colors
    private var settings = KeysSettings()
    private var popup: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        clipsToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    // MARK: - Обновление

    func update(rows: [[KeySpec]], theme: ThemeColors, settings: KeysSettings) {
        let sameLayout = specs.map { $0.map(\.keyID) } == rows.map { $0.map(\.keyID) }
        let appearanceChanged = self.theme != theme || self.settings != settings
        self.specs = rows
        self.theme = theme
        self.settings = settings

        if sameLayout {
            for (row, views) in zip(rows, keys) {
                for (spec, key) in zip(row, views) where appearanceChanged || spec != key.spec {
                    key.configure(spec: spec, theme: theme, settings: settings)
                }
            }
        } else {
            rebuild()
        }
        setNeedsLayout()
    }

    private func rebuild() {
        keys.forEach { row in row.forEach { $0.removeFromSuperview() } }
        keys = []

        for row in specs {
            var views: [KeyView] = []
            for spec in row {
                let key = KeyView(spec: spec)
                key.configure(spec: spec, theme: theme, settings: settings)
                key.onTap = { [weak self] spec in
                    self?.onAction?(spec.action)
                }
                key.onRepeat = { [weak self] spec in
                    self?.onAction?(spec.action)
                }
                key.onLongPress = { [weak self] spec, view in
                    self?.hidePopup()
                    self?.onLongPress?(spec, view)
                }
                key.onSwipe = { [weak self] spec, direction in
                    self?.hidePopup()
                    self?.onSwipe?(spec, direction)
                }
                key.onPressStart = { [weak self] spec, view in
                    self?.showPopupIfNeeded(for: spec, at: view)
                }
                key.onPressEnd = { [weak self] _ in
                    self?.hidePopup(animated: true)
                }
                addSubview(key)
                views.append(key)
            }
            keys.append(views)
        }
    }

    // MARK: - Раскладка

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !keys.isEmpty else { return }

        let gap = CGFloat(settings.keyGap)
        let width = bounds.width
        let usableHeight = max(
            bounds.height - safeAreaInsets.bottom - KeyboardRows.topPadding - KeyboardRows.bottomPadding,
            CGFloat(keys.count) * 30
        )
        let totalGaps = CGFloat(max(keys.count - 1, 0)) * KeyboardRows.verticalGap
        let rowHeight = max((usableHeight - totalGaps) / CGFloat(keys.count), 28)

        var y = KeyboardRows.topPadding
        for (rowIndex, row) in keys.enumerated() {
            let specRow = specs[rowIndex]
            let totalWeight = specRow.reduce(CGFloat(0)) { $0 + $1.width }
            let usableWidth = width
                - 2 * KeyboardRows.sidePadding
                - CGFloat(max(row.count - 1, 0)) * gap
            var x = KeyboardRows.sidePadding

            for (keyIndex, key) in row.enumerated() {
                let weight = max(specRow[keyIndex].width, 0.1)
                let keyWidth = max(usableWidth * weight / max(totalWeight, 0.1), 1)
                key.frame = CGRect(x: x, y: y, width: keyWidth, height: rowHeight).integral
                x += keyWidth + gap
            }

            y += rowHeight + KeyboardRows.verticalGap
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        guard hit === self, let first = keys.first?.first, let last = keys.last?.first,
              point.y >= first.frame.minY, point.y <= last.frame.maxY else { return hit }
        let row = keys.min {
            abs(($0.first?.frame.midY ?? 0) - point.y) < abs(($1.first?.frame.midY ?? 0) - point.y)
        }
        return row?.min {
            let left = max($0.frame.minX - point.x, point.x - $0.frame.maxX)
            let right = max($1.frame.minX - point.x, point.x - $1.frame.maxX)
            return left < right
        } ?? hit
    }

    // MARK: - Всплывающая подсказка

    private func showPopupIfNeeded(for spec: KeySpec, at key: KeyView) {
        guard settings.keyPopup, case .character = spec.action, !spec.label.isEmpty else {
            hidePopup()
            return
        }
        hidePopup()

        let height = min(CGFloat(settings.keyHeight) * 0.92, 46)
        let width = max(key.bounds.width + 14, 34)
        var frame = CGRect(
            x: key.frame.midX - width / 2,
            y: key.frame.minY - height - 2,
            width: width,
            height: height
        )
        frame.origin.x = min(max(frame.origin.x, 2), bounds.width - width - 2)
        frame.origin.y = max(frame.origin.y, -self.frame.minY)

        let label = UILabel(frame: .zero)
        label.text = spec.label
        label.font = UIFont.systemFont(ofSize: CGFloat(settings.fontSize) * 1.15, weight: .regular)
        label.textAlignment = .center
        label.textColor = theme.uiText
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7

        let bubble = UIView(frame: frame)
        bubble.isUserInteractionEnabled = false
        let expressivePopup = settings.design == .expressive && settings.expressiveDetail != .minimal
        bubble.backgroundColor = expressivePopup ? .clear : theme.uiKeyPressed
        if expressivePopup {
            let shape = CAShapeLayer()
            shape.path = ExpressiveShape.cookie.path(in: bubble.bounds)
            shape.fillColor = theme.uiAccent.cgColor
            bubble.layer.addSublayer(shape)
            label.textColor = theme.uiAccent.keysContrastingText
        }
        bubble.layer.cornerRadius = CGFloat(settings.cornerRadius) + 2
        bubble.layer.cornerCurve = .continuous
        bubble.layer.shadowColor = UIColor.black.cgColor
        bubble.layer.shadowOpacity = expressivePopup ? 0 : 0.25
        bubble.layer.shadowRadius = 6
        bubble.layer.shadowOffset = CGSize(width: 0, height: 2)
        label.frame = bubble.bounds.insetBy(dx: 4, dy: 2)
        bubble.addSubview(label)
        bubble.alpha = 0
        addSubview(bubble)
        popup = bubble

        if UIAccessibility.isReduceMotionEnabled {
            bubble.alpha = 1
            return
        }
        UIView.animate(withDuration: 0.09, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            bubble.alpha = 1
        }
    }

    private func hidePopup(animated: Bool = false) {
        guard let popup else { return }
        self.popup = nil
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            popup.removeFromSuperview()
            return
        }
        UIView.animate(
            withDuration: 0.12,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: { popup.alpha = 0 },
            completion: { _ in popup.removeFromSuperview() }
        )
    }
}