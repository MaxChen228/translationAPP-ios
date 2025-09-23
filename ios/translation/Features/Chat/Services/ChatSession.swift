import Foundation
import SwiftUI

@MainActor
final class ChatSession: ObservableObject, Identifiable {
    let id: UUID

    @Published var messages: [ChatMessage]
    @Published var isLoading: Bool
    @Published var state: ChatTurnResponse.State
    @Published var checklist: [String]?
    @Published var researchDeck: ChatResearchDeck?
    @Published var errorMessage: String?
    @Published var hasPendingRequest: Bool

    private let service: ChatService
    private let persister: ChatSessionPersisting
    private var pendingRequestType: ChatPendingRequestType?

    init(
        id: UUID = UUID(),
        service: ChatService,
        persister: ChatSessionPersisting
    ) {
        self.id = id
        self.service = service
        self.persister = persister
        self.messages = [ChatMessage(role: .assistant, content: String(localized: "chat.greeting"))]
        self.isLoading = false
        self.state = .gathering
        self.checklist = nil
        self.researchDeck = nil
        self.errorMessage = nil
        self.hasPendingRequest = false
        persistStateDetached()
    }

    init(
        from data: ChatSessionData,
        service: ChatService,
        persister: ChatSessionPersisting
    ) {
        self.id = data.id
        self.service = service
        self.persister = persister
        self.messages = data.messages
        self.isLoading = false
        self.state = data.state
        self.checklist = data.checklist
        self.researchDeck = data.researchDeck
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
        await persistStateAsync()

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
        await persistStateAsync()
    }

    func runResearch() async {
        guard !messages.isEmpty else { return }

        pendingRequestType = .research
        hasPendingRequest = true
        await persistStateAsync()

        isLoading = true
        defer { isLoading = false }

        do {
            let deck = try await service.research(messages: messages)
            researchDeck = deck
            let cardCount = deck.cards.count
            let template = String(localized: "chat.research.deckGenerated")
            let messageText = String(format: template, deck.name, cardCount)
            messages.append(ChatMessage(role: .assistant, content: messageText))
            errorMessage = nil
            pendingRequestType = nil
            hasPendingRequest = false
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        await persistStateAsync()
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
        researchDeck = nil
        state = .gathering
        errorMessage = nil
        pendingRequestType = nil
        hasPendingRequest = false
        persistStateDetached()
    }

    func applyPersistedData(_ data: ChatSessionData) {
        messages = data.messages
        state = data.state
        checklist = data.checklist
        researchDeck = data.researchDeck
        hasPendingRequest = data.hasPendingRequest
        pendingRequestType = data.pendingRequestType
        errorMessage = nil
        isLoading = false
    }

    private func persistStateDetached() {
        Task {
            await persistStateAsync()
        }
    }

    private func persistStateAsync() async {
        let data = ChatSessionData(
            id: id,
            messages: messages,
            state: state,
            checklist: checklist,
            researchDeck: researchDeck,
            hasPendingRequest: hasPendingRequest,
            pendingRequestType: pendingRequestType
        )
        await persister.save(data)
    }
}
