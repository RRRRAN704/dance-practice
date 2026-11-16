//
//  BeatGrid.swift
//  DancePractice
//

import Foundation

/// A stretch of video with a steady beat. Counting starts on a "1" at `start` and runs until the
/// next segment begins, `end`, or the end of the video. All times are video seconds.
struct BeatSegment: Codable, Equatable, Identifiable {
    var id = UUID()
    /// Video time of a "1".
    var start: Double
    var bpm: Double
    /// Where counting stops; nil means it runs on until the next segment.
    var end: Double?

    /// Video seconds per beat.
    var beatInterval: Double { 60 / bpm }
}

/// Where a moment of the video falls in the count.
struct BeatPosition: Equatable {
    /// 1...8, like a dance teacher's count.
    let count: Int
    /// How far through this beat, 0..<1; drives the pulse animation.
    let phase: Double
}

/// The counted parts of one video. Studio videos have talking, pauses and restarts, so instead of one
/// beat for the whole video there are segments, and nothing is counted where no segment applies.
struct BeatGrid: Codable, Equatable {
    static let countsPerEight = 8
    /// The "1" shows this fraction of a beat early: a tapped start tends to land a little late.
    static let earlyTolerance = 0.15

    /// Sorted by `start`.
    private(set) var segments: [BeatSegment] = []

    var isEmpty: Bool { segments.isEmpty }

    /// The segment that is counting at `time`: the last one started by then, unless it has ended.
    func segment(at time: Double) -> BeatSegment? {
        guard let segment = segments.last(where: { $0.start - Self.earlyTolerance * $0.beatInterval <= time })
        else { return nil }
        if let end = segment.end, time >= end { return nil }
        return segment
    }

    func position(at time: Double) -> BeatPosition? {
        guard let segment = segment(at: time) else { return nil }
        let beats = max(0, (time - segment.start) / segment.beatInterval)
        let index = beats.rounded(.down)
        return BeatPosition(count: Int(index) % Self.countsPerEight + 1, phase: beats - index)
    }

    /// Starts counting at `segment.start`. Re-tapping near an existing segment replaces it (to fix a wrong
    /// tempo); an earlier segment simply hands over here. If the segment being taken over had an end
    /// after this point, the new one keeps that end.
    mutating func add(_ segment: BeatSegment) {
        var segment = segment
        if segment.end == nil, let current = self.segment(at: segment.start), let end = current.end {
            segment.end = end
        }
        let replaceWindow = Double(Self.countsPerEight) * segment.beatInterval
        segments.removeAll { abs($0.start - segment.start) < replaceWindow }
        segments.append(segment)
        segments.sort { $0.start < $1.start }
    }

    /// Stops the count at `time` (the music stopped). Does nothing if nothing is counting there.
    mutating func stop(at time: Double) {
        guard let current = segment(at: time),
              let index = segments.firstIndex(where: { $0.id == current.id }) else { return }
        if time <= current.start {
            segments.remove(at: index)
        } else {
            segments[index].end = time
        }
    }

    mutating func removeAll() {
        segments.removeAll()
    }
}
