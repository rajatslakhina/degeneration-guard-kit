/// Finds a stream that ends in the same sentence, or the same run of sentences, several times
/// in a row, compared after normalization.
///
/// A unit ends at a newline, at a full-width terminator, or at whitespace that follows `.`, `!`
/// or `?`. Units are compared by `UnitKey`, so a loop that varies its spacing, its list numbers
/// or (with `maskDigits`) the numbers it is checking still repeats. This catches what the
/// verbatim detector cannot: blocks longer than `maximumPeriod` scalars, and copies that differ
/// only in spacing, case or numbering.
public struct UnitCycleDetector: LoopDetector {
    public let policy: DegenerationPolicy
    private var units: [Unit] = []
    private var unitStart: Int?
    private var afterTerminator = false
    private var unitHasLetter = false

    struct Unit: Sendable {
        let key: String
        let start: Int
        let end: Int
    }

    /// Scalars that end a unit when whitespace follows them ("3.14" stays whole), and only once
    /// the unit has a letter, so the "2." of a numbered list stays with its item.
    static let terminators: Set<Unicode.Scalar> = [".", "!", "?"]
    /// Scalars that end a unit at once: CJK text puts no space after a sentence.
    static let wideTerminators: Set<Unicode.Scalar> = ["\u{3002}", "\u{FF01}", "\u{FF1F}"]

    public init(policy: DegenerationPolicy = .standard) {
        self.policy = policy
    }

    public mutating func observe(_ scalar: Unicode.Scalar, in history: ScalarHistory) -> DegenerationFinding? {
        let index = history.count - 1
        if scalar == "\n" { return close(end: index, in: history) }
        if scalar.properties.isWhitespace {
            return afterTerminator ? close(end: index, in: history) : nil
        }
        if unitStart == nil { unitStart = index }
        if Self.wideTerminators.contains(scalar) { return close(end: index + 1, in: history) }
        unitHasLetter = unitHasLetter || scalar.properties.isAlphabetic
        afterTerminator = unitHasLetter && Self.terminators.contains(scalar)
        return nil
    }

    public mutating func finish(in history: ScalarHistory) -> DegenerationFinding? {
        close(end: history.count, in: history)
    }

    private mutating func close(end: Int, in history: ScalarHistory) -> DegenerationFinding? {
        afterTerminator = false
        unitHasLetter = false
        guard let start = unitStart else { return nil }
        unitStart = nil
        guard let key = UnitKey.make(history.text(start..<end), policy: policy) else { return nil }
        units.append(Unit(key: key, start: start, end: end))
        let keep = policy.maximumUnitPeriod * policy.minimumCopies
        if units.count > keep { units.removeFirst(units.count - keep) }
        return cycle(scanned: history.count, history: history)
    }

    /// The smallest run of units whose last `minimumCopies` copies are identical.
    private func cycle(scanned: Int, history: ScalarHistory) -> DegenerationFinding? {
        let copies = policy.minimumCopies
        for length in 1...policy.maximumUnitPeriod {
            let span = length * copies
            guard span <= units.count else { return nil }
            let tail = units.count - span
            let repeats = (tail + length..<units.count).allSatisfy { units[$0].key == units[$0 - length].key }
            guard repeats else { continue }
            let first = units[tail]
            let last = units[tail + length - 1]
            return DegenerationFinding(
                kind: .unitCycle(units: length, copies: copies),
                detectedAt: scanned,
                loopStart: first.start,
                keepThrough: units[tail + length].start,
                sample: String(history.text(first.start..<last.end).prefix(80))
            )
        }
        return nil
    }
}
