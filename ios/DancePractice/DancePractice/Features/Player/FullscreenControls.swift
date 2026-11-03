//
//  FullscreenControls.swift
//  DancePractice
//

import SwiftUI

/// Controls drawn over fullscreen video: a top bar, and the timeline plus controls at the bottom.
/// Landscape puts everything in one bar; portrait uses a compact stack so most of the video stays visible.
struct FullscreenControls: View {
    let viewModel: PlayerViewModel
    let title: String
    let isLandscape: Bool
    /// Pinned controls never auto-hide.
    let isPinned: Bool
    let onTogglePin: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 0)
            bottomArea
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            OverlayIconButton(systemImage: "chevron.left", accessibilityLabel: "Exit Fullscreen", action: onExit)
            Spacer()
            OverlayIconButton(
                systemImage: isPinned ? "pin.fill" : "pin",
                accessibilityLabel: isPinned ? "Unpin Controls" : "Pin Controls",
                isActive: isPinned,
                action: onTogglePin
            )
            // Placeholder for the more-options menu.
            OverlayIconButton(systemImage: "ellipsis", accessibilityLabel: "More") {}
                .disabled(true)
        }
        // Centred on the screen regardless of how many buttons sit on each side.
        .overlay {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .padding(.horizontal, 104)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .background(
            LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private var bottomArea: some View {
        VStack(spacing: 12) {
            PlayerTimeline(viewModel: viewModel, style: .overlay)
                .padding(.horizontal, 16)

            if isLandscape {
                // Wide phones fit titles; narrow ones (e.g. iPhone SE) fall back to icons.
                ViewThatFits(in: .horizontal) {
                    landscapeBar(showsTitles: true)
                    landscapeBar(showsTitles: false)
                }
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 12) {
                    PlayerSpeedSlider(viewModel: viewModel, style: .compact)
                    HStack(spacing: 10) {
                        SegmentListButton(size: 48)
                        MirrorButton(viewModel: viewModel, showsTitle: false)
                            .frame(width: 48)
                        LoopButton(viewModel: viewModel, showsTitle: false)
                            .frame(width: 48)
                        MetronomeButton(showsTitle: false)
                            .frame(width: 48)
                        Spacer(minLength: 0)
                        PlayButton(isPlaying: viewModel.isPlaying, isCompact: true, action: viewModel.togglePlayPause)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private func landscapeBar(showsTitles: Bool) -> some View {
        HStack(spacing: 8) {
            SegmentListButton(size: 48)
            MirrorButton(viewModel: viewModel, showsTitle: showsTitles)
                .frame(width: showsTitles ? 88 : 48)
            barDivider
            PlayerSpeedSlider(viewModel: viewModel, style: .compact)
                .frame(minWidth: 160, maxWidth: 280)
            barDivider
            LoopButton(viewModel: viewModel, showsTitle: showsTitles)
                .frame(width: showsTitles ? 112 : 48)
            MetronomeButton(showsTitle: showsTitles)
                .frame(width: showsTitles ? 88 : 48)
            PlayButton(isPlaying: viewModel.isPlaying, action: viewModel.togglePlayPause)
                .frame(width: showsTitles ? 136 : 120)
        }
    }

    private var barDivider: some View {
        Rectangle()
            .fill(Theme.panelBorder)
            .frame(width: 1, height: 36)
    }
}
