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
        var errorDescription: String? { String(localized: "error.chat.backendMissing") }
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

    struct AttachmentDTO: Codable {
        let type: String
        let mimeType: String
        let data: String
    }

    struct MessageDTO: Codable {
        let role: String
        let content: String
        let attachments: [AttachmentDTO]?
    }
    struct TurnResponseDTO: Codable {
        let reply: String
        let state: String
        let checklist: [String]?
    }
    struct ResearchItemDTO: Codable {
        let term: String
        let explanation: String
        let context: String
        let type: String
    }

    struct ResearchResponseDTO: Codable {
        let items: [ResearchItemDTO]
    }

    func send(messages: [ChatMessage]) async throws -> ChatTurnResponse {
        let model = UserDefaults.standard.string(forKey: "settings.chatResponseModel")
        let dto = try await postTurn(messages: MessageList(messages: messages, model: model))
        let state = ChatTurnResponse.State(rawValue: dto.state) ?? .gathering
        return ChatTurnResponse(reply: dto.reply, state: state, checklist: dto.checklist)
    }

    func research(messages: [ChatMessage]) async throws -> ChatResearchResponse {
        let model = UserDefaults.standard.string(forKey: "settings.researchModel")
        let dto = try await postResearch(messages: MessageList(messages: messages, model: model))
        let items = dto.items.map { item in
            ChatResearchItem(
                term: item.term,
                explanation: item.explanation,
                context: item.context,
                type: ErrorType(rawValue: item.type) ?? .lexical
            )
        }
        guard !items.isEmpty else {
            throw URLError(.cannotDecodeContentData)
        }
        return ChatResearchResponse(items: items)
    }

    private struct MessageList: Codable {
        let messages: [MessageDTO]
        let model: String?

        init(messages: [ChatMessage], model: String? = nil) {
            self.messages = messages.map { message in
                let attachments = message.attachments.isEmpty ? nil : message.attachments.map { attachment in
                    AttachmentDTO(type: attachment.kind.rawValue, mimeType: attachment.mimeType, data: attachment.data.base64EncodedString())
                }
                return MessageDTO(role: message.role.rawValue, content: message.content, attachments: attachments)
            }
            self.model = model
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
