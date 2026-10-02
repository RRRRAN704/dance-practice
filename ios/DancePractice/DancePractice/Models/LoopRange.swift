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
        guard clampedEnd - clampedStart >= Self.minimumLength else { return nil }
        self.start = clampedStart
        self.end = clampedEnd
    }

    var length: Double { end - start }

    func contains(_ time: Double) -> Bool {
        time >= start && time <= end
    }
}
