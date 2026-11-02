//
//  AuthSheet.swift
//  DancePractice
//

import SwiftUI

/// Login and register share one form; the chips at the top switch between them.
struct AuthSheet: View {
    enum Mode: CaseIterable, Identifiable {
        case login, register

        var id: Self { self }

        var title: String {
            switch self {
            case .login: "登录"
            case .register: "注册"
            }
        }
    }

    /// Matches the backend's RegisterRequest: BCrypt only reads 72 bytes.
    static let passwordLength = 8...72

    @Environment(AccountManager.self) private var accounts
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("登录后，练习室和练习记录会同步到云端，换手机也不会丢。视频文件只保存在本机。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        ForEach(Mode.allCases) { option in
                            SelectableChip(title: option.title, isSelected: mode == option, fillsWidth: true) {
                                mode = option
                                errorMessage = nil
                            }
                        }
                    }

                    LabeledField(title: "邮箱") {
                        TextField("name@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.app)
                    }

                    LabeledField(title: "密码") {
                        // The eye is login-only: when registering, the confirmation field catches typos.
                        PasswordField(placeholder: mode == .register ? "至少 8 位" : "输入密码",
                                      text: $password,
                                      contentType: mode == .register ? .newPassword : .password,
                                      allowsReveal: mode == .login)
                            .onSubmit(submit)
                    }

                    if mode == .register {
                        LabeledField(title: "确认密码") {
                            PasswordField(placeholder: "再输入一次密码", text: $confirmation,
                                          contentType: .newPassword)
                                .onSubmit(submit)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemBackground))
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: isSubmitting ? "请稍候…" : mode.title, action: submit)
                    .disabled(!canSubmit)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .background(Color(.systemBackground))
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Theme.fieldFill))
                    }
                    .accessibilityLabel("取消")
                }
            }
            .interactiveDismissDisabled(isSubmitting)
        }
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !isSubmitting && !trimmedEmail.isEmpty && !password.isEmpty
            && (mode == .login || !confirmation.isEmpty)
    }

    private func submit() {
        guard canSubmit else { return }
        if let problem = Self.validationProblem(email: trimmedEmail, password: password,
                                                     confirmation: confirmation, mode: mode) {
            errorMessage = problem
            return
        }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                switch mode {
                case .login: try await accounts.login(email: trimmedEmail, password: password)
                case .register: try await accounts.register(email: trimmedEmail, password: password)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    /// Checked before sending, so the common mistakes get a Chinese message without a round trip.
    static func validationProblem(email: String, password: String, confirmation: String = "",
                                  mode: Mode) -> String? {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        if parts.count != 2 || parts[0].isEmpty || !parts[1].contains(".") {
            return "请输入有效的邮箱地址"
        }
        if mode == .register && !passwordLength.contains(password.count) {
            return "密码需要 \(passwordLength.lowerBound)–\(passwordLength.upperBound) 位"
        }
        if mode == .register && password != confirmation {
            return "两次输入的密码不一致"
        }
        return nil
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AuthSheet()
        }
        .environment(AccountManager())
}
