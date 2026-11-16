//
//  BeatCountBadge.swift
//  DancePractice
//

import SwiftUI

/// The current count (1–8) over the video, with a dot per count of the eight.
/// It pops at the start of each beat; the "1" is in the accent colour so each new eight stands out.
struct BeatCountBadge: View {
    let position: BeatPosition

    var body: some View {
        VStack(spacing: 6) {
            Text(verbatim: String(position.count))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(position.count == 1 ? Theme.accent : .white)
                .scaleEffect(pop)

            HStack(spacing: 4) {
                ForEach(1...BeatGrid.countsPerEight, id: \.self) { count in
                    Circle()
                        .fill(count <= position.count ? Theme.accent : Color.white.opacity(0.25))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.5)))
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(Text("Count \(position.count)"))
    }

    /// Larger right on the beat, settling back over the first quarter of it.
    private var pop: CGFloat {
        1 + 0.15 * max(0, 1 - position.phase / 0.25)
    }
}

#Preview {
    HStack {
        BeatCountBadge(position: BeatPosition(count: 1, phase: 0))
        BeatCountBadge(position: BeatPosition(count: 5, phase: 0.6))
    }
    .padding()
    .background(Color.gray)
}
