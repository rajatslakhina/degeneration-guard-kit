/// What kind of repetition a detector found.
public enum LoopKind: Sendable, Equatable, CustomStringConvertible {
    /// The stream ends in `copies` consecutive copies of the same `period`-scalar block.
    case verbatim(period: Int, copies: Int)
    /// The stream ends in `copies` consecutive copies of the same run of `units` sentences or
    /// lines, compared after normalization.
    case unitCycle(units: Int, copies: Int)
    /// Reported by a detector outside this package.
    case custom(String)

    public var description: String {
        switch self {
        case let .verbatim(period, copies):
            return "verbatim: a \(period)-scalar block written \(copies) times in a row"
        case let .unitCycle(units, copies):
            let noun = units == 1 ? "sentence" : "run of \(units) sentences"
            return "unit cycle: the same \(noun) written \(copies) times in a row"
        case let .custom(name):
            return "custom: \(name)"
        }
    }
}

/// One detected loop, located by scalar offsets from the start of the stream.
public struct DegenerationFinding: Sendable, Equatable {
    public let kind: LoopKind
    /// How many scalars had been received when the loop was detected. Everything after this
    /// point is text a caller that stops the stream never pays for.
    public let detectedAt: Int
    /// Where the first copy of the repeated block starts.
    public let loopStart: Int
    /// Where the second copy starts. Keeping the text before this offset keeps one copy and
    /// drops the repetition.
    public let keepThrough: Int
    /// The repeated block as written, at most 80 scalars.
    public let sample: String

    public init(kind: LoopKind, detectedAt: Int, loopStart: Int, keepThrough: Int, sample: String) {
        self.kind = kind
        self.detectedAt = detectedAt
        self.loopStart = loopStart
        self.keepThrough = keepThrough
        self.sample = sample
    }
}

/// The state of a stream: clean so far, or degenerate from a known point.
public enum DegenerationVerdict: Sendable, Equatable {
    case clean(scanned: Int)
    case degenerate(DegenerationFinding)

    public var finding: DegenerationFinding? {
        if case let .degenerate(finding) = self { return finding }
        return nil
    }
}

/// An answer cut back to the text before its repetition began.
public struct Salvage: Sendable, Equatable {
    /// The text to show: everything before the second copy, without trailing whitespace.
    public let text: String
    public let keptScalars: Int
    /// Scalars of the received text that were dropped.
    public let removedScalars: Int
}
