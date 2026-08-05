import Foundation

struct GeoResult: Decodable, Sendable, Identifiable {
    let id: Int
    let name: String
    let admin1: String?
    let country: String?
    let latitude: Double
    let longitude: Double

    var detail: String {
        [admin1, country].compactMap { $0 }.joined(separator: ", ")
    }
}

private struct GeoResponse: Decodable {
    let results: [GeoResult]?
}

struct GeocodingClient: Sendable {
    func search(_ query: String) async throws -> [GeoResult] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("DeepWeather/1.0 (iOS app)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return []
        }
        return try JSONDecoder().decode(GeoResponse.self, from: data).results ?? []
    }
}
