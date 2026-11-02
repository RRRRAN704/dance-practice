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

struct PracticeFormatTests {
    static let durationCases: [(Double, String)] = [
        (30, "不到 1 分钟"),
        (2700, "45 分钟"),
        (7200, "2 小时"),
        (12600, "3.5 小时"),
        (3659, "1 小时"),
    ]

    @Test(arguments: durationCases)
    func practiceDuration(seconds: Double, expected: String) {
        #expect(TimeFormat.practiceDuration(seconds) == expected)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func lastPracticedRelativeDays() {
        let now = date(10, 21, 9, 0)
        #expect(TimeFormat.lastPracticed(date(10, 21, 8, 5), now: now, calendar: calendar) == "今天 08:05")
        #expect(TimeFormat.lastPracticed(date(10, 20, 23, 50), now: now, calendar: calendar) == "昨天 23:50")
        #expect(TimeFormat.lastPracticed(date(10, 18, 12, 0), now: now, calendar: calendar) == "3 天前")
        #expect(TimeFormat.lastPracticed(date(10, 2, 12, 0), now: now, calendar: calendar) == "10月2日")
    }
}

@MainActor
struct PracticeStatsTests {
    private var calendar: Calendar {
        var base = Calendar(identifier: .gregorian)
        base.timeZone = TimeZone(identifier: "Europe/London")!
        return PracticeStats.calendar(base: base)
    }

    /// 2026-10-21 is a Wednesday.
    private func date(_ day: Int, _ hour: Int = 12, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func sessions(_ items: [(Date, TimeInterval)]) -> [PracticeSession] {
        let room = PracticeRoom(name: "R", videoFileName: "r.mov")
        return items.map { PracticeSession(startedAt: $0.0, duration: $0.1, room: room) }
    }

    @Test func todayAndWeekTotals() {
        let all = sessions([
            (date(21, 9), 600),   // today (Wed)
            (date(21, 20), 300),  // today
            (date(19), 1200),     // Monday, same week
            (date(18), 900),      // Sunday, previous week
        ])
        let now = date(21, 22)
        #expect(PracticeStats.today(all, now: now, calendar: calendar) == 900)
        #expect(PracticeStats.thisWeek(all, now: now, calendar: calendar) == 2100)
    }

    @Test func weekStartsOnMonday() {
        let days = PracticeStats.weekDays(now: date(21), calendar: calendar)
        #expect(days.count == 7)
        #expect(days.first == calendar.startOfDay(for: date(19)))
        #expect(days.last == calendar.startOfDay(for: date(25)))
    }

    @Test func streakCountsBackFromToday() {
        let days = PracticeStats.practicedDays([date(21), date(20), date(19), date(17)], calendar: calendar)
        #expect(PracticeStats.currentStreak(days: days, now: date(21, 23), calendar: calendar) == 3)
    }

    @Test func streakSurvivesUntilTodayIsPracticed() {
        let days = PracticeStats.practicedDays([date(20), date(19)], calendar: calendar)
        #expect(PracticeStats.currentStreak(days: days, now: date(21, 8), calendar: calendar) == 2)
    }

    @Test func streakBreaksAfterAMissedDay() {
        let days = PracticeStats.practicedDays([date(19), date(18)], calendar: calendar)
        #expect(PracticeStats.currentStreak(days: days, now: date(21), calendar: calendar) == 0)
    }

    @Test func streakCrossesMonthBoundary() {
        let days = PracticeStats.practicedDays([date(1, month: 11), date(31), date(30)], calendar: calendar)
        #expect(PracticeStats.currentStreak(days: days, now: date(1, 20, month: 11), calendar: calendar) == 3)
    }
}

struct HomeFormatTests {
    @Test func durationPartsSplitValueAndUnit() {
        #expect(TimeFormat.durationParts(0) == ("0", "分钟"))
        #expect(TimeFormat.durationParts(2700) == ("45", "分钟"))
        #expect(TimeFormat.durationParts(12600) == ("3.5", "小时"))
    }

    @Test func greetingByHour() {
        #expect(HomeScreen.greeting(hour: 7) == "早上好")
        #expect(HomeScreen.greeting(hour: 12) == "中午好")
        #expect(HomeScreen.greeting(hour: 15) == "下午好")
        #expect(HomeScreen.greeting(hour: 23) == "晚上好")
        #expect(HomeScreen.greeting(hour: 2) == "晚上好")
    }
}

@MainActor
struct StatsTabTests {
    private var calendar: Calendar {
        var base = Calendar(identifier: .gregorian)
        base.timeZone = TimeZone(identifier: "Europe/London")!
        return PracticeStats.calendar(base: base)
    }

    private func date(_ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    @Test func longestStreakFindsTheBestRun() {
        let days = PracticeStats.practicedDays(
            [date(1), date(2), date(3), date(4), date(10), date(11), date(20)],
            calendar: calendar
        )
        #expect(PracticeStats.longestStreak(days: days, calendar: calendar) == 4)
        #expect(PracticeStats.longestStreak(days: [], calendar: calendar) == 0)
    }

    @Test func recentDaysFillGapsWithZero() {
        let room = PracticeRoom(name: "R", videoFileName: "r.mov")
        let sessions = [
            PracticeSession(startedAt: date(21, 9), duration: 600, room: room),
            PracticeSession(startedAt: date(21, 20), duration: 300, room: room),
            PracticeSession(startedAt: date(19), duration: 120, room: room),
        ]
        let totals = PracticeStats.totalsByDay(sessions, calendar: calendar)
        let days = PracticeStats.recentDays(totals, count: 3, now: date(21, 22), calendar: calendar)
        #expect(days.map(\.seconds) == [120, 0, 900])
        #expect(days.last?.day == calendar.startOfDay(for: date(21)))
    }

    @Test func heatmapEndsWithTheCurrentWeek() {
        let weeks = PracticeStats.heatmapWeeks(weeks: 12, now: date(21), calendar: calendar)
        #expect(weeks.count == 12)
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(weeks.last?.first == calendar.startOfDay(for: date(19)))   // Monday this week
    }

    @Test(arguments: [(0.0, 0), (59.0, 0), (60.0, 1), (899.0, 1), (900.0, 2), (1800.0, 3), (3600.0, 4)])
    func heatLevelBands(seconds: Double, level: Int) {
        #expect(PracticeStats.heatLevel(seconds) == level)
    }

    @Test func genreTotalsSortBiggestFirstWithUnsetLast() {
        let kpop = PracticeRoom(name: "A", videoFileName: "a.mov", genre: .kpop)
        let jazz = PracticeRoom(name: "B", videoFileName: "b.mov", genre: .jazz)
        let unset = PracticeRoom(name: "C", videoFileName: "c.mov")
        let sessions = [
            PracticeSession(startedAt: .now, duration: 100, room: jazz),
            PracticeSession(startedAt: .now, duration: 300, room: kpop),
            PracticeSession(startedAt: .now, duration: 100, room: unset),
            PracticeSession(startedAt: .now, duration: 50, room: jazz),
        ]
        let shares = PracticeStats.genreTotals(sessions)
        #expect(shares.map(\.genre) == [.kpop, .jazz, nil])
        #expect(shares.map(\.seconds) == [300, 150, 100])
    }
}

struct StorageUsageTests {
    private let sizes: [String: Int64] = ["a.mov": 1_000, "a.jpg": 50, "b.mov": 2_000, "stray.mov": 300]

    @Test func roomBytesAddItsFilesAndIgnoreMissingOnes() {
        #expect(StorageUsage.bytes(of: ["a.mov", "a.jpg"], sizes: sizes) == 1_050)
        #expect(StorageUsage.bytes(of: ["gone.mov"], sizes: sizes) == 0)
    }

    @Test func orphansAreFilesNoRoomReferences() {
        let referenced: Set<String> = ["a.mov", "a.jpg", "b.mov"]
        #expect(StorageUsage.orphans(sizes: sizes, referenced: referenced) == ["stray.mov"])
        #expect(StorageUsage.orphans(sizes: sizes, referenced: Set(sizes.keys)).isEmpty)
    }

    @Test func zeroBytesStayNumeric() {
        #expect(StorageUsage.format(0).hasPrefix("0"))
    }
}

struct AppAppearanceTests {
    @Test func mapsToInterfaceStyle() {
        #expect(AppAppearance.system.interfaceStyle == .unspecified)
        #expect(AppAppearance.light.interfaceStyle == .light)
        #expect(AppAppearance.dark.interfaceStyle == .dark)
    }

    @Test func rawValuesStayStableForStoredSettings() {
        #expect(AppAppearance.allCases.map(\.rawValue) == ["system", "light", "dark"])
    }
}

struct StoredCredentialsTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func credentials(expiringIn seconds: TimeInterval) -> StoredCredentials {
        StoredCredentials(userId: UUID(), email: "a@b.com", accessToken: "old-access",
                          refreshToken: "old-refresh", accessExpiresAt: now.addingTimeInterval(seconds))
    }

    @Test func freshTokenIsUsedAsIs() {
        #expect(!credentials(expiringIn: 15 * 60).accessTokenNeedsRefresh(now: now))
    }

    @Test func refreshesInsideTheMargin() {
        #expect(credentials(expiringIn: StoredCredentials.refreshMargin - 1).accessTokenNeedsRefresh(now: now))
        #expect(credentials(expiringIn: -10).accessTokenNeedsRefresh(now: now))
    }

    @Test func replacingTokensKeepsTheAccount() throws {
        let old = credentials(expiringIn: 0)
        let response = try JSONDecoder().decode(TokenResponse.self, from: Data("""
            {"accessToken":"new-access","refreshToken":"new-refresh","expiresIn":900,"tokenType":"Bearer"}
            """.utf8))
        let updated = old.replacingTokens(with: response, now: now)
        #expect(updated.userId == old.userId)
        #expect(updated.email == old.email)
        #expect(updated.accessToken == "new-access")
        #expect(updated.refreshToken == "new-refresh")
        #expect(updated.accessExpiresAt == now.addingTimeInterval(900))
    }
}

struct APIErrorTests {
    @Test func unauthorizedIgnoresTheBody() {
        #expect(APIError(status: 401, body: Data()) == .unauthorized)
    }

    @Test func readsProblemDetail() {
        let body = Data(#"{"status":409,"detail":"This email is already registered"}"#.utf8)
        #expect(APIError(status: 409, body: body) == .server(status: 409, message: "This email is already registered"))
    }

    @Test func prefersTheFieldMessage() {
        let body = Data(#"{"detail":"Request validation failed","errors":{"email":"must be a well-formed email address"}}"#.utf8)
        #expect(APIError(status: 400, body: body) == .server(status: 400, message: "must be a well-formed email address"))
    }

    @Test func survivesANonJSONBody() {
        #expect(APIError(status: 502, body: Data("<html>".utf8)) == .server(status: 502, message: nil))
    }
}

struct AuthValidationTests {
    @Test(arguments: ["", "abc", "@b.com", "a@b", "a@@b.com"])
    func rejectsBadEmails(email: String) {
        #expect(AuthSheet.validationProblem(email: email, password: "12345678", mode: .login) != nil)
    }

    @Test func passwordRulesOnlyApplyWhenRegistering() {
        #expect(AuthSheet.validationProblem(email: "a@b.com", password: "short", mode: .login) == nil)
        #expect(AuthSheet.validationProblem(email: "a@b.com", password: "short", confirmation: "short",
                                            mode: .register) != nil)
        #expect(AuthSheet.validationProblem(email: "a@b.com", password: "12345678", confirmation: "12345678",
                                            mode: .register) == nil)
        let long = String(repeating: "x", count: 73)
        #expect(AuthSheet.validationProblem(email: "a@b.com", password: long, confirmation: long,
                                            mode: .register) != nil)
    }

    @Test func registeringNeedsMatchingPasswords() {
        #expect(AuthSheet.validationProblem(email: "a@b.com", password: "12345678", confirmation: "12345679",
                                            mode: .register) == "两次输入的密码不一致")
    }
}

@MainActor
struct AccountStoresTests {
    @Test func guestKeepsTheDefaultStore() {
        #expect(AccountStores.storeURL(for: nil) == ModelConfiguration().url)
    }

    @Test func eachAccountGetsItsOwnFile() {
        let a = UUID(), b = UUID()
        #expect(AccountStores.storeURL(for: a) != AccountStores.storeURL(for: b))
        #expect(AccountStores.storeURL(for: a) != AccountStores.storeURL(for: nil))
        #expect(AccountStores.storeURL(for: a).lastPathComponent == "\(a.uuidString).store")
    }
}

struct APIDateTests {
    @Test(arguments: [
        ("2026-11-02T20:45:00Z", Int64(1_793_652_300_000)),
        ("2026-11-02T20:45:00.123Z", Int64(1_793_652_300_123)),
        ("2026-11-02T20:45:00.123456Z", Int64(1_793_652_300_123)),
        ("2026-11-02T20:45:00.123789Z", Int64(1_793_652_300_124)),
    ])
    func readsJavaInstants(text: String, millis: Int64) throws {
        let date = try #require(APIDate.date(from: text))
        #expect(APIDate.millis(date) == millis)
    }

    @Test func rejectsNonUTC() {
        #expect(APIDate.date(from: "2026-11-02T20:45:00+01:00") == nil)
    }

    @Test func roundTripsAtMillisecondPrecision() throws {
        let date = Date(timeIntervalSince1970: 1_793_652_300.123_456)
        let text = APIDate.string(from: date)
        #expect(text == "2026-11-02T20:45:00.123Z")
        #expect(try #require(APIDate.date(from: text)) == date.roundedToMilliseconds)
    }
}

struct SyncMergerTests {
    private let t0 = Date(timeIntervalSince1970: 1_000)
    private let t1 = Date(timeIntervalSince1970: 2_000)

    private func remote(updatedAt: Date, deleted: Bool = false) -> RoomDTO {
        RoomDTO(id: UUID(), name: "Smoothie", videoFileName: "a.mov", createdAt: t0,
                updatedAt: updatedAt, deletedAt: deleted ? updatedAt : nil)
    }

    @Test func newRoomsAreInserted() {
        #expect(SyncMerger.action(for: remote(updatedAt: t1), local: .none) == .insert)
    }

    @Test func unknownTombstonesAreIgnored() {
        #expect(SyncMerger.action(for: remote(updatedAt: t1, deleted: true), local: .none) == .skip)
    }

    @Test func tombstonesDeleteEvenNewerLocalEdits() {
        let local = SyncMerger.Local.room(needsSync: true, updatedAt: t1)
        #expect(SyncMerger.action(for: remote(updatedAt: t0, deleted: true), local: local) == .delete)
    }

    @Test func newerServerVersionWins() {
        #expect(SyncMerger.action(for: remote(updatedAt: t1), local: .room(needsSync: true, updatedAt: t0)) == .update)
        #expect(SyncMerger.action(for: remote(updatedAt: t0), local: .room(needsSync: false, updatedAt: t1)) == .update)
    }

    @Test func newerUnpushedLocalEditIsKept() {
        #expect(SyncMerger.action(for: remote(updatedAt: t0), local: .room(needsSync: true, updatedAt: t1)) == .keepLocal)
    }

    @Test func aTieGoesToTheServer() {
        // Matches the backend, where an equal updatedAt loses.
        #expect(SyncMerger.action(for: remote(updatedAt: t1), local: .room(needsSync: true, updatedAt: t1)) == .update)
    }

    @Test func pendingLocalDeletesWaitForThePush() {
        #expect(SyncMerger.action(for: remote(updatedAt: t1), local: .pendingDelete) == .skip)
    }

    @Test func editsDuringThePushStayDirty() {
        #expect(SyncMerger.isClean(afterPushing: t0, current: t0))
        #expect(!SyncMerger.isClean(afterPushing: t0, current: t1))
    }
}

struct SyncDTOTests {
    @Test func encodesTheBackendsShape() throws {
        let room = RoomDTO(id: UUID(uuidString: "6E4425E2-266E-4340-9ED2-84443D8CFF52")!, name: "Smoothie",
                           videoFileName: "a.mov", createdAt: Date(timeIntervalSince1970: 1_793_652_300),
                           updatedAt: Date(timeIntervalSince1970: 1_793_652_300.5))
        let json = try #require(String(data: APIClient.encoder.encode(room), encoding: .utf8))
        #expect(json.contains(#""updatedAt":"2026-11-02T20:45:00.500Z""#))
        #expect(json.contains(#""id":"6E4425E2-266E-4340-9ED2-84443D8CFF52""#))
        // Optionals left out read as null in Jackson.
        #expect(!json.contains("deletedAt"))
    }

    @Test @MainActor func tombstoneCarriesTheWholeRoom() throws {
        let room = PracticeRoom(name: "Smoothie", videoFileName: "a.mov", artist: "NCT DREAM", genre: .kpop)
        let now = Date(timeIntervalSince1970: 1_793_652_300.123_4)
        let tombstone = try #require(DeletedRoom(room: room, now: now).room)
        #expect(tombstone.id == room.id)
        #expect(tombstone.name == "Smoothie")
        #expect(tombstone.genre == "kpop")
        #expect(tombstone.deletedAt == now.roundedToMilliseconds)
        #expect(tombstone.updatedAt == now.roundedToMilliseconds)
    }
}

@MainActor
struct GuestImporterTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainer(for: AccountStores.schema,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    @Test func importedIDsAreStablePerAccountAndDifferAcrossAccounts() {
        let guestID = UUID(), a = UUID(), b = UUID()
        #expect(GuestImporter.importedID(guestID, accountID: a) == GuestImporter.importedID(guestID, accountID: a))
        #expect(GuestImporter.importedID(guestID, accountID: a) != GuestImporter.importedID(guestID, accountID: b))
        #expect(GuestImporter.importedID(guestID, accountID: a) != guestID)
    }

    @Test func copiesRoomsAndSessionsWithTheirLinks() throws {
        let guest = try makeContext(), account = try makeContext()
        let room = PracticeRoom(name: "Smoothie", videoFileName: "missing.mov", genre: .kpop)
        guest.insert(room)
        guest.insert(PracticeSession(startedAt: .now, duration: 600, room: room))
        try guest.save()

        let summary = try GuestImporter.importData(from: guest, into: account, accountID: UUID())

        #expect(summary == GuestImporter.Summary(rooms: 1, sessions: 1))
        let copy = try #require(try account.fetch(FetchDescriptor<PracticeRoom>()).first)
        #expect(copy.name == "Smoothie")
        #expect(copy.genre == .kpop)
        #expect(copy.needsSync)
        // Its own file name, never the guest's, so deleting one room can't take the other's video.
        #expect(copy.videoFileName != room.videoFileName)
        #expect(copy.sessions.count == 1)
        #expect(try guest.fetchCount(FetchDescriptor<PracticeRoom>()) == 1)
    }

    @Test func importingAgainUpdatesInsteadOfDuplicating() throws {
        let guest = try makeContext(), account = try makeContext()
        let accountID = UUID()
        let room = PracticeRoom(name: "Smoothie", videoFileName: "missing.mov")
        guest.insert(room)
        try guest.save()
        _ = try GuestImporter.importData(from: guest, into: account, accountID: accountID)

        room.name = "Smoothie 副歌"
        room.updatedAt = Date.now.addingTimeInterval(60).roundedToMilliseconds
        guest.insert(PracticeSession(startedAt: .now, duration: 300, room: room))
        try guest.save()
        let second = try GuestImporter.importData(from: guest, into: account, accountID: accountID)

        #expect(second == GuestImporter.Summary(rooms: 0, sessions: 1))
        let rooms = try account.fetch(FetchDescriptor<PracticeRoom>())
        #expect(rooms.count == 1)
        #expect(rooms.first?.name == "Smoothie 副歌")
    }

    @Test func laterAccountEditsSurviveAReimport() throws {
        let guest = try makeContext(), account = try makeContext()
        let accountID = UUID()
        guest.insert(PracticeRoom(name: "Smoothie", videoFileName: "missing.mov"))
        try guest.save()
        _ = try GuestImporter.importData(from: guest, into: account, accountID: accountID)

        let copy = try #require(try account.fetch(FetchDescriptor<PracticeRoom>()).first)
        copy.name = "Renamed in the account"
        copy.updatedAt = Date.now.addingTimeInterval(60).roundedToMilliseconds
        _ = try GuestImporter.importData(from: guest, into: account, accountID: accountID)

        #expect(copy.name == "Renamed in the account")
    }
}
