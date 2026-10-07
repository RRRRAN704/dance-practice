//
//  LoopRange.swift
//  DancePractice
//

import Foundation

/// A validated A-B loop segment, in seconds.
struct LoopRange: Equatable {
    /// Shortest segment we allow, so the player doesn't thrash seeking.
    static let minimumLength: Double = 0.2

    let start: Double
    let end: Double

    /// Returns nil when the segment is shorter than `minimumLength` after clamping to `0...duration`.
    init?(start: Double, end: Double, duration: Double) {
        let clampedStart = max(0, start)
        let clampedEnd = min(end, duration)
        // Small tolerance so a range built as `start + minimumLength` isn't rejected by rounding.
        guard clampedEnd - clampedStart >= Self.minimumLength - 1e-9 else { return nil }
        self.start = clampedStart
        self.end = clampedEnd
    }

    var length: Double { end - start }

    func contains(_ time: Double) -> Bool {
        time >= start && time <= end
    }

    /// Moves A, keeping it at least `minimumLength` before B.
    func withStart(_ newStart: Double, duration: Double) -> LoopRange {
        LoopRange(start: min(newStart, end - Self.minimumLength), end: end, duration: duration) ?? self
    }

    /// Moves B, keeping it at least `minimumLength` after A.
    func withEnd(_ newEnd: Double, duration: Double) -> LoopRange {
        LoopRange(start: start, end: max(newEnd, start + Self.minimumLength), duration: duration) ?? self
    }
}

enum LoopHandle {
    case a, b
}
