import UIKit

final class SuggestionBar: UIStackView {
    var onPick: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        distribution = .fillEqually
        for _ in 0..<3 {
            let button = UIButton(type: .system)
            button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.titleLabel?.lineBreakMode = .byTruncatingTail
            button.addTarget(self, action: #selector(pick(_:)), for: .touchUpInside)
            addArrangedSubview(button)
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) unavailable")
    }

    func display(_ words: [String], color: UIColor) {
        for (index, view) in arrangedSubviews.enumerated() {
            guard let button = view as? UIButton else { continue }
            let word = words.indices.contains(index) ? words[index] : nil
            button.setTitle(word, for: .normal)
            button.setTitleColor(color, for: .normal)
            button.isEnabled = word != nil
            button.isAccessibilityElement = word != nil
        }
    }

    @objc private func pick(_ button: UIButton) {
        if let word = button.currentTitle { onPick?(word) }
    }
}
