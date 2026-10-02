//
//  PlayerViewModel.swift
//  DancePractice
//

import AVFoundation
import Observation

/// Player screen state: speed, mirror and A-B loop. Delegates playback to `PlayerEngine`.
@Observable
@MainActor
final class PlayerViewModel {
    nonisolated static let speedRange: ClosedRange<Double> = 0.25...2.0
    nonisolated static let speedStep: Double = 0.05
    static let skipInterval: Double = 5

    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var isPlaying = false
    private(set) var speed: Double = 1.0
    private(set) var isMirrored = false
    private(set) var markA: Double?
    private(set) var markB: Double?
    private(set) var isLoopEnabled = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let engine = PlayerEngine()
    @ObservationIgnored private var isScrubbing = false

    var player: AVPlayer { engine.player }

    var loopRange: LoopRange? {
        guard let markA, let markB else { return nil }
        return LoopRange(start: markA, end: markB, duration: duration)
    }

    init() {
        engine.onTimeChange = { [weak self] time in
            guard let self, !self.isScrubbing else { return }
            self.currentTime = time
        }
        engine.onPlayingChange = { [weak self] isPlaying in
            self?.isPlaying = isPlaying
        }
    }

    // MARK: - Playback

    func load(url: URL) async {
        do {
            duration = try await engine.load(url: url)
            currentTime = 0
            markA = nil
            markB = nil
            isLoopEnabled = false
            engine.setRate(Float(speed))
        } catch {
            errorMessage = "视频加载失败：\(error.localizedDescription)"
        }
    }

    func togglePlayPause() {
        isPlaying ? engine.pause() : engine.play()
    }

    func pause() {
        engine.pause()
    }

    func skip(by delta: Double) {
        seek(to: currentTime + delta)
    }

    func seek(to time: Double) {
        currentTime = clampToDuration(time)
        engine.seek(to: currentTime)
    }

    func beginScrubbing() {
        isScrubbing = true
    }

    func scrub(to time: Double) {
        seek(to: time)
    }

    func endScrubbing() {
        isScrubbing = false
    }

    // MARK: - Speed & mirror

    func setSpeed(_ value: Double) {
        speed = Self.normalizedSpeed(value)
        engine.setRate(Float(speed))
    }

    /// Clamps to `speedRange` and snaps to `speedStep`.
    nonisolated static func normalizedSpeed(_ value: Double) -> Double {
        let clamped = min(max(value, speedRange.lowerBound), speedRange.upperBound)
        let snapped = (clamped / speedStep).rounded() * speedStep
        return (snapped * 100).rounded() / 100
    }

    func toggleMirror() {
        isMirrored.toggle()
    }

    // MARK: - A-B loop

    /// Sets A at the current time. Drops B if it would no longer form a valid segment.
    func setMarkA() {
        markA = currentTime
        if let markB, LoopRange(start: currentTime, end: markB, duration: duration) == nil {
            self.markB = nil
        }
        syncLoop()
    }

    /// Sets B at the current time. Without A, the loop starts from 0.
    /// Returns false if B would not be after A.
    @discardableResult
    func setMarkB() -> Bool {
        guard let range = LoopRange(start: markA ?? 0, end: currentTime, duration: duration) else {
            return false
        }
        markA = range.start
        markB = range.end
        syncLoop()
        return true
    }

    func toggleLoop() {
        guard loopRange != nil else { return }
        isLoopEnabled.toggle()
        syncLoop()
    }

    func clearLoop() {
        markA = nil
        markB = nil
        isLoopEnabled = false
        syncLoop()
    }

    // MARK: - Private

    private func syncLoop() {
        if loopRange == nil {
            isLoopEnabled = false
        }
        engine.setLoop(isLoopEnabled ? loopRange : nil)
    }

    private func clampToDuration(_ time: Double) -> Double {
        min(max(time, 0), duration)
    }
}
