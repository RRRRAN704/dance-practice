//
//  BeatCountTests.swift
//  DancePracticeTests
//

import AVFoundation
import Testing
@testable import DancePractice

struct TapTempoTests {
    /// Taps every `interval` seconds from `start`, each nudged by the matching `jitter`.
    private func tapped(start: Double, interval: Double, count: Int, jitter: [Double] = []) -> TapTempo {
        var tempo = TapTempo()
        for i in 0..<count {
            tempo.tap(at: start + Double(i) * interval + (i < jitter.count ? jitter[i] : 0))
        }
        return tempo
    }

    private func segment(_ estimate: TapTempo.Estimate) throws -> (start: Double, bpm: Double) {
        guard case let .segment(start, bpm) = estimate else {
            Issue.record("expected a segment, got \(estimate)")
            throw CancellationError()
        }
        return (start, bpm)
    }

    @Test func needsFourTaps() {
        #expect(tapped(start: 10, interval: 0.5, count: 3).estimate == .needMoreTaps)
    }

    @Test func steadyTapsGiveExactTempoAndStart() throws {
        let result = try segment(tapped(start: 10, interval: 0.5, count: 8).estimate)
        #expect(abs(result.bpm - 120) < 1e-9)
        #expect(abs(result.start - 10) < 1e-9)
    }

    @Test func wobblyTapsStillLandClose() throws {
        let jitter = [0.02, -0.03, 0.01, 0.025, -0.02, 0.0, 0.03, -0.01]
        let result = try segment(tapped(start: 42, interval: 0.48, count: 8, jitter: jitter).estimate)
        #expect(abs(result.bpm - 125) < 2)
        #expect(abs(result.start - 42) < 0.04)
    }

    @Test func unevenTapsAreRejected() {
        let tempo = tapped(start: 0, interval: 0.5, count: 6, jitter: [0, 0, 0.3, 0, 0, 0])
        #expect(tempo.estimate == .uneven)
    }

    @Test func tooFastIsRejected() {
        // 0.2 s apart is 300 BPM: past the range, though not short enough to count as bounces.
        #expect(tapped(start: 0, interval: 0.2, count: 6).estimate == .uneven)
    }

    @Test func longPauseStartsOver() {
        var tempo = tapped(start: 0, interval: 0.5, count: 3)
        tempo.tap(at: 1 + TapTempo.maximumGap + 0.1)
        #expect(tempo.count == 1)
    }

    @Test func bouncesAreIgnored() {
        var tempo = TapTempo()
        tempo.tap(at: 5)
        tempo.tap(at: 5.05)
        #expect(tempo.count == 1)
    }

    @Test func keepsTappingPastOneEight() throws {
        let tempo = tapped(start: 0, interval: 0.5, count: 16)
        #expect(tempo.count == 16)
        #expect(tempo.beatTaps.last == BeatTap(beat: 15, time: 7.5))
        _ = try segment(tempo.estimate)
    }

    @Test func seekingBackStartsOver() {
        var tempo = tapped(start: 30, interval: 0.5, count: 3)
        tempo.tap(at: 12)
        #expect(tempo.taps == [12])
    }
}

struct BeatGridTests {
    private func grid(_ segments: BeatSegment...) -> BeatGrid {
        var grid = BeatGrid()
        segments.forEach { grid.add($0) }
        return grid
    }

    @Test func nothingCountsBeforeTheFirstSegment() {
        let grid = grid(BeatSegment(start: 10, bpm: 120))
        #expect(grid.position(at: 5) == nil)
    }

    @Test func countsOneToEightThenWraps() {
        let grid = grid(BeatSegment(start: 10, bpm: 120)) // 0.5 s per beat
        #expect(grid.position(at: 10)?.count == 1)
        #expect(grid.position(at: 10.49)?.count == 1)
        #expect(grid.position(at: 10.5)?.count == 2)
        #expect(grid.position(at: 13.75)?.count == 8)
        #expect(grid.position(at: 14)?.count == 1)
    }

    @Test func phaseRunsThroughEachBeat() throws {
        let position = try #require(BeatGrid().adding(BeatSegment(start: 0, bpm: 60)).position(at: 2.25))
        #expect(position.count == 3)
        #expect(abs(position.phase - 0.25) < 1e-9)
    }

    @Test func oneShowsJustBeforeATappedStart() {
        let grid = grid(BeatSegment(start: 10, bpm: 120))
        #expect(grid.position(at: 9.95)?.count == 1)
        #expect(grid.position(at: 9.9) == nil)
    }

    @Test func laterSegmentTakesOver() {
        let grid = grid(BeatSegment(start: 10, bpm: 120), BeatSegment(start: 60, bpm: 100))
        #expect(grid.segments.count == 2)
        #expect(grid.segment(at: 59)?.bpm == 120)
        #expect(grid.segment(at: 61)?.bpm == 100)
        #expect(grid.position(at: 60)?.count == 1)
    }

    @Test func retappingNearbyReplacesTheSegment() {
        let grid = grid(BeatSegment(start: 10, bpm: 120), BeatSegment(start: 10.3, bpm: 118))
        #expect(grid.segments.count == 1)
        #expect(grid.segments.first?.bpm == 118)
    }

    @Test func stopEndsTheCount() {
        var grid = grid(BeatSegment(start: 10, bpm: 120))
        grid.stop(at: 30)
        #expect(grid.position(at: 29.9) != nil)
        #expect(grid.position(at: 30) == nil)
        #expect(grid.position(at: 100) == nil)
    }

    @Test func stopOutsideASegmentDoesNothing() {
        var grid = grid(BeatSegment(start: 10, bpm: 120))
        grid.stop(at: 5)
        #expect(grid.segments.count == 1)
        #expect(grid.segments.first?.end == nil)
    }

    @Test func newSegmentInsideAStoppedOneKeepsTheEnd() {
        var grid = grid(BeatSegment(start: 10, bpm: 120))
        grid.stop(at: 50)
        grid.add(BeatSegment(start: 30, bpm: 122))
        #expect(grid.segment(at: 40)?.bpm == 122)
        #expect(grid.position(at: 50) == nil)
    }

    @Test func survivesSaving() throws {
        var grid = grid(BeatSegment(start: 10, bpm: 120), BeatSegment(start: 60, bpm: 100))
        grid.stop(at: 90)
        let decoded = try JSONDecoder().decode(BeatGrid.self, from: JSONEncoder().encode(grid))
        #expect(decoded == grid)
    }
}

private extension BeatGrid {
    func adding(_ segment: BeatSegment) -> BeatGrid {
        var copy = self
        copy.add(segment)
        return copy
    }
}

struct ClickTrackTests {
    private func grid(_ segments: BeatSegment...) -> BeatGrid {
        var grid = BeatGrid()
        segments.forEach { grid.add($0) }
        return grid
    }

    @Test func clickOnEveryBeatWithTheOneMarked() {
        let clicks = ClickTrack.clicks(for: grid(BeatSegment(start: 1, bpm: 120)), duration: 6)
        #expect(clicks.map(\.time) == [1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5])
        #expect(clicks.filter(\.isDownbeat).map(\.time) == [1, 5])
    }

    @Test func silentWhereCountingStopped() {
        var grid = grid(BeatSegment(start: 0, bpm: 60))
        grid.stop(at: 3)
        #expect(ClickTrack.clicks(for: grid, duration: 10).map(\.time) == [0, 1, 2])
    }

    @Test func nextSegmentTakesOverWithoutDoubleClicks() {
        let clicks = ClickTrack.clicks(
            for: grid(BeatSegment(start: 0, bpm: 60), BeatSegment(start: 20.5, bpm: 120)),
            duration: 22
        )
        // The old segment clicks until just before the new "1" (20 s is outside the 0.075 s early window).
        #expect(clicks.map(\.time).suffix(5) == [19, 20, 20.5, 21, 21.5])
        #expect(clicks.first { $0.time == 20.5 }?.isDownbeat == true)
    }

    @Test func noCountsNoClicks() {
        #expect(ClickTrack.clicks(for: BeatGrid(), duration: 30).isEmpty)
    }

    @Test func writtenFileHasTheVideoLengthAndSoundOnTheBeats() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "click-test-\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let clicks = [ClickTrack.Click(time: 0.5, isDownbeat: true), ClickTrack.Click(time: 1.99, isDownbeat: false)]

        try ClickTrack.write(clicks, duration: 2.5, to: url)

        let file = try AVAudioFile(forReading: url)
        #expect(file.length == Int64(2.5 * ClickTrack.sampleRate))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let samples = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
        func loudest(from: Double, to: Double) -> Float {
            samples[Int(from * ClickTrack.sampleRate)..<Int(to * ClickTrack.sampleRate)].map(abs).max() ?? 0
        }
        #expect(loudest(from: 0, to: 0.49) == 0)
        #expect(loudest(from: 0.5, to: 0.55) > 0.1)
        #expect(loudest(from: 0.6, to: 1.98) == 0)
        // This click starts just before the one-second chunk boundary and runs over it.
        #expect(loudest(from: 2.0, to: 2.02) > 0.01)
    }
}

struct CalibrationTests {
    /// A segment tapped slightly too fast: 0.495 s per beat when the music is 0.5 s (about 121.2 BPM vs 120).
    private func rushedSegment() -> BeatSegment {
        let taps = (0..<8).map { BeatTap(beat: $0, time: 10 + Double($0) * 0.495) }
        return BeatSegment(start: 10, bpm: 60 / 0.495, taps: taps)
    }

    private func tapped(from start: Double, count: Int = 8, interval: Double = 0.5) -> TapTempo {
        var tempo = TapTempo()
        for i in 0..<count { tempo.tap(at: start + Double(i) * interval) }
        return tempo
    }

    @Test func tapsLaterInTheSongFixTheTempo() throws {
        let segment = rushedSegment()
        // Beat 112 of the real music is at 10 + 112 × 0.5 = 66 s; by then the rushed count is 0.56 s early.
        let estimate = tapped(from: 66).calibrated(segment)
        guard case let .segment(start, bpm) = estimate else {
            Issue.record("expected a segment, got \(estimate)")
            return
        }
        #expect(abs(bpm - 120) < 0.3)
        #expect(abs(start - 10) < 0.05)
    }

    @Test func calibrationTapsArePlacedOnTheNearestEight() {
        let taps = tapped(from: 66).calibrationTaps(for: rushedSegment())
        #expect(taps.count == 16)
        #expect(taps[8] == BeatTap(beat: 112, time: 66))
        #expect(taps.last?.beat == 119)
    }

    @Test func countsSavedWithoutTapsUseTheirStart() {
        let old = BeatSegment(start: 10, bpm: 60 / 0.495)
        let taps = tapped(from: 66).calibrationTaps(for: old)
        #expect(taps.first == BeatTap(beat: 0, time: 10))
        #expect(taps.count == 9)
    }

    @Test func aDifferentTempoIsRejected() {
        // Steady taps, but at 100 BPM against a 120 BPM count: different music, not a small correction.
        let segment = BeatSegment(start: 10, bpm: 120, taps: (0..<8).map { BeatTap(beat: $0, time: 10 + Double($0) * 0.5) })
        #expect(tapped(from: 66, interval: 0.6).calibrated(segment) == .uneven)
    }

    @Test func needsEnoughTapsOfItsOwn() {
        #expect(tapped(from: 66, count: 3).calibrated(rushedSegment()) == .needMoreTaps)
    }

    @Test func replacingKeepsTheSegmentAndOrder() {
        var grid = BeatGrid()
        grid.add(BeatSegment(start: 10, bpm: 121))
        grid.add(BeatSegment(start: 80, bpm: 100))
        var segment = grid.segments[0]
        segment.bpm = 120
        grid.replace(segment)
        #expect(grid.segments.map(\.bpm) == [120, 100])
    }

    @Test func countsSavedBeforeCalibrationStillLoad() throws {
        let json = #"{"segments":[{"id":"8D3F4E1A-1111-4C2B-9C1A-000000000001","start":10,"bpm":120}]}"#
        let grid = try JSONDecoder().decode(BeatGrid.self, from: Data(json.utf8))
        #expect(grid.segments.first?.taps == nil)
        #expect(grid.position(at: 10)?.count == 1)
    }
}
