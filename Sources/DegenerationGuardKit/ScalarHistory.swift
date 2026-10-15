/// Everything a monitor has received, as Unicode scalars, so detectors can look back by offset.
///
/// Offsets everywhere in this package count Unicode scalars from the start of the stream. A
/// scalar never changes when a chunk boundary moves, which is what makes every result here the
/// same however the stream was split.
public struct ScalarHistory: Sendable, Equatable {
    public private(set) var scalars: [Unicode.Scalar] = []

    public init() {}

    public var count: Int { scalars.count }

    public subscript(offset: Int) -> Unicode.Scalar { scalars[offset] }

    /// The text between two offsets, clamped to what has been received.
    public func text(_ range: Range<Int>) -> String {
        let lower = min(max(0, range.lowerBound), count)
        let upper = min(max(lower, range.upperBound), count)
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars[lower..<upper])
        return String(view)
    }

    mutating func append(_ scalar: Unicode.Scalar) {
        scalars.append(scalar)
    }
}
