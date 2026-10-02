//
//  DancePracticeTests.swift
//  DancePracticeTests
//
//  Created by Yiran on 02/10/2026.
//

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
