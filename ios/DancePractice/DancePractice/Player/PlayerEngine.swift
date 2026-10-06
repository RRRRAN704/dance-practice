//
//  PlayerEngine.swift
//  DancePractice
//

import AVFoundation

/// Wraps `AVPlayer`. This is the only type that drives AVFoundation playback;
/// it knows nothing about SwiftUI and reports state through callbacks.
@MainActor
final class PlayerEngine {
    let player = AVPlayer()

    var onTimeChange: ((Double) -> Void)?
    var onPlayingChange: ((Bool) -> Void)?

    private var periodicObserver: Any?
    private var boundaryObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var loop: LoopRange?
    private var duration: Double = 0

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        player.actionAtItemEnd = .pause

        periodicObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0 / 30, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated { self?.handleTick(time.seconds) }
        }

        statusObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let isPlaying = player.timeControlStatus != .paused
            Task { @MainActor in self?.onPlayingChange?(isPlaying) }
        }
    }

    var currentTime: Double {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    /// Loads a local video and returns its duration in seconds.
    func load(url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let loadedDuration = try await asset.load(.duration).seconds

        let item = AVPlayerItem(asset: asset)
        // Keep the original pitch when slowing down; spectral sounds best for music.
        item.audioTimePitchAlgorithm = .spectral

        setLoop(nil)
        player.replaceCurrentItem(with: item)
        duration = loadedDuration.isFinite ? loadedDuration : 0
        observeEnd(of: item)
        return duration
    }

    func play() {
        if let loop, !loop.contains(currentTime) {
            seek(to: loop.start)
        } else if duration > 0, currentTime >= duration - 0.05 {
            seek(to: 0)
        }
        player.play()
    }

    func pause() {
        player.pause()
    }

    /// Frame-accurate seek, needed for scrubbing and A-B precision.
    func seek(to seconds: Double) {
        player.seek(
            to: CMTime(seconds: seconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    func setRate(_ rate: Float) {
        player.defaultRate = rate
        if player.rate != 0 {
            // Restarting at the new rate keeps video in sync; setting `rate` mid-playback can stall frames.
            player.playImmediately(atRate: rate)
        }
    }

    /// Pass nil to stop looping.
    func setLoop(_ range: LoopRange?) {
        if let boundaryObserver {
            player.removeTimeObserver(boundaryObserver)
            self.boundaryObserver = nil
        }
        loop = range
        guard let range else { return }

        let end = NSValue(time: CMTime(seconds: range.end, preferredTimescale: 600))
        boundaryObserver = player.addBoundaryTimeObserver(forTimes: [end], queue: .main) { [weak self] in
            MainActor.assumeIsolated { self?.jumpToLoopStart() }
        }
        if !range.contains(currentTime) {
            seek(to: range.start)
        }
    }

    // MARK: - Private

    private func handleTick(_ seconds: Double) {
        guard seconds.isFinite else { return }
        // Fallback for when playback ends up past B without crossing the boundary (e.g. after a seek).
        if let loop, player.rate != 0, seconds > loop.end + 0.1 {
            jumpToLoopStart()
        }
        onTimeChange?(seconds)
    }

    private func jumpToLoopStart() {
        guard let loop else { return }
        seek(to: loop.start)
    }

    private func observeEnd(of item: AVPlayerItem) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                // When B sits at the very end, the boundary may not fire; restart the loop here.
                guard let self, let loop = self.loop else { return }
                self.seek(to: loop.start)
                self.player.play()
            }
        }
    }
}
