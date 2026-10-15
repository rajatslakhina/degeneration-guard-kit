/// The thresholds that decide when a streamed answer has degenerated into repetition.
///
/// Every threshold is about the *tail* of the stream: nothing is reported until the text written
/// so far ends in the same thing several times in a row. The defaults are deliberately slow to
/// fire. A loop that is caught after four copies instead of three still saves everything the
/// model would have written up to its output cap, while a song that ends on a repeated chorus,
/// or a table with similar rows, must never be cut.
public struct DegenerationPolicy: Sendable, Equatable {
    /// The longest block, in Unicode scalars, the verbatim detector looks for. Longer loops are
    /// left to the unit-cycle detector, which counts sentences instead of scalars.
    public let maximumPeriod: Int
    /// How many consecutive copies of a block (verbatim) or of a run of units (unit cycle)
    /// count as a loop. Never less than 2.
    public let minimumCopies: Int
    /// The fewest scalars a verbatim loop must cover before it is reported.
    public let minimumLoopScalars: Int
    /// Blocks shorter than this many scalars ("!", "the ", a newline) are held to
    /// `minimumRunScalars` instead of `minimumLoopScalars`: separators and ellipses repeat short
    /// blocks legitimately, a run of hundreds of them does not.
    public let shortPeriodLimit: Int
    /// The fewest scalars a loop of a short block must cover before it is reported.
    public let minimumRunScalars: Int
    /// The longest run of units, in sentences or lines, the unit-cycle detector looks for.
    public let maximumUnitPeriod: Int
    /// Units shorter than this many scalars after normalization are not counted: a closing
    /// brace, a table rule or "Yes." repeats in ordinary text.
    public let minimumUnitScalars: Int
    /// Replaces each run of digits with `#` before units are compared, so "check 17 x 3" and
    /// "check 17 x 4" count as the same unit. This catches the numerical loops of reasoning
    /// models, and it also makes a times table or a price list look like a loop.
    public let maskDigits: Bool

    public init(
        maximumPeriod: Int = 512,
        minimumCopies: Int = 4,
        minimumLoopScalars: Int = 120,
        shortPeriodLimit: Int = 8,
        minimumRunScalars: Int = 200,
        maximumUnitPeriod: Int = 8,
        minimumUnitScalars: Int = 12,
        maskDigits: Bool = false
    ) {
        self.maximumPeriod = max(1, maximumPeriod)
        self.minimumCopies = max(2, minimumCopies)
        self.minimumLoopScalars = max(1, minimumLoopScalars)
        self.shortPeriodLimit = max(1, shortPeriodLimit)
        self.minimumRunScalars = max(1, minimumRunScalars)
        self.maximumUnitPeriod = max(1, maximumUnitPeriod)
        self.minimumUnitScalars = max(1, minimumUnitScalars)
        self.maskDigits = maskDigits
    }

    /// For answers a person reads: digits are compared as written.
    public static let standard = DegenerationPolicy()

    /// For reasoning traces, where numerical loops are common and the person never reads the
    /// text that would be lost to a false positive. Digits are masked.
    public static let reasoning = DegenerationPolicy(maskDigits: true)

    /// The scalars a verbatim loop with this block length must cover before it is reported.
    func requiredCoverage(forPeriod period: Int) -> Int {
        period < shortPeriodLimit ? minimumRunScalars : minimumLoopScalars
    }
}
