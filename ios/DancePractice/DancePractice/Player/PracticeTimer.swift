//
//  PracticeTimer.swift
//  DancePractice
//

import Foundation

/// One finished stretch of practice, handed from the player to whoever stores it.
struct PracticeRecord: Equatable {
    let startedAt: Date
    let duration: TimeInterval
}

/// Adds up wall-clock time while the video is actually playing; pauses and scrubbing don't count.
/// Takes `now` as a parameter so tests don't depend on the clock.
struct PracticeTimer {
    /// Shorter sessions are dropped so a quick peek doesn't count as practice.
    static let minimumDuration: TimeInterval = 10

    private var startedAt: Date?
    private var runningSince: Date?
    private var accumulated: TimeInterval = 0

    var isRunning: Bool { runningSince != nil }

    mutating func start(at now: Date) {
        guard runningSince == nil else { return }
        if startedAt == nil { startedAt = now }
        runningSince = now
    }

    mutating func stop(at now: Date) {
        guard let runningSince else { return }
        accumulated += max(0, now.timeIntervalSince(runningSince))
        self.runningSince = nil
    }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    /// Ends the session and resets. Returns nil if it was too short to keep.
    /// Keeps running if it was running, so playback that continues starts a fresh session.
    mutating func finish(at now: Date) -> PracticeRecord? {
        let wasRunning = isRunning
        let duration = elapsed(at: now)
        let record = startedAt.flatMap { start in
            duration >= Self.minimumDuration ? PracticeRecord(startedAt: start, duration: duration) : nil
        }
        self = PracticeTimer()
        if wasRunning { start(at: now) }
        return record
    }
}
