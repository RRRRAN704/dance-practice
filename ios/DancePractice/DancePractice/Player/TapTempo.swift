//
//  TapTempo.swift
//  DancePractice
//

import Foundation

/// Works out a beat from taps along with the music.
///
/// Taps are recorded in VIDEO time, not wall-clock time, so the result is right at any playback speed:
/// at 0.5x the taps come twice as far apart in real life, but the same distance apart in the video.
struct TapTempo {
    static let minimumTaps = 4
    /// Two eights: tapping finishes on its own after this many. More taps over a longer stretch give a
    /// steadier tempo, so the user can keep going past one eight before pressing Done.
    static let maximumTaps = 16
    static let bpmRange: ClosedRange<Double> = 40...240
    /// Closer than this is a finger bounce, not a beat (240 BPM is 0.25 s per beat).
    static let minimumGap = 0.12
    /// A longer pause than one beat at the slowest tempo starts over.
    static let maximumGap = 60 / bpmRange.lowerBound
    /// A tap further than this fraction of a beat from the fitted line means the taps were too uneven.
    static let maximumDeviation = 0.3

    private(set) var taps: [Double] = []

    var count: Int { taps.count }

    /// Records a tap at `videoTime`. Ignores bounces; starts over after a long pause or a seek backwards.
    mutating func tap(at videoTime: Double) {
        if let last = taps.last {
            let gap = videoTime - last
            if gap >= 0 && gap < Self.minimumGap { return }
            if gap < 0 || gap > Self.maximumGap { taps.removeAll() }
        }
        taps.append(videoTime)
    }

    mutating func reset() {
        taps.removeAll()
    }

    enum Estimate: Equatable {
        case needMoreTaps
        /// The taps don't follow a steady beat, or the tempo is out of range.
        case uneven
        case segment(start: Double, bpm: Double)
    }

    /// The taps so far, counted from the first one as beat 0 (the user starts tapping on a "1").
    var beatTaps: [BeatTap] {
        taps.enumerated().map { BeatTap(beat: $0.offset, time: $0.element) }
    }

    /// A new segment starting at the first tap.
    var estimate: Estimate {
        guard taps.count >= Self.minimumTaps else { return .needMoreTaps }
        return Self.fit(beatTaps)
    }

    /// Calibrating: these taps, made later in `segment`, refit together with the taps it was made from.
    ///
    /// Eight taps only span a few seconds, so a tiny error in the beat length adds up over a long song.
    /// Taps a minute later pin the line down at both ends, which makes it many times more accurate.
    func calibrated(_ segment: BeatSegment) -> Estimate {
        // These taps must make sense on their own before they're trusted to correct the segment.
        guard case .segment = estimate else { return estimate }
        return Self.fit(calibrationTaps(for: segment))
    }

    /// The segment's own taps plus these, numbered by the segment's beat. The user starts on a "1", so
    /// the first tap is the nearest multiple of eight beats: a drift of up to four beats is still placed right.
    func calibrationTaps(for segment: BeatSegment) -> [BeatTap] {
        guard let first = taps.first else { return segment.taps ?? [] }
        let beatsIn = (first - segment.start) / segment.beatInterval
        let eight = Double(BeatGrid.countsPerEight)
        let firstBeat = Int((beatsIn / eight).rounded() * eight)
        let earlier = segment.taps ?? [BeatTap(beat: 0, time: segment.start)]
        return earlier + taps.enumerated().map { BeatTap(beat: firstBeat + $0.offset, time: $0.element) }
    }

    /// Fits a straight line through the taps (least squares): beat number → video time.
    /// The slope is the beat length and the intercept is where beat 0, the first "1", falls. Using every
    /// tap evens out the wobble of a human finger better than averaging the gaps would.
    static func fit(_ taps: [BeatTap]) -> Estimate {
        guard taps.count >= 2 else { return .needMoreTaps }
        let n = Double(taps.count)
        let meanX = taps.reduce(0) { $0 + Double($1.beat) } / n
        let meanY = taps.reduce(0) { $0 + $1.time } / n
        var sxy = 0.0, sxx = 0.0
        for tap in taps {
            let dx = Double(tap.beat) - meanX
            sxy += dx * (tap.time - meanY)
            sxx += dx * dx
        }
        guard sxx > 0 else { return .uneven }
        let interval = sxy / sxx
        guard interval > 0 else { return .uneven }
        let start = meanY - interval * meanX
        let bpm = 60 / interval
        guard bpmRange.contains(bpm) else { return .uneven }

        let worst = taps.map { abs($0.time - (start + interval * Double($0.beat))) }.max() ?? 0
        guard worst <= maximumDeviation * interval else { return .uneven }
        return .segment(start: start, bpm: bpm)
    }
}
