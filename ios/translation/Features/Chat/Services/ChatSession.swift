import Foundation
import SwiftUI

@MainActor
final class ChatSession: ObservableObject, Identifiable {
    let id: UUID

    @Published var messages: [ChatMessage]
    @Published var isLoading: Bool
    @Published var state: ChatTurnResponse.State
    @Published var checklist: [String]?
    @Published var researchResult: ChatResearchResponse?
    @Published var errorMessage: String?
    @Published var hasPendingRequest: Bool

    private let service: ChatService
    private let repository: ChatSessionRepository
    private var pendingRequestType: ChatPendingRequestType?

    init(
        id: UUID = UUID(),
        service: ChatService,
        repository: ChatSessionRepository
    ) {
        self.id = id
        self.service = service
        self.repository = repository
        self.messages = [ChatMessage(role: .assistant, content: String(localized: "chat.greeting"))]
        self.isLoading = false
        self.state = .gathering
        self.checklist = nil
        self.researchResult = nil
        self.errorMessage = nil
        self.hasPendingRequest = false
        persistState()
    }

    init(
        from data: ChatSessionData,
        service: ChatService,
        repository: ChatSessionRepository
    ) {
        self.id = data.id
        self.service = service
        self.repository = repository
        self.messages = data.messages
        self.isLoading = false
        self.state = data.state
        self.checklist = data.checklist
        self.researchResult = data.researchResult
        self.errorMessage = nil
        self.hasPendingRequest = data.hasPendingRequest
        self.pendingRequestType = data.pendingRequestType
    }

    func sendMessage(content: String, attachments: [ChatAttachment] = [], appendUserMessage: Bool = true) async {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !attachments.isEmpty else { return }

        if appendUserMessage {
            messages.append(ChatMessage(role: .user, content: trimmed, attachments: attachments))
        }

        pendingRequestType = .message(content: trimmed, attachments: attachments)
        hasPendingRequest = true
        persistState()

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await service.send(messages: messages)
            checklist = response.checklist
            state = response.state
            messages.append(ChatMessage(role: .assistant, content: response.reply))
            errorMessage = nil
            pendingRequestType = nil
            hasPendingRequest = false
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        persistState()
    }

    func runResearch() async {
        guard !messages.isEmpty else { return }

        pendingRequestType = .research
        hasPendingRequest = true
        persistState()

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await service.research(messages: messages)
            researchResult = result
            let bulletList = result.items.map { "• \($0.term)" }.joined(separator: "\n")
            let messageText = bulletList.isEmpty ? String(localized: "chat.research.ready") : bulletList
            messages.append(ChatMessage(role: .assistant, content: messageText))
            errorMessage = nil
            pendingRequestType = nil
            hasPendingRequest = false
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        persistState()
    }

    func resumePendingRequest() async {
        guard let pendingType = pendingRequestType else { return }
        switch pendingType {
        case .message(let content, let attachments):
            await sendMessage(content: content, attachments: attachments, appendUserMessage: false)
        case .research:
            await runResearch()
        }
    }

    func reset() {
        messages = [ChatMessage(role: .assistant, content: String(localized: "chat.greeting"))]
        checklist = nil
        researchResult = nil
        state = .gathering
        errorMessage = nil
        pendingRequestType = nil
        hasPendingRequest = false
        persistState()
    }

    private func persistState() {
        let data = ChatSessionData(
            id: id,
            messages: messages,
            state: state,
            checklist: checklist,
            researchResult: researchResult,
            hasPendingRequest: hasPendingRequest,
            pendingRequestType: pendingRequestType
        )
        repository.save(data)
    }
}
