enum CapitalizationMode {
    case none, allCharacters, words, sentences
}

enum TextInputRules {
    static func canReplaceSpace(in context: String?) -> Bool {
        guard let context, context.last == " ",
              let previous = context.dropLast().last else { return false }
        return !previous.isWhitespace && !".!?…".contains(previous)
    }

    static func shouldCapitalize(before context: String?, mode: CapitalizationMode) -> Bool {
        switch mode {
        case .none:
            return false
        case .allCharacters:
            return true
        case .words:
            return context?.last?.isWhitespace ?? true
        case .sentences:
            for character in (context ?? "").reversed() {
                if character.isNewline { return true }
                if !character.isWhitespace { return ".!?…".contains(character) }
            }
            return true
        }
    }
}

struct ShiftGesture {
    private var previousTap: Double?

    mutating func reset() {
        previousTap = nil
    }

    mutating func tap(at time: Double, shifted: Bool, locked: Bool) -> (shift: Bool, caps: Bool) {
        if locked {
            reset()
            return (false, false)
        }
        if let previousTap, (0...0.35).contains(time - previousTap) {
            reset()
            return (false, true)
        }
        previousTap = time
        return (!shifted, false)
    }
}
