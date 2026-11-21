import UIKit

final class EmojiCell: UICollectionViewCell {
    static let reuseID = "EmojiCell"
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            label.topAnchor.constraint(equalTo: contentView.topAnchor),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    override var isHighlighted: Bool {
        didSet {
            contentView.backgroundColor = isHighlighted ? UIColor.white.withAlphaComponent(0.15) : .clear
        }
    }
}

/// Панель эмодзи: категории сверху, сетка, служебные клавиши снизу.
final class EmojiPanelView: UIView {
    var onInsert: ((String) -> Void)?
    var onBackspace: (() -> Void)?
    var onGlobe: (() -> Void)?
    var onClose: (() -> Void)?

    private let categoryScroll = UIScrollView()
    private let categoryStack = UIStackView()
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 2
        layout.sectionInset = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.alwaysBounceVertical = true
        view.dataSource = self
        view.delegate = self
        view.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.reuseID)
        return view
    }()

    private let barStack = UIStackView()
    private var categories: [EmojiCategory] = EmojiCatalog.all
    private var selectedCategory = 0
    private var categoryButtons: [UIButton] = []

    private var theme: ThemeColors = ThemePreset.midnight.colors
    private var settings = KeysSettings()
    private var deleteTimer: Timer?
    private var barHeight: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    deinit {
        deleteTimer?.invalidate()
    }

    // MARK: - Построение

    private func build() {
        categoryScroll.showsHorizontalScrollIndicator = false
        categoryScroll.translatesAutoresizingMaskIntoConstraints = false
        categoryStack.axis = .horizontal
        categoryStack.spacing = 4
        categoryStack.alignment = .center
        categoryStack.translatesAutoresizingMaskIntoConstraints = false
        categoryScroll.addSubview(categoryStack)

        collectionView.translatesAutoresizingMaskIntoConstraints = false

        barStack.axis = .horizontal
        barStack.spacing = 6
        barStack.distribution = .fill
        barStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(categoryScroll)
        addSubview(collectionView)
        addSubview(barStack)

        barHeight = barStack.heightAnchor.constraint(equalToConstant: 40)
        NSLayoutConstraint.activate([
            categoryScroll.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            categoryScroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            categoryScroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            categoryScroll.heightAnchor.constraint(equalToConstant: 34),

            categoryStack.leadingAnchor.constraint(equalTo: categoryScroll.contentLayoutGuide.leadingAnchor),
            categoryStack.trailingAnchor.constraint(equalTo: categoryScroll.contentLayoutGuide.trailingAnchor),
            categoryStack.topAnchor.constraint(equalTo: categoryScroll.contentLayoutGuide.topAnchor),
            categoryStack.bottomAnchor.constraint(equalTo: categoryScroll.contentLayoutGuide.bottomAnchor),
            categoryStack.heightAnchor.constraint(equalTo: categoryScroll.frameLayoutGuide.heightAnchor),

            collectionView.topAnchor.constraint(equalTo: categoryScroll.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: barStack.topAnchor, constant: -2),

            barStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            barStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            barStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -4),
            barHeight
        ])
    }

    // MARK: - Конфигурация

    func apply(theme: ThemeColors, settings: KeysSettings, recents: [String], showGlobe: Bool) {
        self.theme = theme
        self.settings = settings
        backgroundColor = theme.uiBackground

        var list: [EmojiCategory] = []
        if !recents.isEmpty {
            list.append(EmojiCategory(title: "Недавние", icon: "🕘", emojis: recents))
        }
        list.append(contentsOf: EmojiCatalog.all)
        let keepTitle = categories.indices.contains(selectedCategory) ? categories[selectedCategory].title : nil
        categories = list
        if let keepTitle, let index = categories.firstIndex(where: { $0.title == keepTitle }) {
            selectedCategory = index
        } else {
            selectedCategory = 0
        }

        barHeight.constant = max(CGFloat(settings.keyHeight) * 0.85, 36)
        collectionView.backgroundColor = .clear
        rebuildCategories()
        rebuildBar(showGlobe: showGlobe)
        collectionView.reloadData()
    }

    private func rebuildCategories() {
        categoryButtons.forEach { $0.removeFromSuperview() }
        categoryButtons = []

        for (index, category) in categories.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(category.icon, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 19)
            button.layer.cornerRadius = 8
            button.layer.cornerCurve = .continuous
            button.tag = index
            button.addTarget(self, action: #selector(tapCategory(_:)), for: .touchUpInside)
            button.widthAnchor.constraint(equalToConstant: 34).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            categoryStack.addArrangedSubview(button)
            categoryButtons.append(button)
        }
        updateCategorySelection()
    }

    private func rebuildBar(showGlobe: Bool) {
        barStack.arrangedSubviews.forEach {
            barStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let close = barButton(title: "ABC", systemImage: nil)
        close.addTarget(self, action: #selector(tapClose), for: .touchUpInside)
        barStack.addArrangedSubview(close)

        if showGlobe {
            let globe = barButton(title: nil, systemImage: "globe")
            globe.addTarget(self, action: #selector(tapGlobe), for: .touchUpInside)
            globe.widthAnchor.constraint(equalToConstant: 48).isActive = true
            barStack.addArrangedSubview(globe)
        }

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        barStack.addArrangedSubview(spacer)

        let delete = barButton(title: nil, systemImage: "delete.left")
        delete.addTarget(self, action: #selector(deleteDown), for: .touchDown)
        delete.addTarget(self, action: #selector(deleteUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        delete.widthAnchor.constraint(equalToConstant: 54).isActive = true
        barStack.addArrangedSubview(delete)
    }

    private func barButton(title: String?, systemImage: String?) -> UIButton {
        let button = UIButton(type: .system)
        if let title {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: max(CGFloat(settings.fontSize) * 0.72, 13), weight: .medium)
        }
        if let systemImage {
            let config = UIImage.SymbolConfiguration(pointSize: CGFloat(settings.fontSize) * 0.85, weight: .medium)
            button.setImage(UIImage(systemName: systemImage, withConfiguration: config), for: .normal)
        }
        button.tintColor = theme.uiText
        button.backgroundColor = theme.uiModifier
        button.layer.cornerRadius = CGFloat(settings.cornerRadius)
        button.layer.cornerCurve = .continuous
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return button
    }

    private func updateCategorySelection() {
        for (index, button) in categoryButtons.enumerated() {
            let selected = index == selectedCategory
            button.backgroundColor = selected ? theme.uiKeyPressed : .clear
            button.alpha = selected ? 1 : 0.65
        }
    }

    // MARK: - Действия

    @objc private func tapCategory(_ sender: UIButton) {
        guard categories.indices.contains(sender.tag) else { return }
        selectedCategory = sender.tag
        updateCategorySelection()
        collectionView.reloadData()
        collectionView.setContentOffset(.zero, animated: false)
    }

    @objc private func tapClose() {
        onClose?()
    }

    @objc private func tapGlobe() {
        onGlobe?()
    }

    @objc private func deleteDown() {
        onBackspace?()
        deleteTimer?.invalidate()
        let timer = Timer(timeInterval: 0.09, repeats: true) { [weak self] _ in
            self?.onBackspace?()
        }
        RunLoop.main.add(timer, forMode: .common)
        deleteTimer = timer
    }

    @objc private func deleteUp() {
        deleteTimer?.invalidate()
        deleteTimer = nil
    }
}

// MARK: - UICollectionView

extension EmojiPanelView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard categories.indices.contains(selectedCategory) else { return 0 }
        return categories[selectedCategory].emojis.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: EmojiCell.reuseID,
            for: indexPath
        ) as? EmojiCell ?? EmojiCell(frame: .zero)
        let emoji = categories[selectedCategory].emojis[indexPath.item]
        cell.label.text = emoji
        cell.label.font = UIFont.systemFont(ofSize: 28)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let emoji = categories[selectedCategory].emojis[indexPath.item]
        onInsert?(emoji)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let columns: CGFloat = 8
        let spacing: CGFloat = 4
        let width = collectionView.bounds.width
        let side = max((width - 8 - (columns - 1) * spacing) / columns, 24)
        return CGSize(width: side, height: side)
    }
}