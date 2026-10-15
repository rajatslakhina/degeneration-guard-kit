/// Watches one streamed answer and reports the first point at which it has degenerated.
///
/// Feed it each fragment as it arrives. The verdict after any fragment is exactly the verdict
/// the whole text so far would get, because every detector is fed one scalar at a time: the
/// offset at which a loop is detected is the same whether the text came in one piece, in
/// network-sized chunks or one scalar at a time.
///
/// A finding is final. Text received after it is counted (`scalarsAfterDetection`, which is
/// what a caller that keeps reading in audit mode would have paid for) but is not examined.
public struct DegenerationMonitor: Sendable {
    private var detectors: [any LoopDetector]
    public private(set) var history = ScalarHistory()
    public private(set) var finding: DegenerationFinding?
    private var finished = false

    /// A monitor with this package's two detectors, verbatim first.
    public init(policy: DegenerationPolicy = .standard) {
        self.init(detectors: [VerbatimLoopDetector(policy: policy), UnitCycleDetector(policy: policy)])
    }

    /// A monitor with your own detectors, asked in order for every scalar.
    public init(detectors: [any LoopDetector]) {
        self.detectors = detectors
    }

    public var scanned: Int { history.count }

    /// Scalars received after the loop was detected; zero while the stream is clean.
    public var scalarsAfterDetection: Int {
        finding.map { scanned - $0.detectedAt } ?? 0
    }

    public var verdict: DegenerationVerdict {
        finding.map(DegenerationVerdict.degenerate) ?? .clean(scanned: scanned)
    }

    @discardableResult
    public mutating func ingest(_ chunk: String) -> DegenerationVerdict {
        for scalar in chunk.unicodeScalars {
            history.append(scalar)
            guard finding == nil, !finished else { continue }
            finding = observe(scalar)
        }
        return verdict
    }

    /// Ends the stream: a detector holding an unfinished sentence gets to judge it. Calling it
    /// again returns the same verdict.
    @discardableResult
    public mutating func finish() -> DegenerationVerdict {
        guard !finished else { return verdict }
        finished = true
        guard finding == nil else { return verdict }
        let snapshot = history
        for index in detectors.indices {
            if let found = detectors[index].finish(in: snapshot) {
                finding = found
                break
            }
        }
        return verdict
    }

    private mutating func observe(_ scalar: Unicode.Scalar) -> DegenerationFinding? {
        let snapshot = history
        for index in detectors.indices {
            if let found = detectors[index].observe(scalar, in: snapshot) { return found }
        }
        return nil
    }
}
