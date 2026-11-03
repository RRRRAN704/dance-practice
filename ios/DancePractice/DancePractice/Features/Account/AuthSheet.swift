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

        var title: LocalizedStringResource {
            switch self {
            case .login: "Sign In"
            case .register: "Sign Up"
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
                    Text("Signed in, your rooms and practice history sync to the cloud, so a new phone won't lose them. Videos stay on this device.")
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

                    LabeledField(title: "Email") {
                        TextField("name@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.app)
                    }

                    LabeledField(title: "Password") {
                        // The eye is login-only: when registering, the confirmation field catches typos.
                        PasswordField(placeholder: mode == .register ? "At least 8 characters" : "Enter password",
                                      text: $password,
                                      contentType: mode == .register ? .newPassword : .password,
                                      allowsReveal: mode == .login)
                            .onSubmit(submit)
                    }

                    if mode == .register {
                        LabeledField(title: "Confirm Password") {
                            PasswordField(placeholder: "Enter the password again", text: $confirmation,
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
                PrimaryButton(title: isSubmitting ? "Please wait…" : mode.title, action: submit)
                    .disabled(!canSubmit)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .background(Color(.systemBackground))
            }
            .navigationTitle(Text(mode.title))
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
                    .accessibilityLabel("Cancel")
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

    /// Checked before sending, so the common mistakes get a friendly message without a round trip.
    static func validationProblem(email: String, password: String, confirmation: String = "",
                                  mode: Mode) -> String? {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        if parts.count != 2 || parts[0].isEmpty || !parts[1].contains(".") {
            return String(localized: "Please enter a valid email address")
        }
        if mode == .register && !passwordLength.contains(password.count) {
            return String(localized: "Password must be \(passwordLength.lowerBound)–\(passwordLength.upperBound) characters")
        }
        if mode == .register && password != confirmation {
            return String(localized: "The passwords don't match")
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
