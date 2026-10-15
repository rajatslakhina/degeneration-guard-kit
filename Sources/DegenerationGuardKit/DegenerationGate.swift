/// What a streaming caller should do after a fragment.
public enum StreamDecision: Sendable, Equatable {
    /// Keep reading.
    case proceed
    /// Stop reading: every further token is part of the loop, and is billed.
    case stop(DegenerationFinding)
}

/// A monitor behind an actor, for a stream read on one task and inspected from another, which
/// reports each finished stream to a shared ledger once.
public actor DegenerationGate {
    public nonisolated let model: String
    private var monitor: DegenerationMonitor
    private let ledger: DegenerationLedger?
    private var recorded = false

    public init(model: String, policy: DegenerationPolicy = .standard, ledger: DegenerationLedger? = nil) {
        self.init(model: model, monitor: DegenerationMonitor(policy: policy), ledger: ledger)
    }

    public init(model: String, monitor: DegenerationMonitor, ledger: DegenerationLedger? = nil) {
        self.model = model
        self.monitor = monitor
        self.ledger = ledger
    }

    public var scanned: Int { monitor.scanned }
    public var scalarsAfterDetection: Int { monitor.scalarsAfterDetection }

    public func ingest(_ chunk: String) -> StreamDecision {
        monitor.ingest(chunk).finding.map(StreamDecision.stop) ?? .proceed
    }

    /// Ends the stream and reports it to the ledger, once, however often it is called.
    public func finish() async -> DegenerationVerdict {
        let verdict = monitor.finish()
        if !recorded, let ledger {
            recorded = true
            await ledger.record(model: model, verdict: verdict, scanned: monitor.scanned)
        }
        return verdict
    }
}
