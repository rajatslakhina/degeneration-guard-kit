/// Two loop checks of the kind found in agent tooling today, written down exactly so the demo
/// can measure them on the same texts as DegenerationGuardKit.
enum Baseline {
    /// Five identical lines in a row, compared as written.
    static func identicalLines(_ text: String, run: Int = 5) -> Bool {
        var last: Substring?
        var count = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            count = line == last ? count + 1 : 1
            last = line
            if count >= run { return true }
        }
        return false
    }

    /// More than half of the word 4-grams in the last 200 words already appeared earlier in
    /// that window.
    static func ngramDensity(_ text: String, window: Int = 200, threshold: Double = 0.5) -> Bool {
        let words = text.split(whereSeparator: \.isWhitespace).suffix(window).map(String.init)
        guard words.count >= 8 else { return false }
        var seen = Set<[String]>()
        var repeated = 0
        for start in 0...(words.count - 4) where !seen.insert(Array(words[start..<start + 4])).inserted {
            repeated += 1
        }
        return Double(repeated) / Double(words.count - 3) > threshold
    }
}
