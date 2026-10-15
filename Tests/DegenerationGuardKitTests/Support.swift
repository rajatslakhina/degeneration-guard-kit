@testable import DegenerationGuardKit
import XCTest

/// Splits `text` into chunks of `size` Unicode scalars.
func chunks(_ text: String, size: Int) -> [String] {
    let scalars = Array(text.unicodeScalars)
    return stride(from: 0, to: scalars.count, by: size).map { start in
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars[start..<min(start + size, scalars.count)])
        return String(view)
    }
}

/// The verdict of a monitor fed `pieces` one by one, then finished.
func streamed(_ pieces: [String], policy: DegenerationPolicy = .standard) -> DegenerationVerdict {
    var monitor = DegenerationMonitor(policy: policy)
    for piece in pieces { monitor.ingest(piece) }
    return monitor.finish()
}

/// A detector that reports a custom loop when it sees `trigger`, or at the end of the stream.
struct MarkerDetector: LoopDetector {
    var trigger: Unicode.Scalar = "~"
    var atFinish = false

    mutating func observe(_ scalar: Unicode.Scalar, in history: ScalarHistory) -> DegenerationFinding? {
        guard scalar == trigger else { return nil }
        return finding(history)
    }

    mutating func finish(in history: ScalarHistory) -> DegenerationFinding? {
        atFinish ? finding(history) : nil
    }

    private func finding(_ history: ScalarHistory) -> DegenerationFinding {
        DegenerationFinding(
            kind: .custom("marker"),
            detectedAt: history.count,
            loopStart: 0,
            keepThrough: history.count - 1,
            sample: "~"
        )
    }
}
