import UIKit

/// Клавиатура как системное расширение: раскладки, регистр, эмодзи,
/// альтернативные символы, курсор свайпом по пробелу.
final class KeyboardViewController: UIInputViewController {
    private let store = SettingsStore.shared
    private let keyboardView = KeyboardView()
    private let emojiPanel = EmojiPanelView()

    private let suggestionBar = SuggestionBar()
    private var barHeight: NSLayoutConstraint?
    private lazy var checker = UITextChecker()
    private lazy var languages = UITextChecker.availableLanguages
    private var displayedAt: CursorContext?
    private var lastCorrection: (at: CursorContext, original: String, inserted: String)?
    private var activeDocument: UUID?

    private struct CursorContext: Equatable {
        let document: UUID
        let before: String
        let after: String?
    }

    private var heightConstraint: NSLayoutConstraint?
    private var appliedHeight: CGFloat = 0
    private var builtRows: [[KeySpec]] = []

    private var plane: KeyPlane = .letters
    private var shiftActive = false
    private var shiftGesture = ShiftGesture()
    private var capsLock = false
    private var emojiVisible = false
    private var inputEngine = InputEngine()

    private var currentLayout: KeyboardLayoutID = .english
    private var alternatesOverlay: UIView?
    private var quickSettings: QuickSettingsView?
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
        suggestionBar.translatesAutoresizingMaskIntoConstraints = false
        suggestionBar.onPick = { [weak self] word in self?.acceptSuggestion(word) }
        view.addSubview(suggestionBar)
        view.addSubview(keyboardView)
        view.addSubview(emojiPanel)

        let heightConstraint = view.heightAnchor.constraint(equalToConstant: 280)
        self.heightConstraint = heightConstraint
        heightConstraint.priority = UILayoutPriority(999)

        let barHeight = suggestionBar.heightAnchor.constraint(equalToConstant: 0)
        self.barHeight = barHeight
        NSLayoutConstraint.activate([
            suggestionBar.topAnchor.constraint(equalTo: view.topAnchor),
            suggestionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            barHeight,
            keyboardView.topAnchor.constraint(equalTo: suggestionBar.bottomAnchor),
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
        quickSettings?.removeFromSuperview()
        quickSettings = nil
        if !settings.enabledLayouts.contains(currentLayout) {
            currentLayout = settings.enabledLayouts.first ?? .english
        }
        beginDocument()
        plane = .letters
        emojiVisible = false
        capsLock = false
        shiftActive = shouldAutoShift()
        inputEngine.reset()
        rebuild()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(loadSuggestions), object: nil)
        displayedAt = nil
        lastCorrection = nil
        suggestionBar.display([], color: settings.colors.uiText)
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
        if let correction = lastCorrection, cursorContext() != correction.at { lastCorrection = nil }
        if activeDocument != textDocumentProxy.documentIdentifier {
            beginDocument()
            rebuild()
        }
        updateShiftAfterInput()
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

        suggestionBar.configure(settings: current)
        refreshSuggestions()
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
        let total = ceil(content + (barHeight?.constant ?? 0) + view.safeAreaInsets.bottom)
        guard abs(total - appliedHeight) > 0.5 else { return }
        appliedHeight = total
        heightConstraint?.constant = total
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
            self.inputEngine.reset()
            self.updateShiftAfterInput()
        }
        emojiPanel.onBackspace = { [weak self] in
            self?.handle(.backspace)
        }
        emojiPanel.onGlobe = { [weak self] in
            self?.advanceToNextInputMode()
        }
        emojiPanel.onClose = { [weak self] in
            self?.emojiVisible = false
            self?.rebuild()
        }
        emojiPanel.onSettings = { [weak self] in
            self?.showQuickSettings()
        }
    }

    private func handle(_ action: KeyAction) {
        hideAlternates(animated: true)

        if action != .backspace { lastCorrection = nil }
        if action != .space { inputEngine.reset() }

        if action != .shift { shiftGesture.reset() }
        switch action {
        case .character(let character):
            let text = (shiftActive || capsLock) ? character.uppercased() : character
            textDocumentProxy.insertText(text)
            updateShiftAfterInput()

        case .shift:
            let state = shiftGesture.tap(at: ProcessInfo.processInfo.systemUptime, shifted: shiftActive, locked: capsLock)
            shiftActive = state.shift
            capsLock = state.caps
            rebuild()

        case .backspace:
            if let correction = lastCorrection, cursorContext() == correction.at {
                replaceBeforeCursor(correction.inserted, with: correction.original + " ")
            } else {
                textDocumentProxy.deleteBackward()
            }
            lastCorrection = nil
            updateShiftAfterInput()

        case .space:
            let edit = inputEngine.space(
                before: textDocumentProxy.documentContextBeforeInput,
                at: ProcessInfo.processInfo.systemUptime,
                enabled: settings.doubleSpacePeriod
            )
            switch edit {
            case .insertSpace:
                if settings.correctTypos, let cursor = cursorContext(),
                   let fixed = WritingAssist.correction(in: cursor.before) {
                    let original = WritingAssist.word(before: cursor.before)
                    let replacement = fixed + " "
                    replaceBeforeCursor(original, with: replacement)
                    if let at = cursorContext(), at.before.hasSuffix(replacement) {
                        lastCorrection = (at, original, replacement)
                    }
                } else {
                    textDocumentProxy.insertText(" ")
                }
            case .replaceWithPeriod:
                textDocumentProxy.deleteBackward()
                textDocumentProxy.insertText(". ")
            }
            updateShiftAfterInput()

        case .newline:
            textDocumentProxy.insertText("\n")
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
        lastCorrection = nil
        switch (spec.action, direction) {
        case (.space, .left), (.space, .right):
            guard settings.spaceCursor else { return }
            inputEngine.reset()
            textDocumentProxy.adjustTextPosition(byCharacterOffset: direction == .left ? -1 : 1)
            updateShiftAfterInput()
        case (.layout, .left), (.layout, .right):
            inputEngine.reset()
            switchLayout()
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
        let count = InputEngine.wordDeletionCount(before: textDocumentProxy.documentContextBeforeInput)
        for _ in 0..<count {
            textDocumentProxy.deleteBackward()
        }
        inputEngine.reset()
        updateShiftAfterInput()
    }

    // MARK: - Регистр

    private func shouldAutoShift() -> Bool {
        guard settings.autocapitalize else { return false }
        let mode: CapitalizationMode
        switch textDocumentProxy.autocapitalizationType ?? .sentences {
        case .none: mode = .none
        case .allCharacters: mode = .allCharacters
        case .words: mode = .words
        case .sentences: mode = .sentences
        @unknown default: mode = .none
        }
        return TextInputRules.shouldCapitalize(before: textDocumentProxy.documentContextBeforeInput, mode: mode)
    }

    private func updateShiftAfterInput() {
        defer { refreshSuggestions() }
        guard !capsLock else { return }
        let desired = shouldAutoShift()
        if desired != shiftActive {
            shiftActive = desired
            rebuild()
        }
    }

    private func beginDocument() {
        shiftGesture.reset()
        inputEngine.reset()
        lastCorrection = nil
        capsLock = false
        activeDocument = textDocumentProxy.documentIdentifier
        currentLayout = settings.lastLayout
        if settings.detectLayout, let before = textDocumentProxy.documentContextBeforeInput,
           let language = WritingAssist.nearbyLanguage(in: before) {
            let detected: KeyboardLayoutID = language == "ru" ? .russian : .english
            if settings.enabledLayouts.contains(detected) { currentLayout = detected }
        }
    }

    private var permitsWritingAssistance: Bool {
        guard textDocumentProxy.autocorrectionType != .no else { return false }
        switch textDocumentProxy.keyboardType ?? .default {
        case .default, .asciiCapable, .twitter: return true
        default: return false
        }
    }

    private func cursorContext() -> CursorContext? {
        guard permitsWritingAssistance, textDocumentProxy.selectedText?.isEmpty != false,
              let before = textDocumentProxy.documentContextBeforeInput else { return nil }
        if before.suffix(96).allSatisfy({ $0.isLetter }), before.count > 96 { return nil }
        let after = textDocumentProxy.documentContextAfterInput
        if let next = after?.first, next.isLetter || next.isNumber { return nil }
        return CursorContext(document: textDocumentProxy.documentIdentifier,
                             before: String(before.suffix(96)), after: after.map { String($0.prefix(16)) })
    }

    private func refreshSuggestions() {
        let show = settings.suggestions && !emojiVisible && plane == .letters
            && permitsWritingAssistance
        let height: CGFloat = show ? 44 : 0
        if barHeight?.constant != height {
            barHeight?.constant = height
            updateHeight()
        }
        suggestionBar.isHidden = !show
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(loadSuggestions), object: nil)
        displayedAt = nil
        suggestionBar.display([], color: settings.colors.uiText)
        if show { perform(#selector(loadSuggestions), with: nil, afterDelay: 0.06) }
    }

    @objc private func loadSuggestions() {
        guard let cursor = cursorContext() else { return }
        let word = WritingAssist.word(before: cursor.before)
        let russian = currentLayout == .russian
        var words: [String] = []
        if word.isEmpty {
            words = WritingAssist.nextWords(before: cursor.before, russian: russian)
            if shiftActive || capsLock { words = words.map(WritingAssist.titleCase) }
        } else {
            if let fixed = WritingAssist.correction(in: cursor.before) { words.append(fixed) }
            let prefix = russian ? "ru" : "en"
            if let language = languages.first(where: { $0.hasPrefix(prefix) }) {
                let range = NSRange(word.startIndex..<word.endIndex, in: word)
                let completions = checker.completions(forPartialWordRange: range, in: word, language: language) ?? []
                for completion in completions where completion != word && !words.contains(completion) {
                    words.append(completion)
                    if words.count == 3 { break }
                }
            }
        }
        displayedAt = cursor
        suggestionBar.display(words, color: settings.colors.uiText)
    }

    private func acceptSuggestion(_ word: String) {
        guard let cursor = displayedAt, cursor == cursorContext() else { return }
        lastCorrection = nil
        inputEngine.reset()
        let replacement = WritingAssist.suggestionText(word, before: cursor.before, after: cursor.after)
        replaceBeforeCursor(WritingAssist.word(before: cursor.before), with: replacement)
        updateShiftAfterInput()
    }

    private func replaceBeforeCursor(_ original: String, with replacement: String) {
        for _ in original { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(replacement)
    }

    // MARK: - Быстрые настройки

    /// Панель настроек прямо в клавиатуре: работает и без App Group.
    private func showQuickSettings() {
        guard quickSettings == nil else { return }
        hideAlternates(animated: false)

        let panel = QuickSettingsView(store: store)
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.alpha = 0
        panel.onChange = { [weak self] in
            self?.rebuild()
        }
        panel.onClose = { [weak self] in
            self?.hideQuickSettings()
        }

        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: view.topAnchor),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        quickSettings = panel

        UIView.animate(withDuration: 0.15, delay: 0, options: [.allowUserInteraction]) {
            panel.alpha = 1
        }
    }

    private func hideQuickSettings() {
        guard let panel = quickSettings else { return }
        quickSettings = nil
        UIView.animate(
            withDuration: 0.12,
            animations: { panel.alpha = 0 },
            completion: { _ in panel.removeFromSuperview() }
        )
        rebuild()
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
            button.setTitle(shiftActive || capsLock ? character.uppercased() : character, for: .normal)
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
        inputEngine.reset()
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