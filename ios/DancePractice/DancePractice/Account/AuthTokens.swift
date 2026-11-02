//
//  AuthTokens.swift
//  DancePractice
//

import Foundation

/// The body of POST /api/auth/login, /register and /refresh.
struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    /// Access token lifetime in seconds.
    let expiresIn: Double
}

/// The body of GET /api/me (createdAt is left out; the app doesn't show it).
struct UserResponse: Decodable {
    let id: UUID
    let email: String
}

/// Everything kept in the Keychain for the signed-in account.
struct StoredCredentials: Codable, Equatable {
    var userId: UUID
    var email: String
    var accessToken: String
    var refreshToken: String
    var accessExpiresAt: Date

    /// Refresh a little early so a token doesn't expire while a request is in flight.
    static let refreshMargin: TimeInterval = 60

    func accessTokenNeedsRefresh(now: Date) -> Bool {
        now.addingTimeInterval(Self.refreshMargin) >= accessExpiresAt
    }

    /// Takes the new pair from a refresh; the old refresh token is now revoked on the server.
    func replacingTokens(with response: TokenResponse, now: Date) -> StoredCredentials {
        var copy = self
        copy.accessToken = response.accessToken
        copy.refreshToken = response.refreshToken
        copy.accessExpiresAt = now.addingTimeInterval(response.expiresIn)
        return copy
    }
}
