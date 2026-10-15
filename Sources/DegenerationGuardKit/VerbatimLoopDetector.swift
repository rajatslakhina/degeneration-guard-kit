/// Finds a stream that ends in the same block of scalars written several times in a row.
///
/// For every block length `p` up to `maximumPeriod` it tracks one run: how many of the most
/// recent scalars equal the scalar `p` places before them. When that run is `r`, the last
/// `r + p` scalars are copies of one `p`-scalar block. A run only grows at block lengths where
/// the new scalar matches an earlier one, so each scalar visits only the earlier occurrences of
/// itself within `maximumPeriod` (a chain kept per scalar value), and every other run is
/// treated as broken. The result depends only on the scalars, never on where a chunk ended.
///
/// A block that is itself repetitive ("abab") is reported at its smallest length ("ab"), and is
/// held to that length's threshold: a run of "-" is not excused as a run of "----".
public struct VerbatimLoopDetector: LoopDetector {
    public let policy: DegenerationPolicy
    /// Offset of the previous occurrence of the scalar at each offset, or -1.
    private var previous: [Int] = []
    private var lastSeen: [Unicode.Scalar: Int] = [:]
    /// For each block length, where its current run started and the offset it last grew at.
    private var runStart: [Int]
    private var runLast: [Int]

    public init(policy: DegenerationPolicy = .standard) {
        self.policy = policy
        runStart = Array(repeating: 0, count: policy.maximumPeriod + 1)
        runLast = Array(repeating: -2, count: policy.maximumPeriod + 1)
    }

    public mutating func observe(_ scalar: Unicode.Scalar, in history: ScalarHistory) -> DegenerationFinding? {
        let index = history.count - 1
        previous.append(lastSeen[scalar] ?? -1)
        lastSeen[scalar] = index
        var periods: [Int] = []
        var earlier = previous[index]
        while earlier >= 0, index - earlier <= policy.maximumPeriod {
            let period = index - earlier
            if runLast[period] != index - 1 { runStart[period] = index }
            runLast[period] = index
            periods.append(period)
            earlier = previous[earlier]
        }
        return match(periods, at: index, history: history)
    }

    public mutating func finish(in history: ScalarHistory) -> DegenerationFinding? {
        nil
    }

    /// The smallest block length whose run qualifies, skipping lengths whose run a smaller block
    /// already explains. `periods` arrive in ascending order.
    private func match(_ periods: [Int], at index: Int, history: ScalarHistory) -> DegenerationFinding? {
        var widest = 0
        for period in periods {
            let covered = index - runStart[period] + 1 + period
            guard covered > widest else { continue }
            widest = covered
            let copies = covered / period
            guard copies >= policy.minimumCopies,
                  covered >= policy.requiredCoverage(forPeriod: period) else { continue }
            let start = index + 1 - covered
            let cut = Self.alignedCut(start: start, period: period, history: history)
            return DegenerationFinding(
                kind: .verbatim(period: period, copies: copies),
                detectedAt: index + 1,
                loopStart: start,
                keepThrough: cut,
                sample: history.text(cut - period..<cut - period + min(period, 80))
            )
        }
        return nil
    }

    /// Where to cut so that one whole copy is kept and the cut falls between sentences, or at
    /// least between words.
    ///
    /// The repeated region can start partway into a sentence: in "units first. Wait, ... the
    /// units. Wait, ..." the block the counters find starts at the ". " both sentences end with.
    /// Every cut in `[start + period, start + 2 * period)` keeps exactly one copy, because the
    /// region is periodic from `start`, so the first cut that follows a sentence end is chosen,
    /// then the first that follows whitespace, then the plain one.
    static func alignedCut(start: Int, period: Int, history: ScalarHistory) -> Int {
        let first = start + period
        var wordBoundary: Int?
        for cut in first..<first + period where history[cut - 1].properties.isWhitespace {
            if cut >= 2, UnitCycleDetector.terminators.contains(history[cut - 2]) { return cut }
            wordBoundary = wordBoundary ?? cut
        }
        return wordBoundary ?? first
    }
}
