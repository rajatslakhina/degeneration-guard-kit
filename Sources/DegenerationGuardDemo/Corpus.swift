/// Texts used across the tests. Legitimate texts repeat on purpose; degenerate texts are
/// written the way looping models write them.
enum Corpus {
    static func times(_ count: Int, _ text: String) -> String {
        String(repeating: text, count: count)
    }

    static let legitimate: [(name: String, text: String)] = [
        ("times table", (1...12).map { "7 times \($0) equals \(7 * $0)." }.joined(separator: "\n")),
        ("poem with refrain", """
        The tide comes in across the stones,
        And still I wait for you.
        The gulls cry out in tired tones,
        And still I wait for you.
        The lamps are lit along the quay,
        And still I wait for you.
        The night is long and grey for me,
        And still I wait for you.
        """),
        ("song ending on a doubled chorus", song),
        ("markdown table", """
        | Region | Q1 | Q2 | Q3 | Q4 |
        |--------|----|----|----|----|
        | North  | 12 | 14 | 14 | 15 |
        | South  | 12 | 14 | 14 | 15 |
        | East   | 12 | 14 | 14 | 15 |
        | West   | 12 | 14 | 14 | 15 |
        | Total  | 48 | 56 | 56 | 60 |
        """),
        ("swift switch", """
        ```swift
        switch direction {
        case .north: return .south
        case .south: return .north
        case .east: return .west
        case .west: return .east
        }
        ```
        """),
        ("empty checklist", "Packing list:\n" + times(12, "- [ ] \n") + "Fill in the items above."),
        ("separator rule", "Results\n" + String(repeating: "=", count: 72) + "\nAll 12 checks passed."),
        ("json records", """
        [
          {"id": 1, "status": "active", "region": "north"},
          {"id": 2, "status": "active", "region": "north"},
          {"id": 3, "status": "active", "region": "north"},
          {"id": 4, "status": "active", "region": "north"},
          {"id": 5, "status": "active", "region": "north"}
        ]
        """),
        ("recipe steps", """
        1. Preheat the oven to 200C.
        2. Stir the flour into the butter.
        3. Stir in the milk a little at a time.
        4. Bake for 25 minutes, then check it.
        5. Bake for 5 more minutes if it is pale.
        """),
        ("price list", (1...8).map { "Item \($0) costs $\($0 * 3)." }.joined(separator: "\n")),
        ("ellipsis and emphasis", "Well... that is the answer!!! Mostly. " + String(repeating: ".", count: 40)),
        ("csv rows", "date,city,status\n" + (1...9).map { "2026-10-0\($0),Lisbon,ok" }.joined(separator: "\n"))
    ]

    static let song = """
    Verse one: the city sleeps beneath the rain,
    and I keep walking down the same old lane.
    Chorus:
    Rise again, rise again tonight,
    rise again, rise again tonight,
    we will hold the morning light.
    Verse two: the windows glow and fade away,
    I count the hours to another day.
    Chorus:
    Rise again, rise again tonight,
    rise again, rise again tonight,
    we will hold the morning light.
    Rise again, rise again tonight,
    rise again, rise again tonight,
    we will hold the morning light.
    """

    static let degenerate: [(name: String, text: String)] = [
        ("sentence loop", "Let me convert the units first. " + times(12, "Wait, let me reconsider the units. ")),
        ("token flood", "The answer is" + times(120, " the")),
        ("newline flood", "Here is the table:" + String(repeating: "\n", count: 400)),
        ("three-statement cycle", "First, check the input. " + times(6, cycle)),
        ("numbered loop", "Steps:\n" + (1...10).map { "\($0). Check the configuration file." }.joined(separator: "\n")),
        ("spacing varies", "Answer: " + (0..<10).map(spaced).joined()),
        ("code line loop", "```python\ntotal = 0\n" + times(20, "total = total + 1\n")),
        ("cjk loop", cjkIntro + times(10, cjkLoop)),
        ("long paragraph loop", "Summary. " + times(4, paragraph + " "))
    ]

    static let cycle = "The input is valid. So the error must be in the parser. Let me check the input again. "

    static func spaced(_ index: Int) -> String {
        index.isMultiple(of: 2) ? "Hmm,  that is not right. " : "Hmm, that is  not right.\n"
    }

    /// "Let me reconsider this problem." then "I need to check the result again." in Chinese.
    static let cjkIntro = "\u{8BA9}\u{6211}\u{4EEC}\u{91CD}\u{65B0}\u{8003}\u{8651}"
        + "\u{4E00}\u{4E0B}\u{8FD9}\u{4E2A}\u{95EE}\u{9898}\u{3002}"
    static let cjkLoop = "\u{6211}\u{9700}\u{8981}\u{518D}\u{68C0}\u{67E5}\u{4E00}"
        + "\u{904D}\u{8BA1}\u{7B97}\u{7ED3}\u{679C}\u{3002}"

    static let paragraph = (1...7)
        .map { "Point \($0) restates the finding about cache invalidation in a slightly longer sentence than usual." }
        .joined(separator: " ")

    /// Loops that only digit masking catches.
    static let numeric: [(name: String, text: String)] = [
        ("numerical loop", "Find a factor. " + (3...14).map(numericStep).joined(separator: " "))
    ]

    static func numericStep(_ factor: Int) -> String {
        "Let me check 17 times \(factor) equals \(17 * factor). That is not it."
    }
}
