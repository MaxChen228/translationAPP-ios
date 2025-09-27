import Foundation

struct DeckMakeRequest: Codable {
    struct Item: Codable {
        let i: Int
        let concept: String
        let zh: String?
        let en: String?
        let note: String?
        let source: String?

        static func knowledge(_ payload: KnowledgeSavePayload, index: Int) -> Item {
            let trimmedTitle = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedExplanation = payload.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedExample = payload.correctExample.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNote = payload.note?.trimmingCharacters(in: .whitespacesAndNewlines)

            let candidateConcepts = [trimmedTitle, trimmedExample, trimmedExplanation]
            let concept = candidateConcepts.first(where: { !$0.isEmpty }) ?? "Concept \(index)"
            let sourceTag = payload.sourceHintID == nil ? "error" : "hint"

            let zhValue = trimmedExplanation.isEmpty ? nil : trimmedExplanation
            let enValue = trimmedExample.isEmpty ? nil : trimmedExample
            let noteValue = (trimmedNote?.isEmpty == false) ? trimmedNote : nil

            return Item(
                i: index,
                concept: concept,
                zh: zhValue,
                en: enValue,
                note: noteValue,
                source: sourceTag
            )
        }
    }

    let name: String
    let concepts: [Item]
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
    func makeDeck(name: String, concepts: [DeckMakeRequest.Item]) async throws -> (name: String, cards: [Flashcard])
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

    func makeDeck(name: String, concepts: [DeckMakeRequest.Item]) async throws -> (name: String, cards: [Flashcard]) {
        let model = UserDefaults.standard.string(forKey: "settings.deckGenerationModel")
        let req = DeckMakeRequest(name: name, concepts: concepts, model: model)
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
        AppLog.aiInfo("make_deck name=\(dto.name) concepts_in=\(concepts.count) cards_out=\(cards.count)")
        return (dto.name, cards)
    }
}

// Mock implementation removed: BACKEND_URL is required for deck operations.
