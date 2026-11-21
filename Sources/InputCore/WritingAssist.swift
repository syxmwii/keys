enum WritingAssist {
    static let typos = [
        "teh": "the", "thier": "their", "taht": "that", "adn": "and",
        "recieve": "receive", "adress": "address", "becuase": "because",
        "tomorow": "tomorrow", "wierd": "weird", "freind": "friend",
        "првиет": "привет", "првиетик": "приветик", "спаисбо": "спасибо",
        "спасбио": "спасибо", "пожалйуста": "пожалуйста", "сегондя": "сегодня",
        "заврта": "завтра", "котоырй": "который", "потмоу": "потому"
    ]

    static func word(before context: String) -> String {
        String(context.reversed().prefix(while: { $0.isLetter }).reversed())
    }

    static func suggestionText(_ suggestion: String, before: String, after: String?) -> String {
        let needsLeadingSpace = before.last.map {
            !$0.isLetter && !$0.isWhitespace && !"(\"«“".contains($0)
        } ?? false
        let needsTrailingSpace = after?.first.map { !$0.isWhitespace && !$0.isPunctuation } ?? true
        return (needsLeadingSpace ? " " : "") + suggestion + (needsTrailingSpace ? " " : "")
    }

    static func correction(in context: String) -> String? {
        let token = word(before: context)
        let prefix = context.dropLast(token.count)
        guard let fixed = typos[token.lowercased()],
              token == token.lowercased() || token == titleCase(token.lowercased()),
              prefix.last.map({ $0.isWhitespace || "(\"«“".contains($0) }) ?? true else { return nil }
        return token.first?.isUppercase == true ? titleCase(fixed) : fixed
    }

    static func titleCase(_ word: String) -> String {
        word.prefix(1).uppercased() + word.dropFirst()
    }

    static func nearbyLanguage(in context: String) -> String? {
        for character in context.suffix(64).lowercased().reversed() {
            if ("а"..."я").contains(character) || character == "ё" { return "ru" }
            if ("a"..."z").contains(character) { return "en" }
            if character.isLetter { return nil }
        }
        return nil
    }

    static func nextWords(before context: String, russian: Bool) -> [String] {
        let previous = context.split(whereSeparator: { !$0.isLetter }).last?.lowercased()
        switch (russian, previous) {
        case (true, "доброе"): return ["утро", "дело", "слово"]
        case (true, "до"): return ["встречи", "завтра", "вечера"]
        case (true, "как"): return ["дела", "ты", "обычно"]
        case (true, "спасибо"): return ["за", "большое", "вам"]
        case (false, "thank"): return ["you", "them", "everyone"]
        case (false, "see"): return ["you", "the", "if"]
        case (false, "good"): return ["morning", "luck", "night"]
        case (false, "how"): return ["are", "do", "much"]
        default: return russian ? ["я", "мы", "это"] : ["I", "the", "we"]
        }
    }
}
