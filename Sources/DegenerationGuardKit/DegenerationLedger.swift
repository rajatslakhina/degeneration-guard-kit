/// Counts finished streams per model, so an app can tell which model loops and how often.
public actor DegenerationLedger {
    public struct Entry: Sendable, Equatable {
        public internal(set) var streams = 0
        public internal(set) var verbatimLoops = 0
        public internal(set) var unitCycles = 0
        public internal(set) var customLoops = 0
        /// Scalars received across all streams, up to where each one was stopped.
        public internal(set) var scannedScalars = 0

        public init() {}

        public var loops: Int { verbatimLoops + unitCycles + customLoops }

        /// Loops per stream; zero before the first stream.
        public var loopRate: Double {
            streams == 0 ? 0 : Double(loops) / Double(streams)
        }

        mutating func add(_ verdict: DegenerationVerdict, scanned: Int) {
            streams += 1
            scannedScalars += scanned
            switch verdict.finding?.kind {
            case .verbatim?: verbatimLoops += 1
            case .unitCycle?: unitCycles += 1
            case .custom?: customLoops += 1
            case nil: break
            }
        }

        mutating func merge(_ other: Entry) {
            streams += other.streams
            verbatimLoops += other.verbatimLoops
            unitCycles += other.unitCycles
            customLoops += other.customLoops
            scannedScalars += other.scannedScalars
        }
    }

    private var entries: [String: Entry] = [:]

    public init() {}

    public func record(model: String, verdict: DegenerationVerdict, scanned: Int) {
        entries[model, default: Entry()].add(verdict, scanned: scanned)
    }

    public func entry(for model: String) -> Entry {
        entries[model] ?? Entry()
    }

    /// Every model with at least one stream, in name order.
    public var models: [String] { entries.keys.sorted() }

    /// All models together.
    public var total: Entry {
        entries.values.reduce(into: Entry()) { $0.merge($1) }
    }
}
