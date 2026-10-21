//
//  LabeledField.swift
//  DancePractice
//

import SwiftUI

/// A small label above a form control; required fields get a red asterisk.
struct LabeledField<Content: View>: View {
    let title: String
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
    LabeledField(title: "练习室名称", isRequired: true) {
        TextField("例如：Smoothie", text: $name)
            .textFieldStyle(.app)
    }
    .padding()
}
