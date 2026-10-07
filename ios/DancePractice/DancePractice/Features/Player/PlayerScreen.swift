//
//  PlayerScreen.swift
//  DancePractice
//

import SwiftUI

struct PlayerScreen: View {
    let videoURL: URL
    let title: String

    @State private var viewModel = PlayerViewModel()

    var body: some View {
        VStack(spacing: 16) {
            VideoSurface(player: viewModel.player)
                .scaleEffect(x: viewModel.isMirrored ? -1 : 1, y: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .clipped()
                .onTapGesture { viewModel.togglePlayPause() }

            VStack(spacing: 14) {
                TimelineBar(
                    currentTime: viewModel.currentTime,
                    duration: viewModel.duration,
                    markA: viewModel.markA,
                    markB: viewModel.markB,
                    isLoopEnabled: viewModel.isLoopEnabled,
                    thumbnails: viewModel.thumbnails,
                    onScrubBegan: viewModel.beginScrubbing,
                    onScrub: viewModel.scrub(to:),
                    onScrubEnded: viewModel.endScrubbing,
                    onHandleDragBegan: viewModel.beginHandleDrag,
                    onMoveHandle: viewModel.moveHandle(_:to:),
                    onHandleDragEnded: viewModel.endHandleDrag
                )

                SpeedSlider(
                    speed: Binding(get: { viewModel.speed }, set: { viewModel.setSpeed($0) }),
                    range: PlayerViewModel.speedRange,
                    step: PlayerViewModel.speedStep
                )

                HStack(spacing: 10) {
                    ControlButton(
                        title: "镜面",
                        systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                        isActive: viewModel.isMirrored,
                        action: viewModel.toggleMirror
                    )
                    ControlButton(
                        title: "A-B 循环",
                        systemImage: "repeat",
                        isActive: viewModel.isLoopEnabled,
                        action: viewModel.toggleLoop
                    )
                    // Placeholder until the metronome step.
                    ControlButton(title: "节拍", systemImage: "music.note") {}
                        .disabled(true)
                }

                HStack(spacing: 12) {
                    // Placeholder for the saved-segments list.
                    Button {} label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .frame(width: 56, height: 56)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel))
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                    .opacity(0.4)
                    .accessibilityLabel("片段列表")

                    PlayButton(isPlaying: viewModel.isPlaying, action: viewModel.togglePlayPause)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
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
        .task { await viewModel.load(url: videoURL) }
        .onDisappear { viewModel.pause() }
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
}
