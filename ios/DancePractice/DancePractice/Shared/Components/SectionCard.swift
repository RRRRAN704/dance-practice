//
//  SectionCard.swift
//  DancePractice
//

import SwiftUI

/// A titled card: heading on the left, an optional control on the right, content below.
struct SectionCard<Accessory: View, Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                accessory
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
    }
}

extension SectionCard where Accessory == EmptyView {
    init(title: LocalizedStringResource, @ViewBuilder content: () -> Content) {
        self.init(title: title, accessory: { EmptyView() }, content: content)
    }
}

#Preview {
    SectionCard(title: "Practice Trend") {
        Text("Last 7 Days").font(.subheadline).foregroundStyle(.secondary)
    } content: {
        Rectangle().fill(.quaternary).frame(height: 120)
    }
    .padding()
    .background(Theme.background)
}
