//
//  DancePracticeTests.swift
//  DancePracticeTests
//
//  Created by Yiran on 02/10/2026.
//

import CoreGraphics
import Testing
@testable import DancePractice

struct LoopRangeTests {
    @Test func validRange() throws {
        let range = try #require(LoopRange(start: 32, end: 41, duration: 198))
        #expect(range.start == 32)
        #expect(range.end == 41)
        #expect(range.contains(35))
        #expect(!range.contains(42))
    }

    @Test func rejectsEndBeforeStart() {
        #expect(LoopRange(start: 41, end: 32, duration: 198) == nil)
    }

    @Test func rejectsTooShort() {
        #expect(LoopRange(start: 10, end: 10.1, duration: 198) == nil)
    }

    @Test func clampsToVideoBounds() throws {
        let range = try #require(LoopRange(start: -3, end: 500, duration: 198))
        #expect(range.start == 0)
        #expect(range.end == 198)
    }
}

struct SpeedTests {
    @Test(arguments: [
        (0.1, 0.25),
        (3.0, 2.0),
        (0.74, 0.75),
        (1.0, 1.0),
        (1.33, 1.35),
    ])
    func normalizesSpeed(input: Double, expected: Double) {
        #expect(PlayerViewModel.normalizedSpeed(input) == expected)
    }

    @Test(arguments: [
        (0.1, 0.25),
        (2.3, 2.0),
        (1.33, 1.35),
        (1.75, 1.75),
    ])
    func sliderSnapsToStep(input: Double, expected: Double) {
        #expect(SpeedSlider.snapped(input, range: 0.25...2.0, step: 0.05) == expected)
    }
}

struct TimeFormatTests {
    @Test func clock() {
        #expect(TimeFormat.clock(198) == "03:18")
        #expect(TimeFormat.clock(.nan) == "00:00")
    }

    @Test func precise() {
        #expect(TimeFormat.precise(32.47) == "00:32.4")
        #expect(TimeFormat.precise(61.05) == "01:01.0")
    }
}

struct LoopEditingTests {
    @Test func defaultLoopStartsAtCurrentTime() throws {
        let range = try #require(PlayerViewModel.defaultLoopRange(at: 30, duration: 198))
        #expect(range.start == 30)
        #expect(range.end == 38)
    }

    @Test func defaultLoopShiftsBackNearEnd() throws {
        let range = try #require(PlayerViewModel.defaultLoopRange(at: 195, duration: 198))
        #expect(range.start == 190)
        #expect(range.end == 198)
    }

    @Test func defaultLoopFitsShortVideo() throws {
        let range = try #require(PlayerViewModel.defaultLoopRange(at: 2, duration: 5))
        #expect(range.start == 0)
        #expect(range.end == 5)
    }

    @Test func seekIsClampedToLoop() throws {
        let loop = try #require(LoopRange(start: 30, end: 38, duration: 198))
        #expect(PlayerViewModel.clampedSeekTime(10, loop: loop, duration: 198) == 30)
        #expect(PlayerViewModel.clampedSeekTime(50, loop: loop, duration: 198) == 38)
        #expect(PlayerViewModel.clampedSeekTime(50, loop: nil, duration: 198) == 50)
        #expect(PlayerViewModel.clampedSeekTime(300, loop: nil, duration: 198) == 198)
    }

    @Test func handlesKeepMinimumLength() throws {
        let loop = try #require(LoopRange(start: 30, end: 38, duration: 198))
        #expect(loop.withStart(40, duration: 198).start == 38 - LoopRange.minimumLength)
        #expect(loop.withEnd(10, duration: 198).end == 30 + LoopRange.minimumLength)
        #expect(loop.withStart(-5, duration: 198).start == 0)
        #expect(loop.withEnd(500, duration: 198).end == 198)
    }
}

struct VideoOrientationTests {
    @Test func landscapeVideo() {
        #expect(!PlayerViewModel.isPortrait(CGSize(width: 1920, height: 1080)))
    }

    @Test func portraitVideo() {
        #expect(PlayerViewModel.isPortrait(CGSize(width: 1080, height: 1920)))
    }

    /// Phone recordings are stored landscape with a 90° transform; the applied size can be negative.
    @Test func rotatedPhoneRecordingIsPortrait() {
        let displayed = CGSize(width: 1920, height: 1080).applying(CGAffineTransform(rotationAngle: .pi / 2))
        #expect(PlayerViewModel.isPortrait(displayed))
    }

    @Test func audioOnlyIsNotPortrait() {
        #expect(!PlayerViewModel.isPortrait(.zero))
    }
}
