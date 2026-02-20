import Foundation

// MARK: - HTTPError

enum HTTPError: Error, LocalizedError {
    case badResponse(statusCode: Int)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .badResponse(let statusCode):
            return "Server returned an unexpected status code: \(statusCode)"
        case .invalidURL:
            return "The provided URL is invalid."
        }
    }
}

// MARK: - HTTPClient

final class HTTPClient {

    // MARK: Singleton

    static let shared = HTTPClient()

    // MARK: Private State

    private let session: URLSession

    // MARK: Init

    private init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: Public API

    /// Fetches data from the given URL, throwing HTTPError on non-2xx responses.
    func fetch(url: URL) async throws -> Data {
        let request = URLRequest(url: url)
        return try await fetch(request: request)
    }

    /// Fetches data using the given URLRequest, throwing HTTPError on non-2xx responses.
    func fetch(request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.badResponse(statusCode: -1)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw HTTPError.badResponse(statusCode: httpResponse.statusCode)
        }

        return data
    }
}
