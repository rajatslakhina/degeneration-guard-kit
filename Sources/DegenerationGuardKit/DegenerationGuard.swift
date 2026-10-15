/// Whole-text entry points: check an answer that has already arrived, and cut a degenerate
/// answer back to the text before its repetition.
public enum DegenerationGuard {
    /// The verdict a monitor reaches on `text` once the stream has ended.
    public static func check(_ text: String, policy: DegenerationPolicy = .standard) -> DegenerationVerdict {
        var monitor = DegenerationMonitor(policy: policy)
        monitor.ingest(text)
        return monitor.finish()
    }

    /// Keeps the text before `finding.keepThrough` (one copy of the repeated block), without
    /// trailing whitespace. The cut is made on Unicode scalars, the unit the finding counts in.
    public static func salvage(_ text: String, keeping finding: DegenerationFinding) -> Salvage {
        let scalars = Array(text.unicodeScalars)
        var end = min(max(0, finding.keepThrough), scalars.count)
        while end > 0, scalars[end - 1].properties.isWhitespace { end -= 1 }
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars[0..<end])
        return Salvage(text: String(view), keptScalars: end, removedScalars: scalars.count - end)
    }
}
