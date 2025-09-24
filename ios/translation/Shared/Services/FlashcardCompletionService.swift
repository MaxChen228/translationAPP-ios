import Foundation

struct FlashcardCompletionRequest: Encodable {
    struct CardPayload: Encodable {
        let front: String
        let frontNote: String?
        let back: String
        let backNote: String?
    }

    let card: CardPayload
    let instruction: String?
    let deckName: String?
}

struct FlashcardCompletionResponse: Decodable {
    let front: String
    let frontNote: String?
    let back: String
    let backNote: String?
}

protocol FlashcardCompletionService {
    func completeCard(_ request: FlashcardCompletionRequest) async throws -> FlashcardCompletionResponse
}

enum FlashcardCompletionServiceFactory {
    static func makeDefault() -> FlashcardCompletionService { FlashcardCompletionHTTP() }
}

final class FlashcardCompletionHTTP: FlashcardCompletionService {
    private var baseURL: URL {
        guard let url = AppConfig.backendURL else {
            fatalError("BACKEND_URL missing")
        }
        return url
    }

    func completeCard(_ request: FlashcardCompletionRequest) async throws -> FlashcardCompletionResponse {
        let url = baseURL.appendingPathComponent("flashcards").appendingPathComponent("complete")
        AppLog.uiInfo("[flashcards] POST /flashcards/complete")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw FlashcardCompletionError.networking(error)
        }
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard 200..<300 ~= http.statusCode else {
            if http.statusCode == 429 {
                throw FlashcardCompletionError.rateLimited
            }
            if http.statusCode == 400 {
                throw FlashcardCompletionError.invalidInput
            }
            throw FlashcardCompletionError.server(status: http.statusCode)
        }
        do {
            return try JSONDecoder().decode(FlashcardCompletionResponse.self, from: data)
        } catch {
            throw FlashcardCompletionError.decoding(error)
        }
    }
}

enum FlashcardCompletionError: LocalizedError {
    case rateLimited
    case invalidInput
    case server(status: Int)
    case decoding(Error)
    case networking(Error)
    case noDraft
    case emptyFront

    var errorDescription: String? {
        switch self {
        case .rateLimited:
            return String(localized: "flashcards.generator.error.rateLimit")
        case .invalidInput:
            return String(localized: "flashcards.generator.error.invalidInput")
        case .server(let status):
            return String.localizedStringWithFormat(
                String(localized: "flashcards.generator.error.server"),
                status
            )
        case .decoding:
            return String(localized: "flashcards.generator.error.decoding")
        case .networking(let error):
            return error.localizedDescription
        case .noDraft:
            return String(localized: "flashcards.generator.error.noDraft")
        case .emptyFront:
            return String(localized: "flashcards.generator.error.emptyFront")
        }
    }
}
