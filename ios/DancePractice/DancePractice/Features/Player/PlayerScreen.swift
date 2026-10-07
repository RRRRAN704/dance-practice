//
//  PlayerScreen.swift
//  DancePractice
//

import SwiftUI

struct PlayerScreen: View {
    let videoURL: URL
    let title: String

    @State private var viewModel = PlayerViewModel()
    @State private var isFullscreen = false
    @State private var controlsVisible = true
    @State private var hideControlsTask: Task<Void, Never>?
    /// Remembered across videos and launches: someone who pins once usually wants it every time.
    @AppStorage("player.keepControlsVisible") private var keepControlsVisible = false
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?
    /// Last portrait/landscape device orientation, for rotate-to-fullscreen.
    @State private var lastDeviceOrientation: UIDeviceOrientation = .portrait

    private static let autoHideDelay: Duration = .seconds(3)

    /// Compact height means the phone is in landscape.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        Group {
            if isFullscreen {
                fullscreenLayout
            } else {
                regularLayout
            }
        }
        .background(Theme.playerBackground.ignoresSafeArea())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Placeholder for the more-options menu.
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: { Image(systemName: "ellipsis") }
                    .disabled(true)
            }
        }
        .toolbar(isFullscreen ? .hidden : .visible, for: .navigationBar)
        .statusBarHidden(isFullscreen)
        .persistentSystemOverlays(isFullscreen ? .hidden : .automatic)
        .task { await viewModel.load(url: videoURL) }
        .onChange(of: viewModel.isPlaying) { _, isPlaying in
            if isPlaying {
                scheduleAutoHide()
            } else {
                showControls()
            }
        }
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            if FullscreenRotation.isTracked(UIDevice.current.orientation) {
                lastDeviceOrientation = UIDevice.current.orientation
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            handleDeviceRotation(UIDevice.current.orientation)
        }
        .onDisappear {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            viewModel.pause()
            setFullscreen(false)
        }
        .alert(
            "出错了",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            ),
            presenting: viewModel.errorMessage
        ) { _ in
            Button("好") {}
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Layouts

    private var regularLayout: some View {
        VStack(spacing: 16) {
            video
                .overlay(alignment: .bottomTrailing) {
                    Button { setFullscreen(true) } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.black.opacity(0.45)))
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .accessibilityLabel("全屏")
                }

            VStack(spacing: 14) {
                PlayerTimeline(viewModel: viewModel)
                PlayerSpeedSlider(viewModel: viewModel)

                HStack(spacing: 10) {
                    MirrorButton(viewModel: viewModel)
                    LoopButton(viewModel: viewModel)
                    MetronomeButton()
                }

                HStack(spacing: 12) {
                    SegmentListButton()
                    PlayButton(isPlaying: viewModel.isPlaying, action: viewModel.togglePlayPause)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var fullscreenLayout: some View {
        ZStack {
            video
                .ignoresSafeArea()

            FullscreenControls(
                viewModel: viewModel,
                title: title,
                isLandscape: verticalSizeClass == .compact,
                isPinned: keepControlsVisible,
                onTogglePin: togglePin,
                onExit: { setFullscreen(false) }
            )
            // Any touch on the controls (including long scrubs and A/B drags) holds the timer;
            // it restarts when the finger lifts.
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in hideControlsTask?.cancel() }
                    .onEnded { _ in scheduleAutoHide() }
            )
            .opacity(controlsVisible ? 1 : 0)
            .allowsHitTesting(controlsVisible)

            if let toastMessage {
                Text(toastMessage)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.65)))
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
    }

    private var video: some View {
        VideoSurface(player: viewModel.player)
            .scaleEffect(x: viewModel.isMirrored ? -1 : 1, y: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture(perform: handleVideoTap)
    }

    // MARK: - Fullscreen

    /// Landscape videos rotate the interface; portrait videos stay upright and just fill the screen.
    private func setFullscreen(_ fullscreen: Bool) {
        isFullscreen = fullscreen
        OrientationLock.set(fullscreen && !viewModel.isPortraitVideo ? .landscape : .portrait)
        scheduleAutoHide()
    }

    private func handleDeviceRotation(_ orientation: UIDeviceOrientation) {
        guard FullscreenRotation.isTracked(orientation) else { return }
        let action = FullscreenRotation.action(
            previous: lastDeviceOrientation,
            current: orientation,
            isFullscreen: isFullscreen,
            isPortraitVideo: viewModel.isPortraitVideo
        )
        lastDeviceOrientation = orientation
        switch action {
        case .enter: setFullscreen(true)
        case .exit: setFullscreen(false)
        case .none: break
        }
    }

    /// In fullscreen with the controls hidden, the first tap only brings them back.
    private func handleVideoTap() {
        if isFullscreen && !controlsVisible {
            scheduleAutoHide()
        } else {
            viewModel.togglePlayPause()
        }
    }

    // MARK: - Auto-hide

    /// Shows the controls and, while playing in fullscreen, hides them after `autoHideDelay`.
    private func scheduleAutoHide() {
        showControls()
        guard isFullscreen, viewModel.isPlaying, !keepControlsVisible else { return }
        hideControlsTask = Task {
            try? await Task.sleep(for: Self.autoHideDelay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { controlsVisible = false }
        }
    }

    private func togglePin() {
        keepControlsVisible.toggle()
        showToast(keepControlsVisible ? "控件已固定" : "已取消固定")
        scheduleAutoHide()
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) { toastMessage = message }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { toastMessage = nil }
        }
    }

    private func showControls() {
        hideControlsTask?.cancel()
        hideControlsTask = nil
        if !controlsVisible {
            withAnimation(.easeInOut(duration: 0.2)) { controlsVisible = true }
        }
    }
}
