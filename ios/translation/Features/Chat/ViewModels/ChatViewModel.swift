import Foundation
import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var isBackgroundActive: Bool = false
    @Published var showContinuationBanner: Bool = false

    // 代理到 ChatSession 的屬性
    var messages: [ChatMessage] { session.messages }
    var isLoading: Bool { session.isLoading }
    var state: ChatTurnResponse.State { session.state }
    var checklist: [String]? { session.checklist }
    var researchResult: ChatResearchResponse? { session.researchResult }
    var errorMessage: String? { session.errorMessage }
    var hasPendingRequest: Bool { session.hasPendingRequest }

    let chatManager: ChatManaging
    private let session: ChatSession
    private let sessionID: UUID
    private var cancellables: Set<AnyCancellable> = []

    init(sessionID: UUID? = nil, chatManager: ChatManaging? = nil) {
        let resolvedManager = chatManager ?? ChatManager.shared
        self.sessionID = sessionID ?? UUID()
        self.chatManager = resolvedManager
        self.session = resolvedManager.startChatSession(sessionID: self.sessionID)

        // 監聽後台狀態
        resolvedManager.backgroundActivityPublisher
            .receive(on: RunLoop.main)
            .assign(to: \.isBackgroundActive, on: self)
            .store(in: &cancellables)

        session.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // 檢查是否有待恢復的對話
        if session.hasPendingRequest {
            showContinuationBanner = true
        }
    }

    func sendMessage(attachments: [ChatAttachment] = []) async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !attachments.isEmpty else { return }

        inputText = ""
        showContinuationBanner = false

        // 使用 ChatManager 的後台安全方法
        await chatManager.sendMessage(sessionID: sessionID, content: trimmed, attachments: attachments)
    }

    func runResearch() async {
        guard !session.messages.isEmpty else { return }
        showContinuationBanner = false

        // 使用 ChatManager 的後台安全方法
        await chatManager.runResearch(sessionID: sessionID)
    }

    func reset() {
        session.reset()
        inputText = ""
        showContinuationBanner = false
    }

    func resumePendingRequest() async {
        showContinuationBanner = false
        await session.resumePendingRequest()
    }

    func dismissContinuationBanner() {
        showContinuationBanner = false
    }
}
