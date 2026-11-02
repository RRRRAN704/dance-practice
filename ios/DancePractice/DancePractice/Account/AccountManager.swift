//
//  AccountManager.swift
//  DancePractice
//

import Foundation
import Observation

/// Who is signed in, and the only place that touches their tokens.
///
/// Every authorized call goes through `send(_:)`, which refreshes the access token when it is
/// about to expire and retries once on a 401. Refreshes are single-flight: requests that find the
/// token stale at the same time all wait for one refresh, because the server rotates refresh
/// tokens and treats a second use of the old one as theft (it revokes the whole login).
@Observable
@MainActor
final class AccountManager {
    struct Account: Equatable {
        let id: UUID
        let email: String
    }

    /// nil = guest.
    private(set) var account: Account?

    @ObservationIgnored private let api: APIClient
    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private var credentials: StoredCredentials?
    @ObservationIgnored private var refreshTask: Task<StoredCredentials, Error>?

    private static let credentialsKey = "credentials"

    init(api: APIClient = APIClient(), keychain: KeychainStore = KeychainStore(service: "DancePractice.account")) {
        self.api = api
        self.keychain = keychain
        // Signed in straight away from the Keychain, even offline; `verifyAccount()` checks it later.
        if let data = keychain.data(for: Self.credentialsKey),
           let stored = try? JSONDecoder().decode(StoredCredentials.self, from: data) {
            credentials = stored
            account = Account(id: stored.userId, email: stored.email)
        }
    }

    // MARK: Signing in and out

    func login(email: String, password: String) async throws {
        do {
            let tokens: TokenResponse = try await api.send(
                .post("/api/auth/login", json: Credentials(email: email, password: password)))
            try await signIn(with: tokens)
        } catch APIError.unauthorized {
            throw AccountError.wrongCredentials
        }
    }

    func register(email: String, password: String) async throws {
        do {
            let tokens: TokenResponse = try await api.send(
                .post("/api/auth/register", json: Credentials(email: email, password: password)))
            try await signIn(with: tokens)
        } catch APIError.server(status: 409, message: _) {
            throw AccountError.emailTaken
        }
    }

    /// Signs out locally right away; telling the server is best effort, since the refresh token
    /// expires on its own anyway.
    func logout() async {
        let refreshToken = credentials?.refreshToken
        clearLocalAccount()
        if let refreshToken {
            try? await api.send(.post("/api/auth/logout", json: RefreshRequest(refreshToken: refreshToken)))
        }
    }

    /// Run at launch: signs out if the login was revoked or the account deleted elsewhere.
    /// Offline, the account stays signed in.
    func verifyAccount() async {
        guard account != nil else { return }
        do {
            let user: UserResponse = try await send(.get("/api/me"))
            if user.email != credentials?.email {
                credentials?.email = user.email
                saveCredentials()
                account = Account(id: user.id, email: user.email)
            }
        } catch APIError.unauthorized, APIError.server(status: 404, message: _) {
            clearLocalAccount()
        } catch {
            // Offline or a server hiccup: try again next launch.
        }
    }

    private func signIn(with tokens: TokenResponse) async throws {
        let user: UserResponse = try await api.send(.get("/api/me"), accessToken: tokens.accessToken)
        credentials = StoredCredentials(
            userId: user.id,
            email: user.email,
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            accessExpiresAt: .now.addingTimeInterval(tokens.expiresIn))
        saveCredentials()
        account = Account(id: user.id, email: user.email)
    }

    private func clearLocalAccount() {
        credentials = nil
        account = nil
        keychain.delete(Self.credentialsKey)
    }

    private func saveCredentials() {
        guard let credentials, let data = try? JSONEncoder().encode(credentials) else { return }
        keychain.set(data, for: Self.credentialsKey)
    }

    // MARK: Authorized requests

    /// - Parameter accountID: when given, the call fails with `AccountError.switchedAccount` unless
    ///   that account is still the signed-in one, so work started for one account (a sync) can't
    ///   go out with the next account's token.
    func send<Response: Decodable>(_ endpoint: Endpoint, as accountID: UUID? = nil) async throws -> Response {
        try await withAccessToken(for: accountID) { [api] token in
            try await api.send(endpoint, accessToken: token)
        }
    }

    func send(_ endpoint: Endpoint, as accountID: UUID? = nil) async throws {
        try await withAccessToken(for: accountID) { [api] token in
            try await api.send(endpoint, accessToken: token)
        }
    }

    private func withAccessToken<T>(for accountID: UUID?, _ call: (String) async throws -> T) async throws -> T {
        guard let current = credentials else { throw APIError.unauthorized }
        if let accountID, current.userId != accountID {
            throw AccountError.switchedAccount
        }
        let token = current.accessTokenNeedsRefresh(now: .now)
            ? try await refreshedCredentials().accessToken
            : current.accessToken
        do {
            return try await call(token)
        } catch APIError.unauthorized {
            // Rejected before its expiry, e.g. the server restarted with a new signing key.
            return try await call(refreshedCredentials().accessToken)
        }
    }

    private func refreshedCredentials() async throws -> StoredCredentials {
        if let refreshTask {
            return try await refreshTask.value
        }
        guard let current = credentials else { throw APIError.unauthorized }

        let task = Task { [api] in
            let tokens: TokenResponse = try await api.send(
                .post("/api/auth/refresh", json: RefreshRequest(refreshToken: current.refreshToken)))
            return current.replacingTokens(with: tokens, now: .now)
        }
        refreshTask = task
        defer { refreshTask = nil }

        do {
            let updated = try await task.value
            // The user may have logged out while the refresh was in flight.
            if credentials?.refreshToken == current.refreshToken {
                credentials = updated
                saveCredentials()
            }
            return updated
        } catch APIError.unauthorized {
            // The refresh token expired or was revoked: this login is over.
            clearLocalAccount()
            throw APIError.unauthorized
        }
    }
}

/// Auth failures worth their own message; everything else is an `APIError`.
enum AccountError: LocalizedError {
    case wrongCredentials
    case emailTaken
    /// Someone else signed in while work for the previous account was still running.
    case switchedAccount

    var errorDescription: String? {
        switch self {
        case .wrongCredentials: "邮箱或密码错误"
        case .emailTaken: "该邮箱已注册，请直接登录"
        case .switchedAccount: "账号已切换"
        }
    }
}

private struct Credentials: Encodable {
    let email: String
    let password: String
}

private struct RefreshRequest: Encodable {
    let refreshToken: String
}
