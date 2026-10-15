@testable import DegenerationGuardKit
import XCTest

/// The verbatim detector written the slow, obvious way: one counter per block length, every
/// counter updated for every scalar. The package's detector skips block lengths whose run
/// cannot grow; this pins that it reports exactly what the obvious version reports.
struct ReferenceVerbatim: LoopDetector {
    let policy: DegenerationPolicy
    var runs: [Int]

    init(policy: DegenerationPolicy) {
        self.policy = policy
        runs = Array(repeating: 0, count: policy.maximumPeriod + 1)
    }

    mutating func observe(_ scalar: Unicode.Scalar, in history: ScalarHistory) -> DegenerationFinding? {
        let index = history.count - 1
        let limit = min(policy.maximumPeriod, index)
        guard limit > 0 else { return nil }
        var widest = 0
        for period in 1...limit {
            runs[period] = history[index - period] == scalar ? runs[period] + 1 : 0
        }
        for period in 1...limit where runs[period] > 0 {
            let covered = runs[period] + period
            guard covered > widest else { continue }
            widest = covered
            guard covered / period >= policy.minimumCopies,
                  covered >= policy.requiredCoverage(forPeriod: period) else { continue }
            let start = history.count - covered
            let cut = VerbatimLoopDetector.alignedCut(start: start, period: period, history: history)
            return DegenerationFinding(
                kind: .verbatim(period: period, copies: covered / period),
                detectedAt: history.count,
                loopStart: start,
                keepThrough: cut,
                sample: history.text(cut - period..<cut - period + min(period, 80))
            )
        }
        return nil
    }

    mutating func finish(in history: ScalarHistory) -> DegenerationFinding? { nil }
}

final class ReferenceTests: XCTestCase {
    private func both(_ text: String, policy: DegenerationPolicy) -> (DegenerationVerdict, DegenerationVerdict) {
        var fast = DegenerationMonitor(detectors: [VerbatimLoopDetector(policy: policy)])
        var slow = DegenerationMonitor(detectors: [ReferenceVerbatim(policy: policy)])
        fast.ingest(text)
        slow.ingest(text)
        return (fast.finish(), slow.finish())
    }

    func testMatchesTheObviousDetectorOnTheCorpus() {
        for (name, text) in Corpus.legitimate + Corpus.degenerate + Corpus.numeric {
            let (fast, slow) = both(text, policy: .standard)
            XCTAssertEqual(fast, slow, name)
        }
    }

    /// Random texts over two to four letters repeat constantly, at every block length, and
    /// small thresholds make loops fire at short and long periods alike.
    func testMatchesTheObviousDetectorOnRandomTexts() {
        let policy = DegenerationPolicy(
            maximumPeriod: 24,
            minimumCopies: 2,
            minimumLoopScalars: 12,
            shortPeriodLimit: 3,
            minimumRunScalars: 9
        )
        var seed: UInt64 = 42
        var fired = 0
        for trial in 0..<600 {
            let alphabet = Array("ab c".unicodeScalars.prefix(2 + trial % 3))
            var view = String.UnicodeScalarView()
            for _ in 0..<(40 + trial % 160) {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                view.append(alphabet[Int(seed >> 33) % alphabet.count])
            }
            let (fast, slow) = both(String(view), policy: policy)
            XCTAssertEqual(fast, slow, "trial \(trial)")
            if fast.finding != nil { fired += 1 }
        }
        // 220 of the 600 fire with this seed, so both outcomes are compared many times.
        XCTAssertEqual(fired, 220)
    }
}
