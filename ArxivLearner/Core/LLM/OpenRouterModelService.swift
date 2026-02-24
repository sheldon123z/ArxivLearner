import Foundation

// MARK: - OpenRouterModelsResponse

// Mirrors the OpenRouter GET /api/v1/models response schema:
// { "data": [{ "id": "openai/gpt-4o", "name": "GPT-4o", ... }] }

private struct OpenRouterModelsResponse: Decodable {
    struct ModelItem: Decodable {
        let id: String
        let name: String
    }
    let data: [ModelItem]
}

// MARK: - OpenRouterModelService

/// Fetches the list of available models from the OpenRouter API and converts them
/// into `PresetModel` values for use throughout the app.
///
/// Inject a custom `URLSession` during testing to avoid real network calls.
final class OpenRouterModelService {

    // MARK: Constants

    private static let modelsEndpoint = "https://openrouter.ai/api/v1/models"

    // MARK: Fallback models

    /// A curated fallback list returned when the network request fails or is unavailable.
    static let fallbackModels: [PresetModel] = [
        PresetModel(id: "anthropic/claude-opus-4-6", name: "Claude Opus 4.6"),
        PresetModel(id: "anthropic/claude-sonnet-4-6", name: "Claude Sonnet 4.6"),
        PresetModel(id: "openai/gpt-4.1", name: "GPT-4.1"),
        PresetModel(id: "google/gemini-2.5-pro", name: "Gemini 2.5 Pro"),
        PresetModel(id: "deepseek/deepseek-chat-v3-0324", name: "DeepSeek V3"),
    ]

    // MARK: Properties

    private let session: URLSession

    // MARK: Init

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: Public API

    /// Fetches the full model catalogue from OpenRouter and returns it as `[PresetModel]`.
    ///
    /// - Throws: `LLMError.invalidURL` if the endpoint string cannot be parsed,
    ///           `LLMError.badResponse` for non-2xx HTTP status codes, or
    ///           `LLMError.invalidResponse` if the response body cannot be decoded.
    func fetchModels() async throws -> [PresetModel] {
        guard let url = URL(string: Self.modelsEndpoint) else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)

        let decoded: OpenRouterModelsResponse
        do {
            decoded = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data)
        } catch {
            throw LLMError.invalidResponse
        }

        return decoded.data.map { item in
            PresetModel(id: item.id, name: item.name)
        }
    }

    // MARK: Private helpers

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.badResponse(statusCode: -1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw LLMError.badResponse(statusCode: httpResponse.statusCode)
        }
    }
}
