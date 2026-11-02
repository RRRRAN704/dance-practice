//
//  PasswordField.swift
//  DancePractice
//

import SwiftUI

/// A secure field in the app's style, optionally with an eye button that shows what was typed.
struct PasswordField: View {
    let placeholder: String
    @Binding var text: String
    var contentType: UITextContentType = .password
    var allowsReveal = false

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if isRevealed {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(placeholder, text: $text)
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
                .accessibilityLabel(isRevealed ? "隐藏密码" : "显示密码")
            }
        }
        .appFieldChrome()
        // Hide again if the reveal option goes away, e.g. switching from 登录 to 注册.
        .onChange(of: allowsReveal) { _, allowed in
            if !allowed { isRevealed = false }
        }
    }
}

#Preview {
    @Previewable @State var password = "secret123"
    VStack(spacing: 16) {
        PasswordField(placeholder: "输入密码", text: $password, allowsReveal: true)
        PasswordField(placeholder: "至少 8 位", text: $password, contentType: .newPassword)
    }
    .padding()
}
