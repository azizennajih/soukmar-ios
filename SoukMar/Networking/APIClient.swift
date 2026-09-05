import Foundation

enum APIError: Error {
    case server(message: String, unverified: Bool)
    case network(String)
    case decoding
}

/// Thin URLSession wrapper mirroring soukmar-android's Retrofit ApiService —
/// same base URL split (dev vs. release) and the same "parse the backend's
/// {error, unverified?} body on failure" convention as ApiErrorDto there.
final class APIClient {
    static let shared = APIClient()

    #if DEBUG
    // iOS Simulator shares the Mac's own network stack, so the backend dev
    // server is reachable via localhost directly — unlike the Android
    // emulator, which needs the 10.0.2.2 host alias instead.
    private let baseURL = URL(string: "http://127.0.0.1:3000/api/")!
    #else
    private let baseURL = URL(string: "https://api.soukmar.ma/api/")!
    #endif

    private let session = URLSession.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var token: String? {
        get { TokenStore.shared.token }
        set { TokenStore.shared.token = newValue }
    }

    private func request(path: String, method: String, body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        return req
    }

    /// POST/PUT/PATCH with a Codable body, decoding a Codable response.
    func send<Body: Encodable, Response: Decodable>(
        path: String, method: String, body: Body
    ) async throws -> Response {
        let data = try encoder.encode(body)
        return try await perform(request(path: path, method: method, body: data))
    }

    /// GET (or any body-less call), decoding a Codable response.
    func send<Response: Decodable>(path: String, method: String = "GET") async throws -> Response {
        try await perform(request(path: path, method: method))
    }

    /// GET with query parameters (e.g. listing filters), decoding a Codable response.
    func send<Response: Decodable>(path: String, query: [String: String]) async throws -> Response {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var req = URLRequest(url: components.url!)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await perform(req)
    }

    /// Multipart/form-data upload (e.g. POST /api/upload's `images` field) —
    /// mirrors Android's UploadRepository, which builds the same kind of
    /// multipart request via OkHttp instead of URLSession.
    func upload<Response: Decodable>(
        path: String, fieldName: String, files: [(data: Data, filename: String, mimeType: String)]
    ) async throws -> Response {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        for file in files {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(file.filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        return try await perform(req)
    }

    private func perform<Response: Decodable>(_ req: URLRequest) async throws -> Response {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.network("Réponse invalide.")
        }

        guard (200..<300).contains(http.statusCode) else {
            let parsed = try? decoder.decode(ApiErrorDto.self, from: data)
            throw APIError.server(
                message: parsed?.error ?? "Une erreur est survenue.",
                unverified: parsed?.unverified ?? false
            )
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}
