//
//  PasswordField.swift
//  DancePractice
//

import SwiftUI

/// A secure field in the app's style, optionally with an eye button that shows what was typed.
struct PasswordField: View {
    let placeholder: LocalizedStringResource
    @Binding var text: String
    var contentType: UITextContentType = .password
    var allowsReveal = false

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if isRevealed {
                    TextField(text: $text) { Text(placeholder) }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(text: $text) { Text(placeholder) }
                }
            }
            .textContentType(contentType)

            if allowsReveal {
                Button { isRevealed.toggle() } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(isRevealed ? "Hide Password" : "Show Password"))
            }
        }
        .appFieldChrome()
        // Hide again if the reveal option goes away, e.g. switching from sign-in to sign-up.
        .onChange(of: allowsReveal) { _, allowed in
            if !allowed { isRevealed = false }
        }
    }
}

#Preview {
    @Previewable @State var password = "secret123"
    VStack(spacing: 16) {
        PasswordField(placeholder: "Enter password", text: $password, allowsReveal: true)
        PasswordField(placeholder: "At least 8 characters", text: $password, contentType: .newPassword)
    }
    .padding()
}
