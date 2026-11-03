//
//  LabeledField.swift
//  DancePractice
//

import SwiftUI

/// A small label above a form control; required fields get a red asterisk.
struct LabeledField<Content: View>: View {
    let title: LocalizedStringResource
    var isRequired = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                Text(title)
                if isRequired {
                    Text("*").foregroundStyle(.red)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            content
        }
    }
}

#Preview {
    @Previewable @State var name = ""
    LabeledField(title: "Room Name", isRequired: true) {
        TextField("e.g. Smoothie", text: $name)
            .textFieldStyle(.app)
    }
    .padding()
}
