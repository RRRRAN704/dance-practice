//
//  DancePracticeTests.swift
//  DancePracticeTests
//
//  Created by Yiran on 02/10/2026.
//

import CoreGraphics
import SwiftData
import Testing
import UIKit
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

struct FullscreenRotationTests {
    private func action(
        _ previous: UIDeviceOrientation,
        _ current: UIDeviceOrientation,
        fullscreen: Bool,
        portraitVideo: Bool = false
    ) -> FullscreenRotation.Action {
        FullscreenRotation.action(
            previous: previous, current: current, isFullscreen: fullscreen, isPortraitVideo: portraitVideo
        )
    }

    @Test func turningToLandscapeEntersFullscreen() {
        #expect(action(.portrait, .landscapeLeft, fullscreen: false) == .enter)
        #expect(action(.portrait, .landscapeRight, fullscreen: false) == .enter)
    }

    @Test func turningBackToPortraitExits() {
        #expect(action(.landscapeLeft, .portrait, fullscreen: true) == .exit)
    }

    @Test func flippingBetweenLandscapesStaysFullscreen() {
        #expect(action(.landscapeLeft, .landscapeRight, fullscreen: true) == .none)
    }

    /// Button pressed while holding the phone upright: no change, so it must not exit.
    @Test func noChangeDoesNothing() {
        #expect(action(.portrait, .portrait, fullscreen: true) == .none)
    }

    @Test func portraitVideosIgnoreRotation() {
        #expect(action(.portrait, .landscapeLeft, fullscreen: false, portraitVideo: true) == .none)
        #expect(action(.landscapeLeft, .portrait, fullscreen: true, portraitVideo: true) == .none)
    }

    @Test func onlyPortraitAndLandscapeAreTracked() {
        #expect(FullscreenRotation.isTracked(.portrait))
        #expect(FullscreenRotation.isTracked(.landscapeLeft))
        #expect(!FullscreenRotation.isTracked(.faceUp))
        #expect(!FullscreenRotation.isTracked(.faceDown))
        #expect(!FullscreenRotation.isTracked(.unknown))
        #expect(!FullscreenRotation.isTracked(.portraitUpsideDown))
    }
}

@MainActor
struct PracticeRoomTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PracticeRoom.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func insertAndFetch() throws {
        let context = try makeContext()
        context.insert(PracticeRoom(name: "Smoothie", videoFileName: "a.mov", artist: "NCT DREAM", genre: .kpop))
        try context.save()

        let rooms = try context.fetch(FetchDescriptor<PracticeRoom>())
        #expect(rooms.count == 1)
        #expect(rooms.first?.name == "Smoothie")
        #expect(rooms.first?.genre == .kpop)
    }

    @Test func genreIsOptional() {
        let room = PracticeRoom(name: "Untitled", videoFileName: "b.mov")
        #expect(room.genre == nil)
        room.genre = .jazz
        #expect(room.genreRaw == "jazz")
    }

    @Test func unknownStoredGenreReadsAsNil() {
        let room = PracticeRoom(name: "Old", videoFileName: "c.mov")
        room.genreRaw = "breaking"
        #expect(room.genre == nil)
    }

    @Test func videoURLIsRebuiltFromFileName() {
        let room = PracticeRoom(name: "Smoothie", videoFileName: "abc.mov")
        #expect(room.videoURL.lastPathComponent == "abc.mov")
        #expect(room.videoURL.deletingLastPathComponent().lastPathComponent == "Videos")
    }

    @Test func fileNamesIncludeCoverWhenPresent() {
        #expect(PracticeRoom(name: "A", videoFileName: "a.mov").fileNames == ["a.mov"])
        #expect(PracticeRoom(name: "B", videoFileName: "b.mov", coverFileName: "b.jpg").fileNames == ["b.mov", "b.jpg"])
    }
}

struct RoomFilterTests {
    private let rooms = [
        PracticeRoom(name: "Smoothie", videoFileName: "a.mov", genre: .kpop),
        PracticeRoom(name: "Jazz Walk", videoFileName: "b.mov", genre: .jazz),
        PracticeRoom(name: "Untitled", videoFileName: "c.mov"),
    ]

    @Test func allKeepsEveryRoomInOrder() {
        #expect(RoomFilter.rooms(rooms, genre: nil).map(\.name) == ["Smoothie", "Jazz Walk", "Untitled"])
    }

    @Test func genreKeepsOnlyMatches() {
        #expect(RoomFilter.rooms(rooms, genre: .kpop).map(\.name) == ["Smoothie"])
    }

    @Test func roomsWithoutGenreOnlyShowUnderAll() {
        #expect(RoomFilter.rooms(rooms, genre: .other).isEmpty)
    }
}

struct PracticeTimerTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func countsOnlyPlayingTime() throws {
        var timer = PracticeTimer()
        timer.start(at: t0)
        timer.stop(at: t0 + 30)          // played 30s
        timer.start(at: t0 + 90)         // paused 60s, not counted
        timer.stop(at: t0 + 110)         // played 20s
        let recordResult = timer.finish(at: t0 + 200)
        let record = try #require(recordResult)
        #expect(record.duration == 50)
        #expect(record.startedAt == t0)
    }

    @Test func includesTheRunningStretchWhenFinished() throws {
        var timer = PracticeTimer()
        timer.start(at: t0)
        let recordResult = timer.finish(at: t0 + 15)
        let record = try #require(recordResult)
        #expect(record.duration == 15)
    }

    @Test func dropsSessionsUnderTheMinimum() {
        var timer = PracticeTimer()
        timer.start(at: t0)
        timer.stop(at: t0 + PracticeTimer.minimumDuration - 1)
        let result = timer.finish(at: t0 + 60)
        #expect(result == nil)
    }

    @Test func neverStartedGivesNothing() {
        var timer = PracticeTimer()
        let result = timer.finish(at: t0)
        #expect(result == nil)
    }

    @Test func repeatedStartOrStopIsIgnored() throws {
        var timer = PracticeTimer()
        timer.start(at: t0)
        timer.start(at: t0 + 10)         // still counts from t0
        timer.stop(at: t0 + 20)
        timer.stop(at: t0 + 40)          // already stopped
        let recordResult = timer.finish(at: t0 + 50)
        let record = try #require(recordResult)
        #expect(record.duration == 20)
    }

    @Test func finishWhilePlayingStartsAFreshSession() throws {
        var timer = PracticeTimer()
        timer.start(at: t0)
        _ = timer.finish(at: t0 + 20)
        #expect(timer.isRunning)
        let nextResult = timer.finish(at: t0 + 45)
        let next = try #require(nextResult)
        #expect(next.startedAt == t0 + 20)
        #expect(next.duration == 25)
    }
}

@MainActor
struct PracticeSessionTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PracticeRoom.self, PracticeSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func roomTotalsAddUpItsSessions() throws {
        let context = try makeContext()
        let room = PracticeRoom(name: "Smoothie", videoFileName: "a.mov", genre: .kpop)
        context.insert(room)
        let early = Date(timeIntervalSince1970: 1_000)
        let late = Date(timeIntervalSince1970: 5_000)
        context.insert(PracticeSession(startedAt: late, duration: 120, room: room))
        context.insert(PracticeSession(startedAt: early, duration: 60, room: room))
        try context.save()

        #expect(room.totalPracticeTime == 180)
        #expect(room.lastPracticedAt == late)
    }

    @Test func deletingRoomKeepsSessionsWithSnapshot() throws {
        let context = try makeContext()
        let room = PracticeRoom(name: "Smoothie", videoFileName: "a.mov", genre: .kpop)
        context.insert(room)
        context.insert(PracticeSession(startedAt: .now, duration: 60, room: room))
        try context.save()

        context.delete(room)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<PracticeSession>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.room == nil)
        #expect(sessions.first?.roomName == "Smoothie")
        #expect(sessions.first?.genre == .kpop)
    }

    @Test func sessionGenreFollowsLaterRoomEdits() throws {
        let context = try makeContext()
        let room = PracticeRoom(name: "Untitled", videoFileName: "a.mov")
        context.insert(room)
        let session = PracticeSession(startedAt: .now, duration: 60, room: room)
        context.insert(session)
        room.genre = .jazz
        #expect(session.genre == .jazz)
    }
}
