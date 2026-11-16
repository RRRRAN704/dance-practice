//
//  BeatCountTests.swift
//  DancePracticeTests
//

import Foundation
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
