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
        .onDisappear {
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
                onExit: { setFullscreen(false) }
            )
        }
    }

    private var video: some View {
        VideoSurface(player: viewModel.player)
            .scaleEffect(x: viewModel.isMirrored ? -1 : 1, y: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { viewModel.togglePlayPause() }
    }

    // MARK: - Fullscreen

    /// Landscape videos rotate the interface; portrait videos stay upright and just fill the screen.
    private func setFullscreen(_ fullscreen: Bool) {
        isFullscreen = fullscreen
        OrientationLock.set(fullscreen && !viewModel.isPortraitVideo ? .landscape : .portrait)
    }
}
