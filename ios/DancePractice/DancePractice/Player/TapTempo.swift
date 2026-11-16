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
    /// One eight: tapping finishes on its own after this many.
    static let maximumTaps = 8
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

    /// Fits a straight line through the taps (least squares): tap number → video time.
    /// The slope is the beat length and the intercept is where the first "1" falls. Using every tap
    /// evens out the wobble of a human finger better than averaging the gaps would.
    var estimate: Estimate {
        guard taps.count >= Self.minimumTaps else { return .needMoreTaps }
        let n = Double(taps.count)
        let xs = taps.indices.map(Double.init)
        let meanX = xs.reduce(0, +) / n
        let meanY = taps.reduce(0, +) / n
        var sxy = 0.0, sxx = 0.0
        for (x, y) in zip(xs, taps) {
            sxy += (x - meanX) * (y - meanY)
            sxx += (x - meanX) * (x - meanX)
        }
        let interval = sxy / sxx
        guard interval > 0 else { return .uneven }
        let start = meanY - interval * meanX
        let bpm = 60 / interval
        guard Self.bpmRange.contains(bpm) else { return .uneven }

        let worst = zip(xs, taps).map { abs($1 - (start + interval * $0)) }.max() ?? 0
        guard worst <= Self.maximumDeviation * interval else { return .uneven }
        return .segment(start: start, bpm: bpm)
    }
}
