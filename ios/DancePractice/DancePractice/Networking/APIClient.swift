//
//  APIClient.swift
//  DancePractice
//

import Foundation

/// One HTTP call to the backend. Knows nothing about tokens; `AccountManager` adds them.
struct Endpoint {
    enum Method: String {
        case get = "GET", post = "POST", delete = "DELETE"
    }

    let method: Method
    let path: String
    var body: Data?

    static func get(_ path: String) -> Endpoint {
        Endpoint(method: .get, path: path)
    }

    static func delete(_ path: String) -> Endpoint {
        Endpoint(method: .delete, path: path)
    }

    static func post(_ path: String, json: some Encodable) -> Endpoint {
        // Encoding our own request types can't fail.
        Endpoint(method: .post, path: path, body: try! APIClient.encoder.encode(json))
    }
}

/// Thin wrapper over URLSession: builds the request, checks the status, decodes the JSON.
struct APIClient {
    #if DEBUG
    /// The simulator reaches the Mac's localhost directly; see backend/README.md.
    static let defaultBaseURL = URL(string: "http://localhost:8080")!
    #else
    static let defaultBaseURL = URL(string: "https://api.example.com")!
    #endif

    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()

    var baseURL = defaultBaseURL
    var session = URLSession.shared

    func send<Response: Decodable>(_ endpoint: Endpoint, accessToken: String? = nil) async throws -> Response {
        let data = try await data(for: endpoint, accessToken: accessToken)
        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.unreadableResponse
        }
    }

    /// For calls that answer 204 No Content.
    func send(_ endpoint: Endpoint, accessToken: String? = nil) async throws {
        _ = try await data(for: endpoint, accessToken: accessToken)
    }

    private func data(for endpoint: Endpoint, accessToken: String?) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: endpoint.path))
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 20
        if let body = endpoint.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.offline
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw APIError(status: status, body: data)
        }
        return data
    }
}
