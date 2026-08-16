import Foundation

enum APIError: LocalizedError {
    case badURL, invalidResponse, server(String)
    var errorDescription: String? {
        switch self {
        case .badURL: return "Неверный адрес сервера."
        case .invalidResponse: return "Некорректный ответ сервера."
        case .server(let value): return value
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private var baseURL: String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "BALI_GATEWAY_URL") as? String) ?? ""
        return raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func request<T: Decodable>(_ path: String, method: String = "GET", token: String? = nil, body: Data? = nil) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw APIError.server(message ?? "Ошибка сервера: \(http.statusCode)")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func register(fio: String, role: StaffRole, deviceId: String) async throws -> RegistrationResponse {
        let payload: [String: String] = ["fio": fio, "role": role.rawValue, "deviceId": deviceId]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try await request("/api/register", method: "POST", body: data)
    }

    func content(token: String) async throws -> ContentResponse {
        try await request("/api/content", token: token)
    }

    func submit(result: QuizResultPayload, token: String) async throws {
        let data = try JSONEncoder().encode(result)
        let _: SimpleOK = try await request("/api/result", method: "POST", token: token, body: data)
    }

    func progress(token: String) async throws -> ProgressResponse {
        try await request("/api/me", token: token)
    }

    func askAI(message: String, mode: String, token: String) async throws -> AIResponse {
        let data = try JSONEncoder().encode(AIRequest(message: message, mode: mode))
        return try await request("/api/ai", method: "POST", token: token, body: data)
    }
}

private struct SimpleOK: Codable { let ok: Bool }
