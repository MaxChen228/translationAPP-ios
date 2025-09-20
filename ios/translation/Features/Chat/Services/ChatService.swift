import Foundation

protocol ChatService {
    func send(messages: [ChatMessage]) async throws -> ChatTurnResponse
    func research(messages: [ChatMessage]) async throws -> ChatResearchResponse
}

enum ChatServiceFactory {
    static func makeDefault() -> ChatService {
        guard let respond = AppConfig.chatRespondURL, let research = AppConfig.chatResearchURL else {
            AppLog.aiError("BACKEND_URL missing: ChatService unavailable")
            return UnavailableChatService()
        }
        AppLog.aiInfo("Using HTTP ChatService")
        return ChatServiceHTTP(respondEndpoint: respond, researchEndpoint: research)
    }
}

final class UnavailableChatService: ChatService {
    struct MissingBackendError: LocalizedError {
        var errorDescription: String? { "BACKEND_URL 未設定，無法使用聊天。" }
    }
    func send(messages: [ChatMessage]) async throws -> ChatTurnResponse { throw MissingBackendError() }
    func research(messages: [ChatMessage]) async throws -> ChatResearchResponse { throw MissingBackendError() }
}

final class ChatServiceHTTP: ChatService {
    private let respondEndpoint: URL
    private let researchEndpoint: URL
    private let session: URLSession

    init(respondEndpoint: URL, researchEndpoint: URL, session: URLSession = .shared) {
        self.respondEndpoint = respondEndpoint
        self.researchEndpoint = researchEndpoint
        self.session = session
    }

    struct MessageDTO: Codable { let role: String; let content: String }
    struct TurnResponseDTO: Codable {
        let reply: String
        let state: String
        let checklist: [String]?
    }
    struct ResearchResponseDTO: Codable {
        let title: String
        let summary: String
        let sourceZh: String?
        let attemptEn: String?
        let correctedEn: String
        let errors: [AIServiceHTTP.ErrorDTO]
    }

    func send(messages: [ChatMessage]) async throws -> ChatTurnResponse {
        let dto = try await postTurn(messages: MessageList(messages: messages))
        let state = ChatTurnResponse.State(rawValue: dto.state) ?? .gathering
        return ChatTurnResponse(reply: dto.reply, state: state, checklist: dto.checklist)
    }

    func research(messages: [ChatMessage]) async throws -> ChatResearchResponse {
        let dto = try await postResearch(messages: MessageList(messages: messages))
        let errors = dto.errors.map { e -> ErrorItem in
            let type = ErrorType(rawValue: e.type) ?? .lexical
            let identifier = e.id ?? UUID()
            let hints: ErrorHints? = {
                guard let h = e.hints else { return nil }
                return ErrorHints(before: h.before, after: h.after, occurrence: h.occurrence)
            }()
            return ErrorItem(id: identifier, span: e.span, type: type, explainZh: e.explainZh, suggestion: e.suggestion, hints: hints)
        }
        return ChatResearchResponse(title: dto.title, summary: dto.summary, sourceZh: dto.sourceZh, attemptEn: dto.attemptEn, correctedEn: dto.correctedEn, errors: errors)
    }

    private struct MessageList: Codable {
        let messages: [MessageDTO]
        init(messages: [ChatMessage]) {
            self.messages = messages.map { MessageDTO(role: $0.role.rawValue, content: $0.content) }
        }
    }

    private func postTurn(messages: MessageList) async throws -> TurnResponseDTO {
        try await post(url: respondEndpoint, body: messages)
    }

    private func postResearch(messages: MessageList) async throws -> ResearchResponseDTO {
        try await post(url: researchEndpoint, body: messages)
    }

    private func post<R: Decodable>(url: URL, body: MessageList) async throws -> R {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw URLError(.badServerResponse, userInfo: ["status": code])
        }
        return try JSONDecoder().decode(R.self, from: data)
    }
}
