@testable import DegenerationGuardKit
import XCTest

final class CorpusTests: XCTestCase {
    func testStandardPolicyLeavesEveryLegitimateTextAlone() {
        for (name, text) in Corpus.legitimate {
            XCTAssertNil(DegenerationGuard.check(text).finding, name)
        }
    }

    func testStandardPolicyCatchesEveryDegenerateText() {
        for (name, text) in Corpus.degenerate {
            let finding = DegenerationGuard.check(text).finding
            XCTAssertNotNil(finding, name)
            XCTAssertLessThanOrEqual(finding?.detectedAt ?? .max, text.unicodeScalars.count, name)
        }
    }

    func testNumericalLoopNeedsDigitMasking() {
        for (name, text) in Corpus.numeric {
            XCTAssertNil(DegenerationGuard.check(text).finding, name)
            let finding = DegenerationGuard.check(text, policy: .reasoning).finding
            XCTAssertEqual(finding?.kind, .unitCycle(units: 2, copies: 4), name)
        }
    }

    /// The price of masking digits, pinned: these legitimate texts look like loops once every
    /// number reads `#`. The reasoning preset is for text nobody reads.
    func testReasoningPolicyFlagsTheseLegitimateTexts() {
        let flagged = Corpus.legitimate
            .filter { DegenerationGuard.check($0.text, policy: .reasoning).finding != nil }
            .map(\.name)
        XCTAssertEqual(flagged, ["times table", "json records", "price list", "csv rows"])
    }

    func testReasoningPolicyStillCatchesEveryDegenerateText() {
        for (name, text) in Corpus.degenerate {
            XCTAssertNotNil(DegenerationGuard.check(text, policy: .reasoning).finding, name)
        }
    }

    func testSalvagedTextIsCleanAndKeepsOneCopy() {
        let expected: [String: String] = [
            "sentence loop": "Let me convert the units first. Wait, let me reconsider the units.",
            "token flood": "The answer is the",
            "newline flood": "Here is the table:",
            "three-statement cycle": "First, check the input. The input is valid. So the error must be in the parser. "
                + "Let me check the input again.",
            "numbered loop": "Steps:\n1. Check the configuration file.",
            "code line loop": "```python\ntotal = 0\ntotal = total + 1"
        ]
        for (name, text) in Corpus.degenerate {
            guard let finding = DegenerationGuard.check(text).finding else { return XCTFail(name) }
            let salvage = DegenerationGuard.salvage(text, keeping: finding)
            XCTAssertNil(DegenerationGuard.check(salvage.text).finding, name)
            XCTAssertEqual(salvage.keptScalars + salvage.removedScalars, text.unicodeScalars.count, name)
            if let want = expected[name] { XCTAssertEqual(salvage.text, want, name) }
        }
    }

    func testEveryChunkingGivesTheWholeTextVerdict() {
        let texts = Corpus.legitimate + Corpus.degenerate + Corpus.numeric
        for (name, text) in texts {
            for policy in [DegenerationPolicy.standard, .reasoning] {
                let whole = DegenerationGuard.check(text, policy: policy)
                for size in [1, 2, 3, 5, 7, 8, 13, 16, 31, 64] {
                    XCTAssertEqual(streamed(chunks(text, size: size), policy: policy), whole, "\(name) / \(size)")
                }
            }
        }
    }

    func testIrregularSplitsGiveTheWholeTextVerdict() {
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        for (name, text) in Corpus.degenerate {
            let whole = DegenerationGuard.check(text)
            let scalars = Array(text.unicodeScalars)
            for _ in 0..<5 {
                var pieces: [String] = []
                var start = 0
                while start < scalars.count {
                    seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                    let size = Int(seed >> 59) + 1
                    var view = String.UnicodeScalarView()
                    view.append(contentsOf: scalars[start..<min(start + size, scalars.count)])
                    pieces.append(String(view))
                    start += size
                }
                XCTAssertEqual(streamed(pieces), whole, name)
            }
        }
    }
}
