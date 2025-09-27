import Foundation

struct DeckMakeRequest: Codable {
    struct Item: Codable {
        let title: String?
        let explanation: String?
        let example: String?
        let note: String?
        let source: String?
        let tags: [String]?

        // Legacy fields retained for backward compatibility/prompt context
        let en: String?
        let suggestion: String?
        let explainZh: String?

        let raw: RawSnapshot?

        struct RawSnapshot: Codable {
            let id: UUID
            let title: String
            let explanation: String
            let correctExample: String
            let note: String?
            let sourceHintID: String?
            let savedAtISO8601: String
        }

        private static let isoFormatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()

        static func knowledge(_ payload: KnowledgeSavePayload) -> Item {
            let trimmedTitle = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedExplanation = payload.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedExample = payload.correctExample.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNote = payload.note?.trimmingCharacters(in: .whitespacesAndNewlines)
            let sourceTag = payload.sourceHintID == nil ? "error" : "hint"

            let snapshot = RawSnapshot(
                id: payload.id,
                title: payload.title,
                explanation: payload.explanation,
                correctExample: payload.correctExample,
                note: payload.note,
                sourceHintID: payload.sourceHintID?.uuidString,
                savedAtISO8601: isoFormatter.string(from: payload.savedAt)
            )

            let cleanedNote: String? = {
                guard let trimmedNote, !trimmedNote.isEmpty else { return nil }
                return trimmedNote
            }()

            return Item(
                title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                explanation: trimmedExplanation.isEmpty ? nil : trimmedExplanation,
                example: trimmedExample.isEmpty ? nil : trimmedExample,
                note: cleanedNote,
                source: sourceTag,
                tags: nil,
                en: trimmedExample.isEmpty ? nil : trimmedExample,
                suggestion: trimmedTitle.isEmpty ? nil : trimmedTitle,
                explainZh: trimmedExplanation.isEmpty ? nil : trimmedExplanation,
                raw: snapshot
            )
        }
    }

    let name: String
    let items: [Item]
    let model: String?
}

struct DeckCardDTO: Codable {
    let front: String
    let frontNote: String?
    let back: String
    let backNote: String?
}
struct DeckMakeResponse: Codable { let name: String; let cards: [DeckCardDTO] }

protocol DeckService {
    func makeDeck(name: String, items: [DeckMakeRequest.Item]) async throws -> (name: String, cards: [Flashcard])
}

enum DeckServiceFactory {
    static func makeDefault() -> DeckService { DeckServiceHTTP() }
}

final class DeckServiceHTTP: DeckService {
    private func endpointURL() throws -> URL {
        guard let correct = AppConfig.correctAPIURL else { throw URLError(.badURL) }
        var comps = URLComponents(url: correct, resolvingAgainstBaseURL: false)!
        comps.path = comps.path.replacingOccurrences(of: "/correct", with: "") + "/make_deck"
        return comps.url ?? correct.deletingLastPathComponent().appendingPathComponent("make_deck")
    }

    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600
        config.timeoutIntervalForResource = 1200
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }

    private let session: URLSession

    init(session: URLSession = DeckServiceHTTP.makeSession()) {
        self.session = session
    }

    func makeDeck(name: String, items: [DeckMakeRequest.Item]) async throws -> (name: String, cards: [Flashcard]) {
        let model = UserDefaults.standard.string(forKey: "settings.deckGenerationModel")
        let req = DeckMakeRequest(name: name, items: items, model: model)
        var urlReq = URLRequest(url: try endpointURL())
        urlReq.httpMethod = "POST"
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlReq.timeoutInterval = 1200
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let body = try enc.encode(req)
            urlReq.httpBody = body
            if let s = String(data: body, encoding: .utf8) {
                AppLog.aiInfo("make_deck request JSON:\n\(s)")
            }
        } catch {
            AppLog.aiError("make_deck encode request failed: \(error.localizedDescription)")
            throw error
        }
        let (data, resp) = try await session.data(for: urlReq)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            if let s = String(data: data, encoding: .utf8) { AppLog.aiError("make_deck http \(code) body:\n\(s)") }
            throw URLError(.badServerResponse, userInfo: ["status": code])
        }
        if let raw = String(data: data, encoding: .utf8) {
            AppLog.aiInfo("make_deck response JSON raw:\n\(raw)")
        }
        let dto = try JSONDecoder().decode(DeckMakeResponse.self, from: data)
        let cards = dto.cards.map { Flashcard(front: $0.front, back: $0.back, frontNote: $0.frontNote, backNote: $0.backNote) }
        AppLog.aiInfo("make_deck name=\(dto.name) items_in=\(items.count) cards_out=\(cards.count)")
        return (dto.name, cards)
    }
}

// Mock implementation removed: BACKEND_URL is required for deck operations.
