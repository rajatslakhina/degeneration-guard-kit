import DegenerationGuardKit

/// A reasoning model that falls into a loop and would keep going until its output cap.
func scenarioBill() async {
    heading(1, "A looping answer, streamed through a DegenerationGate")
    let cap = 16_384
    let opening = "To convert 3.2 km/h to m/s, divide by 3.6. "
    let loop = "Wait, let me reconsider the units. "
    var answer = opening
    while answer.unicodeScalars.count < cap { answer += loop }
    let gate = DegenerationGate(model: "demo-reasoner")
    var received = ""
    var chunkCount = 0
    for chunk in chunked(answer, size: 16) {
        received += chunk
        chunkCount += 1
        if case .stop = await gate.ingest(chunk) { break }
    }
    let verdict = await gate.finish()
    guard let finding = verdict.finding else { return print("  no loop found") }
    let scanned = await gate.scanned
    let salvage = DegenerationGuard.salvage(received, keeping: finding)
    print("  output cap (scalars):      \(cap)")
    print("  found:                     \(finding.kind)")
    print("  detected at scalar:        \(finding.detectedAt) (chunk \(chunkCount) of 16 scalars)")
    print("  read before stopping:      \(scanned)")
    print("  never generated:           \(answer.unicodeScalars.count - scanned) of \(answer.unicodeScalars.count)")
    print("  kept for the user:         \"\(salvage.text)\"")
}

func scenarioKinds() {
    heading(2, "Nine ways a model loops (policy .standard)")
    print("  " + pad("text", 22) + pad("kind", 17) + pad("at/total", 11) + "kept tail")
    for (name, text) in Corpus.degenerate {
        guard let finding = DegenerationGuard.check(text).finding else {
            print("  " + pad(name, 22) + "missed")
            continue
        }
        let kept = DegenerationGuard.salvage(text, keeping: finding).text
        let kind: String
        switch finding.kind {
        case let .verbatim(period, _): kind = "verbatim p=\(period)"
        case let .unitCycle(units, _): kind = "units m=\(units)"
        case .custom: kind = "custom"
        }
        let span = "\(finding.detectedAt)/\(text.unicodeScalars.count)"
        let tail = "..." + visible(String(kept.suffix(34)), limit: 40)
        print("  " + pad(name, 22) + pad(kind, 17) + pad(span, 11) + tail)
    }
}

func scenarioLegitimate() {
    heading(3, "Twelve answers that repeat on purpose")
    print("  " + pad("text", 34) + pad(".standard", 11) + ".reasoning (digits masked)")
    for (name, text) in Corpus.legitimate {
        let standard = DegenerationGuard.check(text).finding == nil ? "clean" : "CUT"
        let reasoning = DegenerationGuard.check(text, policy: .reasoning).finding
        let detail = reasoning.map { "CUT at \($0.detectedAt)/\(text.unicodeScalars.count)" } ?? "clean"
        print("  " + pad(name, 34) + pad(standard, 11) + detail)
    }
}

func scenarioBaselines() {
    heading(4, "Against two common loop checks, on the same 21 texts")
    let rows: [(String, (String) -> Bool)] = [
        ("five identical lines", { Baseline.identicalLines($0) }),
        ("4-gram density > 0.5", { Baseline.ngramDensity($0) }),
        ("DegenerationGuardKit", { DegenerationGuard.check($0).finding != nil })
    ]
    print("  " + pad("check", 24) + pad("loops caught", 14) + "legitimate texts cut")
    for (name, flags) in rows {
        let caught = Corpus.degenerate.filter { flags($0.text) }.count
        let falsePositives = Corpus.legitimate.filter { flags($0.text) }.map(\.name)
        let listed = falsePositives.isEmpty ? "" : " (" + falsePositives.joined(separator: ", ") + ")"
        print("  " + pad(name, 24) + pad("\(caught) of \(Corpus.degenerate.count)", 14)
            + "\(falsePositives.count) of \(Corpus.legitimate.count)" + listed)
        let missed = Corpus.degenerate.filter { !flags($0.text) }.map(\.name)
        if !missed.isEmpty { print("    missed: " + missed.joined(separator: ", ")) }
    }
}
