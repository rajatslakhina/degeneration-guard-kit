/// Shows newlines and truncates, so one finding fits on one line of output.
func visible(_ text: String, limit: Int = 44) -> String {
    let escaped = text.unicodeScalars.map { $0 == "\n" ? "\\n" : String($0) }.joined()
    return escaped.count > limit ? String(escaped.prefix(limit - 3)) + "..." : escaped
}

func pad(_ text: String, _ width: Int) -> String {
    text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
}

func heading(_ number: Int, _ title: String) {
    print("")
    print("[\(number)] \(title)")
}
