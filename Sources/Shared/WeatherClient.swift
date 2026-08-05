import Foundation

struct WeatherClient: Sendable {
    enum ClientError: LocalizedError {
        case invalidURL
        case badResponse
        case httpStatus(Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "The location couldn't be turned into a valid request."
            case .badResponse: return "Unexpected response from wttr.in."
            case .httpStatus(let code): return "wttr.in returned HTTP \(code)."
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(location: String?) async throws -> WeatherResponse {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "wttr.in"
        if let location, !location.isEmpty {
            components.path = "/" + location
        }
        components.queryItems = [URLQueryItem(name: "format", value: "j1")]
        guard let url = components.url else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("DeepWeather/1.0 (iOS app)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(WeatherResponse.self, from: data)
    }
}
