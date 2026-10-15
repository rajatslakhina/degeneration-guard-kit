/// One way of recognising repetition in a stream, fed one scalar at a time.
///
/// A detector sees each scalar after it has been appended to the history, and once more at the
/// end of the stream. It returns a finding the first time it is sure; the monitor stops asking
/// it after that. Feeding scalars one at a time is what makes a detector's answer independent of
/// how the stream was chunked: the same scalar arrives at the same offset however the network
/// split the text.
public protocol LoopDetector: Sendable {
    /// Called once per scalar, after `scalar` has been appended to `history`.
    mutating func observe(_ scalar: Unicode.Scalar, in history: ScalarHistory) -> DegenerationFinding?
    /// Called once when the stream ends, for detectors that hold an unfinished unit.
    mutating func finish(in history: ScalarHistory) -> DegenerationFinding?
}
