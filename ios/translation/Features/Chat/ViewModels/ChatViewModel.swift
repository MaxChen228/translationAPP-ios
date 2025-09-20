import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var state: ChatTurnResponse.State = .gathering
    @Published var checklist: [String]? = nil
    @Published var researchResult: ChatResearchResponse? = nil
    @Published var errorMessage: String? = nil

    private let service: ChatService

    init(service: ChatService = ChatServiceFactory.makeDefault()) {
        self.service = service
        messages = [ChatMessage(role: .assistant, content: String(localized: "chat.greeting"))]
    }

    func sendMessage() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        messages.append(ChatMessage(role: .user, content: trimmed))
        await sendCurrentMessages()
    }

    private func sendCurrentMessages() async {
        isLoading = true
        do {
            let resp = try await service.send(messages: messages)
            checklist = resp.checklist
            state = resp.state
            messages.append(ChatMessage(role: .assistant, content: resp.reply))
            errorMessage = nil
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        isLoading = false
    }

    func runResearch() async {
        guard !messages.isEmpty else { return }
        isLoading = true
        do {
            let res = try await service.research(messages: messages)
            researchResult = res
            messages.append(ChatMessage(role: .assistant, content: res.summary))
            errorMessage = nil
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        isLoading = false
    }

    func reset() {
        messages = [ChatMessage(role: .assistant, content: String(localized: "chat.greeting"))]
        inputText = ""
        checklist = nil
        researchResult = nil
        state = .gathering
    }
}
