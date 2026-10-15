/// Turns a sentence or line into the key two units are compared by.
///
/// Case, runs of whitespace and a leading list marker ("- ", "* ", "3. ", "12) ", "## ") are
/// not part of the key, so "1. Check the units." and "2. Check the units." are the same unit.
/// Digits are kept unless the policy masks them. A unit with no letter or digit (a table rule,
/// a fence, a lone brace) or shorter than the policy's minimum has no key and is not counted.
enum UnitKey {
    static func make(_ text: String, policy: DegenerationPolicy) -> String? {
        let scalars = Array(text.lowercased().unicodeScalars)
        var key = String.UnicodeScalarView()
        var pendingSpace = false
        var inDigits = false
        var meaningful = false
        for scalar in scalars[markerEnd(scalars)...] {
            if scalar.properties.isWhitespace {
                pendingSpace = !key.isEmpty
                inDigits = false
                continue
            }
            if pendingSpace { key.append(" ") }
            pendingSpace = false
            meaningful = meaningful || scalar.properties.isAlphabetic || isDigit(scalar)
            if policy.maskDigits, isDigit(scalar) {
                if !inDigits { key.append("#") }
                inDigits = true
                continue
            }
            inDigits = false
            key.append(scalar)
        }
        guard meaningful, key.count >= policy.minimumUnitScalars else { return nil }
        return String(key)
    }

    /// The offset just past leading whitespace and one list marker, or past leading whitespace
    /// alone when there is no marker.
    static func markerEnd(_ scalars: [Unicode.Scalar]) -> Int {
        var index = 0
        while index < scalars.count, scalars[index].properties.isWhitespace { index += 1 }
        let start = index
        while index < scalars.count, "-*+>#".unicodeScalars.contains(scalars[index]) { index += 1 }
        if index == start {
            while index < scalars.count, index - start < 3, isDigit(scalars[index]) { index += 1 }
            guard index > start, index < scalars.count, ".)".unicodeScalars.contains(scalars[index]) else {
                return start
            }
            index += 1
        }
        guard index < scalars.count, scalars[index].properties.isWhitespace else { return start }
        return index
    }

    static func isDigit(_ scalar: Unicode.Scalar) -> Bool {
        ("0"..."9").contains(scalar)
    }
}
