import UIKit

/// Быстрые настройки внутри самой клавиатуры.
///
/// Нужны, когда App Group недоступна (неподписанная сборка / бесплатный Apple ID):
/// приложение тогда не может передать настройки расширению, и всё, что здесь
/// меняется, живёт в UserDefaults расширения.
final class QuickSettingsView: UIView {
    private let store: SettingsStore
    var onChange: (() -> Void)?
    var onClose: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let titleLabel = UILabel()
    private let doneButton = UIButton(type: .system)
    private let heightValueLabel = UILabel()
    private let heightSlider = UISlider()
    private var themeButtons: [UIButton] = []
    private var switchRows: [UISwitch] = []
    private let footerLabel = UILabel()

    private let presets = ThemePreset.allCases
    private var colors: ThemeColors { store.settings.colors }

    init(store: SettingsStore) {
        self.store = store
        super.init(frame: .zero)
        build()
        reloadState()
        applyTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    // MARK: - Построение

    private func build() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        contentStack.axis = .vertical
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 10, right: 12)

        addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        contentStack.addArrangedSubview(header())
        contentStack.addArrangedSubview(themeRow())
        contentStack.addArrangedSubview(heightRow())
        contentStack.addArrangedSubview(toggleRow(title: "Вибрация", tag: 0))
        contentStack.addArrangedSubview(toggleRow(title: "Звук", tag: 1))
        contentStack.addArrangedSubview(toggleRow(title: "Ряд цифр", tag: 2))

        footerLabel.font = UIFont.systemFont(ofSize: 11)
        footerLabel.numberOfLines = 0
        footerLabel.text = "Применяется сразу. Полный набор — в приложении Keys."
        contentStack.addArrangedSubview(footerLabel)
    }

    private func header() -> UIView {
        titleLabel.text = "Настройки клавиатуры"
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)

        doneButton.setTitle("Готово", for: .normal)
        doneButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        doneButton.addTarget(self, action: #selector(tapDone), for: .touchUpInside)
        doneButton.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [titleLabel, UIView(), doneButton])
        row.axis = .horizontal
        row.alignment = .center
        return row
    }

    private func themeRow() -> UIView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 38)
        ])

        for (index, preset) in presets.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.layer.cornerRadius = 9
            button.layer.cornerCurve = .continuous
            button.layer.borderWidth = 1
            button.addTarget(self, action: #selector(tapTheme(_:)), for: .touchUpInside)
            button.widthAnchor.constraint(equalToConstant: 38).isActive = true
            button.accessibilityLabel = preset.title
            stack.addArrangedSubview(button)
            themeButtons.append(button)
        }
        return scroll
    }

    private func heightRow() -> UIView {
        let title = UILabel()
        title.text = "Высота клавиш"
        title.font = UIFont.systemFont(ofSize: 13)
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)

        heightValueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        heightValueLabel.textAlignment = .right
        heightValueLabel.setContentHuggingPriority(.required, for: .horizontal)

        let top = UIStackView(arrangedSubviews: [title, heightValueLabel])
        top.axis = .horizontal

        heightSlider.minimumValue = 40
        heightSlider.maximumValue = 68
        heightSlider.addTarget(self, action: #selector(heightChanged(_:)), for: .valueChanged)

        let column = UIStackView(arrangedSubviews: [top, heightSlider])
        column.axis = .vertical
        column.spacing = 2
        return column
    }

    private func toggleRow(title: String, tag: Int) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 13)

        let toggle = UISwitch()
        toggle.tag = tag
        toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
        toggle.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        let row = UIStackView(arrangedSubviews: [label, UIView(), toggle])
        row.axis = .horizontal
        row.alignment = .center
        switchRows.append(toggle)
        return row
    }

    // MARK: - Состояние

    private func reloadState() {
        let settings = store.settings
        heightSlider.value = Float(settings.keyHeight)
        heightValueLabel.text = "\(Int(settings.keyHeight)) pt"
        if switchRows.count == 3 {
            switchRows[0].isOn = settings.haptics
            switchRows[1].isOn = settings.sound
            switchRows[2].isOn = settings.numberRow
        }
        for (index, button) in themeButtons.enumerated() {
            let preset = presets[index]
            let selected = settings.theme == preset
            button.backgroundColor = preset.colors.uiKey
            button.layer.borderColor = (selected ? preset.colors.uiAccent : preset.colors.uiBorder).cgColor
            button.layer.borderWidth = selected ? 2 : 1
        }
    }

    private func applyTheme() {
        let theme = colors
        backgroundColor = theme.uiBackground
        titleLabel.textColor = theme.uiText
        footerLabel.textColor = theme.uiText.withAlphaComponent(0.55)
        heightValueLabel.textColor = theme.uiText
        doneButton.tintColor = theme.uiAccent
        heightSlider.minimumTrackTintColor = theme.uiAccent
        heightSlider.maximumTrackTintColor = theme.uiModifier
        heightSlider.thumbTintColor = theme.uiAccent
        switchRows.forEach {
            $0.onTintColor = theme.uiAccent
            $0.thumbTintColor = UIColor.white
        }
        // Подписи строк
        for view in contentStack.arrangedSubviews {
            for label in deepLabels(in: view) where label !== titleLabel && label !== footerLabel && label !== heightValueLabel {
                label.textColor = theme.uiText
            }
        }
    }

    private func deepLabels(in view: UIView) -> [UILabel] {
        var result: [UILabel] = []
        if let label = view as? UILabel { result.append(label) }
        for subview in view.subviews { result.append(contentsOf: deepLabels(in: subview)) }
        return result
    }

    // MARK: - Действия

    @objc private func tapDone() {
        onClose?()
    }

    @objc private func tapTheme(_ sender: UIButton) {
        guard presets.indices.contains(sender.tag) else { return }
        store.settings.theme = presets[sender.tag]
        reloadState()
        applyTheme()
        onChange?()
    }

    @objc private func heightChanged(_ sender: UISlider) {
        let value = Double(sender.value.rounded())
        store.settings.keyHeight = value
        heightValueLabel.text = "\(Int(value)) pt"
        onChange?()
    }

    @objc private func toggleChanged(_ sender: UISwitch) {
        switch sender.tag {
        case 0: store.settings.haptics = sender.isOn
        case 1: store.settings.sound = sender.isOn
        case 2: store.settings.numberRow = sender.isOn
        default: break
        }
        onChange?()
    }
}