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
    // nonisolated(unsafe) so deinit can remove it; only touched on the main actor otherwise.
    nonisolated(unsafe) private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var loop: LoopRange?
    /// The video being played, kept so the click track can be mixed in later.
    private var asset: AVURLAsset?
    private var clickVolume: Float = 1
    private var duration: Double = 0
    private var isSeeking = false
    private var pendingSeek: Double?

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

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    var currentTime: Double {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    struct LoadedVideo {
        let duration: Double
        /// Size as displayed, after the track's rotation. Zero for audio-only files.
        let displaySize: CGSize
    }

    /// Loads a local video and returns its duration and display size.
    func load(url: URL) async throws -> LoadedVideo {
        let asset = AVURLAsset(url: url)
        let loadedDuration = try await asset.load(.duration).seconds
        var displaySize = CGSize.zero
        if let track = try await asset.loadTracks(withMediaType: .video).first {
            let (size, transform) = try await track.load(.naturalSize, .preferredTransform)
            displaySize = size.applying(transform)
        }

        let item = AVPlayerItem(asset: asset)
        // Keep the original pitch when slowing down; spectral sounds best for music.
        item.audioTimePitchAlgorithm = .spectral

        self.asset = asset
        setLoop(nil)
        player.replaceCurrentItem(with: item)
        duration = loadedDuration.isFinite ? loadedDuration : 0
        observeEnd(of: item)
        return LoadedVideo(duration: duration, displaySize: displaySize)
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
    /// Only one seek runs at a time; requests that arrive meanwhile collapse into the latest one.
    func seek(to seconds: Double) {
        guard !isSeeking else {
            pendingSeek = seconds
            return
        }
        isSeeking = true
        player.seek(
            to: CMTime(seconds: seconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] _ in
            Task { @MainActor in self?.seekDidFinish() }
        }
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

    // MARK: - Click track

    /// Plays the video with `clickTrack` mixed in as an extra audio track, or without one when nil.
    /// Because the clicks become part of the same item, speed, seeking and A-B loops apply to them
    /// exactly as to the music. Swapping the item keeps the position, play state, speed and loop.
    func setClickTrack(_ clickTrack: URL?) async throws {
        guard let asset else { return }
        let item: AVPlayerItem
        if let clickTrack {
            item = try await Self.itemWithClicks(video: asset, clicks: AVURLAsset(url: clickTrack))
        } else {
            item = AVPlayerItem(asset: asset)
        }
        item.audioTimePitchAlgorithm = .spectral
        item.audioMix = await clickMix(for: item)

        // Read after the await: playback carried on while the item was being built.
        let time = currentTime
        let wasPlaying = player.rate != 0
        player.replaceCurrentItem(with: item)
        observeEnd(of: item)
        seek(to: time)
        if wasPlaying {
            player.playImmediately(atRate: player.defaultRate)
        }
    }

    /// 0 silences the clicks without rebuilding anything.
    func setClickVolume(_ volume: Float) {
        clickVolume = volume
        guard let item = player.currentItem else { return }
        Task { item.audioMix = await clickMix(for: item) }
    }

    /// The video's own tracks plus the clicks, all over the video's full length.
    private static func itemWithClicks(video: AVURLAsset, clicks: AVURLAsset) async throws -> AVPlayerItem {
        let composition = AVMutableComposition()
        let duration = try await video.load(.duration)
        let range = CMTimeRange(start: .zero, duration: duration)

        for track in try await video.loadTracks(withMediaType: .video) {
            let copy = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            try copy?.insertTimeRange(range, of: track, at: .zero)
            // Without this, portrait phone videos would play sideways.
            copy?.preferredTransform = try await track.load(.preferredTransform)
        }
        for track in try await video.loadTracks(withMediaType: .audio) {
            let copy = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try copy?.insertTimeRange(range, of: track, at: .zero)
        }
        if let track = try await clicks.loadTracks(withMediaType: .audio).first {
            let clickDuration = try await clicks.load(.duration)
            let copy = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Self.clickTrackID)
            try copy?.insertTimeRange(CMTimeRange(start: .zero, duration: min(clickDuration, duration)), of: track, at: .zero)
        }
        return AVPlayerItem(asset: composition)
    }

    private static let clickTrackID: CMPersistentTrackID = 1_000

    /// Sets the click track's volume; nil when the item has no click track.
    private func clickMix(for item: AVPlayerItem) async -> AVAudioMix? {
        guard let track = try? await item.asset.loadTrack(withTrackID: Self.clickTrackID) else { return nil }
        let parameters = AVMutableAudioMixInputParameters(track: track)
        parameters.setVolume(clickVolume, at: .zero)
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        return mix
    }

    // MARK: - Private

    private func handleTick(_ seconds: Double) {
        // Ticks during a seek report the old position; skip them so the UI doesn't jump back.
        guard seconds.isFinite, !isSeeking else { return }
        // Fallback for when playback ends up past B without crossing the boundary (e.g. after a seek).
        if let loop, player.rate != 0, seconds > loop.end + 0.1 {
            jumpToLoopStart()
        }
        onTimeChange?(seconds)
    }

    private func seekDidFinish() {
        isSeeking = false
        if let next = pendingSeek {
            pendingSeek = nil
            seek(to: next)
        }
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
