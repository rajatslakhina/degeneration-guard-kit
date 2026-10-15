import DegenerationGuardKit

func scenarioNumeric() {
    heading(5, "A numerical loop: the numbers change, the reasoning does not")
    let text = Corpus.numeric[0].text
    print("  text: \"\(visible(text, limit: 96))\"")
    for (name, policy) in [("standard", DegenerationPolicy.standard), ("reasoning", .reasoning)] {
        guard let finding = DegenerationGuard.check(text, policy: policy).finding else {
            print("  .\(pad(name, 10)) clean")
            continue
        }
        let kept = DegenerationGuard.salvage(text, keeping: finding).text
        print("  .\(pad(name, 10)) \(finding.kind) at \(finding.detectedAt); keeps \"\(visible(kept, limit: 70))\"")
    }
}

func scenarioChunking() {
    heading(6, "The chunking never changes the answer")
    var identical = 0
    var offsets = Set<Int>()
    let texts = Corpus.degenerate + Corpus.legitimate
    for (_, text) in texts {
        let whole = DegenerationGuard.check(text)
        for size in 1...64 {
            var monitor = DegenerationMonitor()
            for chunk in chunked(text, size: size) { monitor.ingest(chunk) }
            let verdict = monitor.finish()
            if verdict == whole { identical += 1 }
            if text == Corpus.degenerate[0].text, let finding = verdict.finding { offsets.insert(finding.detectedAt) }
        }
    }
    let total = texts.count * 64
    print("  \(texts.count) texts x chunk sizes 1...64: \(identical) of \(total) verdicts equal the whole-text verdict")
    let found = offsets.sorted().map(String.init).joined(separator: ", ")
    print("  sentence loop detected at scalar \(found) for every size")
}

func scenarioLedger() async {
    heading(7, "Which model loops: a DegenerationLedger over 30 scripted answers")
    let ledger = DegenerationLedger()
    let scripts: [(String, [String])] = [
        ("model-a", Array(repeating: Corpus.legitimate[8].text, count: 9) + [Corpus.degenerate[0].text]),
        ("model-b", Array(repeating: Corpus.legitimate[1].text, count: 6) + Corpus.degenerate.suffix(4).map(\.text)),
        ("model-c", Corpus.legitimate.prefix(10).map(\.text))
    ]
    for (model, answers) in scripts {
        for answer in answers {
            let gate = DegenerationGate(model: model, ledger: ledger)
            for chunk in chunked(answer, size: 24) where await gate.ingest(chunk) != .proceed { break }
            _ = await gate.finish()
        }
    }
    for model in await ledger.models {
        let entry = await ledger.entry(for: model)
        let rate = String(Int((entry.loopRate * 100).rounded())) + "%"
        print("  \(model): \(entry.loops) of \(entry.streams) answers looped (\(rate)); "
            + "verbatim \(entry.verbatimLoops), unit cycles \(entry.unitCycles), \(entry.scannedScalars) scalars read")
    }
}

func chunked(_ text: String, size: Int) -> [String] {
    let scalars = Array(text.unicodeScalars)
    return stride(from: 0, to: scalars.count, by: size).map { start in
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars[start..<min(start + size, scalars.count)])
        return String(view)
    }
}
