//
//  APIError.swift
//  DancePractice
//

import Foundation

/// What can go wrong talking to the backend, with messages ready to show the user.
enum APIError: Error, Equatable {
    /// No connection, timeout, or the server isn't running.
    case offline
    /// 401: the token is missing, expired or revoked. On login it means a wrong password instead;
    /// `AccountManager` translates it there.
    case unauthorized
    /// Any other non-2xx answer; `message` comes from the ProblemDetail body when there is one.
    case server(status: Int, message: String?)
    case unreadableResponse

    /// The backend sends RFC 9457 problem+json: `detail`, plus `errors` (field → message) on 400s.
    private struct ProblemDetail: Decodable {
        let detail: String?
        let errors: [String: String]?
    }

    init(status: Int, body: Data) {
        if status == 401 {
            self = .unauthorized
            return
        }
        let problem = try? JSONDecoder().decode(ProblemDetail.self, from: body)
        // A field message ("must be a well-formed email address") says more than the generic detail.
        let message = problem?.errors?.values.sorted().first ?? problem?.detail
        self = .server(status: status, message: message)
    }
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .offline:
            String(localized: "Can't reach the server. Check your connection.")
        case .unauthorized:
            String(localized: "Your session has expired. Please sign in again.")
        case .server(let status, let message):
            status >= 500
                ? String(localized: "Something went wrong on the server. Please try again later.")
                : message ?? String(localized: "Request failed (\(status))")
        case .unreadableResponse:
            String(localized: "The server sent a response the app couldn't read.")
        }
    }
}
