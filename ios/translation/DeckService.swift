import Foundation

struct DeckMakeItem: Codable {
    let zh: String
    let en: String
    let corrected: String
    let span: String?
    let suggestion: String?
    let explainZh: String?
    let type: String?
}

struct DeckMakeRequest: Codable {
    let name: String
    let items: [DeckMakeItem]
    // 選用：指定 LLM 模型（若後端支持以此模型產製卡片）
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
    func makeDeck(name: String, from payloads: [ErrorSavePayload]) async throws -> (name: String, cards: [Flashcard])
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

    func makeDeck(name: String, from payloads: [ErrorSavePayload]) async throws -> (name: String, cards: [Flashcard]) {
        let items: [DeckMakeItem] = payloads.map { p in
            DeckMakeItem(
                zh: p.inputZh,
                en: p.inputEn,
                corrected: p.correctedEn,
                span: p.error.span,
                suggestion: p.error.suggestion,
                explainZh: p.error.explainZh,
                type: p.error.type.rawValue
            )
        }
        let model = UserDefaults.standard.string(forKey: "settings.geminiModel")
        let req = DeckMakeRequest(name: name, items: items, model: model)
        var urlReq = URLRequest(url: try endpointURL())
        urlReq.httpMethod = "POST"
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
        let (data, resp) = try await URLSession.shared.data(for: urlReq)
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
        AppLog.aiInfo("make_deck name=\(dto.name) items_in=\(payloads.count) cards_out=\(cards.count)")
        return (dto.name, cards)
    }
}

// Mock implementation removed: BACKEND_URL is required for deck operations.
