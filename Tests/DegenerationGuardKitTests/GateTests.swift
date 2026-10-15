@testable import DegenerationGuardKit
import XCTest

final class GateTests: XCTestCase {
    func testGateStopsTheStreamAndReportsOnceToTheLedger() async throws {
        let ledger = DegenerationLedger()
        let gate = DegenerationGate(model: "looper", ledger: ledger)
        var decision = StreamDecision.proceed
        var sent = 0
        for piece in chunks(String(repeating: "Wait, let me reconsider the units. ", count: 20), size: 9) {
            decision = await gate.ingest(piece)
            sent += 1
            if case .stop = decision { break }
        }
        guard case let .stop(finding) = decision else { return XCTFail("never stopped") }
        let scanned = await gate.scanned
        XCTAssertEqual(scanned, sent * 9)
        let after = await gate.scalarsAfterDetection
        XCTAssertEqual(after, scanned - finding.detectedAt)
        XCTAssertLessThan(after, 9)
        _ = await gate.finish()
        _ = await gate.finish()
        let entry = await ledger.entry(for: "looper")
        XCTAssertEqual(entry.streams, 1)
        XCTAssertEqual(entry.verbatimLoops, 1)
        XCTAssertEqual(entry.scannedScalars, scanned)
        XCTAssertEqual(gate.model, "looper")
    }

    func testGateWithoutLedgerStillFinishes() async {
        let gate = DegenerationGate(model: "solo")
        let decision = await gate.ingest("A clean answer.")
        XCTAssertEqual(decision, .proceed)
        let verdict = await gate.finish()
        XCTAssertEqual(verdict, .clean(scanned: 15))
    }

    func testGateWithCustomMonitor() async {
        let ledger = DegenerationLedger()
        let gate = DegenerationGate(
            model: "custom",
            monitor: DegenerationMonitor(detectors: [MarkerDetector(atFinish: true)]),
            ledger: ledger
        )
        _ = await gate.ingest("text")
        _ = await gate.finish()
        let entry = await ledger.entry(for: "custom")
        XCTAssertEqual(entry.customLoops, 1)
    }

    func testLedgerCountsPerModelAndInTotal() async {
        let ledger = DegenerationLedger()
        let empty = await ledger.entry(for: "nobody")
        XCTAssertEqual(empty, DegenerationLedger.Entry())
        XCTAssertEqual(empty.loopRate, 0)

        let unit = DegenerationFinding(kind: .unitCycle(units: 1, copies: 4), detectedAt: 9, loopStart: 0, keepThrough: 2, sample: "")
        let verbatim = DegenerationFinding(kind: .verbatim(period: 2, copies: 4), detectedAt: 9, loopStart: 0, keepThrough: 2, sample: "")
        await ledger.record(model: "b", verdict: .degenerate(unit), scanned: 10)
        await ledger.record(model: "b", verdict: .clean(scanned: 30), scanned: 30)
        await ledger.record(model: "a", verdict: .degenerate(verbatim), scanned: 5)
        await ledger.record(model: "a", verdict: .clean(scanned: 5), scanned: 5)
        await ledger.record(model: "a", verdict: .clean(scanned: 5), scanned: 5)
        await ledger.record(model: "a", verdict: .clean(scanned: 5), scanned: 5)

        let models = await ledger.models
        XCTAssertEqual(models, ["a", "b"])
        let entryB = await ledger.entry(for: "b")
        XCTAssertEqual(entryB.unitCycles, 1)
        XCTAssertEqual(entryB.loopRate, 0.5)
        let entryA = await ledger.entry(for: "a")
        XCTAssertEqual(entryA.loopRate, 0.25)
        let total = await ledger.total
        XCTAssertEqual(total.streams, 6)
        XCTAssertEqual(total.loops, 2)
        XCTAssertEqual(total.scannedScalars, 60)
    }
}
