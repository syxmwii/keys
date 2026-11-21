import UIKit

/// Клавиатура как системное расширение: раскладки, регистр, эмодзи,
/// альтернативные символы, курсор свайпом по пробелу.
final class KeyboardViewController: UIInputViewController {
    private let store = SettingsStore.shared
    private let keyboardView = KeyboardView()
    private let emojiPanel = EmojiPanelView()

    private var heightConstraint: NSLayoutConstraint!
    private var appliedHeight: CGFloat = 0
    private var builtRows: [[KeySpec]] = []

    private var plane: KeyPlane = .letters
    private var shiftActive = false
    private var capsLock = false
    private var emojiVisible = false
    private var lastInsertedSpace = false

    private var currentLayout: KeyboardLayoutID = .english
    private var alternatesOverlay: UIView?
    private var pendingAlternates: [String] = []
    private var alternatesTimer: Timer?

    private var settings: KeysSettings { store.settings }

    // MARK: - Жизненный цикл

    override func viewDidLoad() {
        super.viewDidLoad()
        currentLayout = store.settings.lastLayout
        view.backgroundColor = settings.colors.uiBackground

        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        emojiPanel.translatesAutoresizingMaskIntoConstraints = false
        emojiPanel.isHidden = true
        view.addSubview(keyboardView)
        view.addSubview(emojiPanel)

        heightConstraint = view.heightAnchor.constraint(equalToConstant: 280)
        heightConstraint.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emojiPanel.topAnchor.constraint(equalTo: view.topAnchor),
            emojiPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emojiPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emojiPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            heightConstraint
        ])

        wireKeyboard()
        wireEmoji()
        rebuild()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        store.reload()
        if !settings.enabledLayouts.contains(currentLayout) {
            currentLayout = settings.enabledLayouts.first ?? .english
        }
        plane = .letters
        emojiVisible = false
        capsLock = false
        shiftActive = false
        rebuild()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeight()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateHeight()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        if !capsLock {
            let desired = shouldAutoShift()
            if desired != shiftActive {
                shiftActive = desired
                rebuild()
            }
        }
    }

    // MARK: - Сборка

    private func rebuild() {
        hideAlternates(animated: false)
        let current = settings
        let colors = current.colors

        if !current.enabledLayouts.contains(currentLayout) {
            currentLayout = current.enabledLayouts.first ?? .english
        }

        view.backgroundColor = colors.uiBackground
        builtRows = KeyboardRows.rows(
            layout: currentLayout,
            plane: plane,
            shift: shiftActive,
            caps: capsLock,
            settings: current,
            enabledLayouts: current.enabledLayouts,
            showGlobe: needsInputModeSwitchKey,
            returnKey: "return"
        )

        keyboardView.isHidden = emojiVisible
        emojiPanel.isHidden = !emojiVisible

        keyboardView.update(rows: builtRows, theme: colors, settings: current)
        emojiPanel.apply(
            theme: colors,
            settings: current,
            recents: current.emojiRecents,
            showGlobe: needsInputModeSwitchKey
        )
        updateHeight()
    }

    private func updateHeight() {
        let current = settings
        let content: CGFloat
        if emojiVisible {
            content = KeyboardRows.contentHeight(rowCount: 5, settings: current) + 42
        } else {
            content = KeyboardRows.contentHeight(rowCount: max(builtRows.count, 1), settings: current)
        }
        let total = ceil(content + view.safeAreaInsets.bottom)
        guard abs(total - appliedHeight) > 0.5 else { return }
        appliedHeight = total
        heightConstraint.constant = total
    }

    // MARK: - Обработка клавиш

    private func wireKeyboard() {
        keyboardView.onAction = { [weak self] action in
            self?.handle(action)
        }
        keyboardView.onLongPress = { [weak self] spec, key in
            self?.showAlternates(for: spec, from: key)
        }
        keyboardView.onSwipe = { [weak self] spec, direction in
            self?.handleSwipe(spec: spec, direction: direction)
        }
    }

    private func wireEmoji() {
        emojiPanel.onInsert = { [weak self] emoji in
            guard let self else { return }
            self.textDocumentProxy.insertText(emoji)
            self.store.settings.rememberEmoji(emoji)
            self.lastInsertedSpace = false
        }
        emojiPanel.onBackspace = { [weak self] in
            self?.textDocumentProxy.deleteBackward()
        }
        emojiPanel.onGlobe = { [weak self] in
            self?.advanceToNextInputMode()
        }
        emojiPanel.onClose = { [weak self] in
            self?.emojiVisible = false
            self?.rebuild()
        }
    }

    private func handle(_ action: KeyAction) {
        hideAlternates(animated: true)

        switch action {
        case .character(let character):
            let text = (shiftActive || capsLock) ? character.uppercased() : character
            textDocumentProxy.insertText(text)
            lastInsertedSpace = false
            if !capsLock { shiftActive = false }
            updateShiftAfterInput()

        case .shift:
            if capsLock {
                capsLock = false
                shiftActive = false
            } else if shiftActive {
                shiftActive = false
                capsLock = true
            } else {
                shiftActive = true
            }
            rebuild()

        case .backspace:
            textDocumentProxy.deleteBackward()
            lastInsertedSpace = false
            updateShiftAfterInput()

        case .space:
            if settings.doubleSpacePeriod && lastInsertedSpace {
                let before = textDocumentProxy.documentContextBeforeInput ?? ""
                if before.hasSuffix(" ") {
                    textDocumentProxy.deleteBackward()
                }
                textDocumentProxy.insertText(". ")
                lastInsertedSpace = false
            } else {
                textDocumentProxy.insertText(" ")
                lastInsertedSpace = true
            }
            updateShiftAfterInput()

        case .newline:
            textDocumentProxy.insertText("\n")
            lastInsertedSpace = false
            updateShiftAfterInput()

        case .globe:
            advanceToNextInputMode()

        case .emoji:
            emojiVisible.toggle()
            rebuild()

        case .plane(let target):
            plane = target
            rebuild()

        case .layout:
            switchLayout()

        case .dismiss:
            dismissKeyboard()

        case .none:
            break
        }
    }

    private func handleSwipe(spec: KeySpec, direction: KeyView.Swipe) {
        switch (spec.action, direction) {
        case (.space, .left):
            if settings.spaceCursor { textDocumentProxy.adjustTextPosition(byCharacterOffset: -1) }
        case (.space, .right):
            if settings.spaceCursor { textDocumentProxy.adjustTextPosition(byCharacterOffset: 1) }
        case (.backspace, .left):
            if settings.swipeBackspace { deleteWord() }
        default:
            break
        }
    }

    private func switchLayout() {
        let enabled = settings.enabledLayouts
        guard enabled.count > 1 else { return }
        let index = enabled.firstIndex(of: currentLayout) ?? 0
        currentLayout = enabled[(index + 1) % enabled.count]
        store.settings.lastLayout = currentLayout
        shiftActive = false
        capsLock = false
        rebuild()
    }

    private func deleteWord() {
        guard let before = textDocumentProxy.documentContextBeforeInput, !before.isEmpty else { return }
        var count = 0
        for character in before.reversed() {
            if character == " " && count > 0 { break }
            count += 1
            if count >= 32 { break }
        }
        for _ in 0..<max(count, 1) {
            textDocumentProxy.deleteBackward()
        }
        lastInsertedSpace = false
        updateShiftAfterInput()
    }

    // MARK: - Регистр

    private func shouldAutoShift() -> Bool {
        guard settings.autocapitalize else { return false }
        let traits = textDocumentProxy.autocapitalizationType ?? .sentences
        switch traits {
        case .none:
            return false
        case .allCharacters:
            return true
        default:
            break
        }

        guard let before = textDocumentProxy.documentContextBeforeInput, !before.isEmpty else {
            return true
        }
        let trimmedRight = before.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
        if trimmedRight.isEmpty { return true }
        guard let last = trimmedRight.last else { return true }
        return ".!?\n".contains(last)
    }

    private func updateShiftAfterInput() {
        guard !capsLock else { return }
        let desired = shouldAutoShift()
        if desired != shiftActive {
            shiftActive = desired
            rebuild()
        }
    }

    // MARK: - Альтернативные символы

    private func showAlternates(for spec: KeySpec, from key: KeyView) {
        guard !spec.alternates.isEmpty else { return }
        hideAlternates(animated: false)

        pendingAlternates = spec.alternates
        let height: CGFloat = 46
        let keyWidth: CGFloat = 42
        let totalWidth = min(CGFloat(spec.alternates.count) * keyWidth + 10, view.bounds.width - 16)

        let keyFrame = key.convert(key.bounds, to: view)
        var originX = keyFrame.midX - totalWidth / 2
        originX = min(max(originX, 8), view.bounds.width - totalWidth - 8)
        var originY = keyFrame.minY - height - 6
        if originY < 4 {
            originY = keyFrame.maxY + 6
        }

        let container = UIView(frame: CGRect(x: originX, y: originY, width: totalWidth, height: height))
        container.backgroundColor = settings.colors.uiKey
        container.layer.cornerRadius = 12
        container.layer.cornerCurve = .continuous
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.3
        container.layer.shadowRadius = 8
        container.layer.shadowOffset = CGSize(width: 0, height: 3)
        container.clipsToBounds = false

        let stack = UIStackView(frame: container.bounds.insetBy(dx: 5, dy: 4))
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 2
        stack.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        for (index, character) in spec.alternates.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(character, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: CGFloat(settings.fontSize) * 1.2)
            button.setTitleColor(settings.colors.uiText, for: .normal)
            button.tag = index
            button.addTarget(self, action: #selector(tapAlternate(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        container.addSubview(stack)
        view.addSubview(container)
        alternatesOverlay = container

        container.alpha = 0
        container.transform = CGAffineTransform(translationX: 0, y: 4).scaledBy(x: 0.98, y: 0.98)
        UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            container.alpha = 1
            container.transform = .identity
        }

        let timer = Timer(timeInterval: 3.5, repeats: false) { [weak self] _ in
            self?.hideAlternates(animated: true)
        }
        RunLoop.main.add(timer, forMode: .common)
        alternatesTimer = timer
    }

    @objc private func tapAlternate(_ sender: UIButton) {
        guard pendingAlternates.indices.contains(sender.tag) else { return }
        let character = pendingAlternates[sender.tag]
        let text = (shiftActive || capsLock) ? character.uppercased() : character
        textDocumentProxy.insertText(text)
        if !capsLock { shiftActive = false }
        hideAlternates(animated: true)
        updateShiftAfterInput()
    }

    private func hideAlternates(animated: Bool) {
        alternatesTimer?.invalidate()
        alternatesTimer = nil
        guard let overlay = alternatesOverlay else { return }
        alternatesOverlay = nil
        pendingAlternates = []
        guard animated else {
            overlay.removeFromSuperview()
            return
        }
        UIView.animate(
            withDuration: 0.1,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: { overlay.alpha = 0 },
            completion: { _ in overlay.removeFromSuperview() }
        )
    }
}