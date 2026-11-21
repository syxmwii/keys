struct InputEngine {
    enum SpaceEdit: Equatable {
        case insertSpace
        case replaceWithPeriod
    }

    private var lastSpaceTime: Double?

    mutating func reset() {
        lastSpaceTime = nil
    }

    mutating func space(before context: String?, at time: Double, enabled: Bool) -> SpaceEdit {
        guard enabled, let previous = lastSpaceTime,
              (0...0.5).contains(time - previous),
              TextInputRules.canReplaceSpace(in: context) else {
            lastSpaceTime = enabled ? time : nil
            return .insertSpace
        }
        reset()
        return .replaceWithPeriod
    }

    static func wordDeletionCount(before context: String?) -> Int {
        let before = (context ?? "").reversed().prefix(32)
        let trailingWhitespace = before.prefix(while: { $0.isWhitespace }).count
        let wordLength = before.dropFirst(trailingWhitespace).prefix(while: { !$0.isWhitespace }).count
        return trailingWhitespace + wordLength
    }
}
