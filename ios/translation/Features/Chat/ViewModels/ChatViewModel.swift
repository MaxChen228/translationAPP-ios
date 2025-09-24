import Foundation
import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var inputText: String = "" {
        didSet { refreshClipboardParseState() }
    }
    @Published var isBackgroundActive: Bool = false
    @Published var showContinuationBanner: Bool = false
    @Published var clipboardParseState: ClipboardDeckParseState = .notMatched
    @Published var clipboardImportDeck: ChatResearchDeck? = nil
    @Published var clipboardImportError: String? = nil

    // 代理到 ChatSession 的屬性
    var messages: [ChatMessage] { session.messages }
    var isLoading: Bool { session.isLoading }
    var state: ChatTurnResponse.State { session.state }
    var checklist: [String]? { session.checklist }
    var researchDeck: ChatResearchDeck? { session.researchDeck }
    var errorMessage: String? { session.errorMessage }
    var hasPendingRequest: Bool { session.hasPendingRequest }

    let chatManager: ChatManaging
    private let session: ChatSession
    private let sessionID: UUID
    private var cancellables: Set<AnyCancellable> = []
    private let clipboardParser = ClipboardDeckParser()

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
        clearClipboardImport()
    }

    func resumePendingRequest() async {
        showContinuationBanner = false
        await session.resumePendingRequest()
    }

    func dismissContinuationBanner() {
        showContinuationBanner = false
    }

    func importClipboardDeck() {
        if let deck = clipboardImportDeck {
            session.importResearch(deck: deck, source: "clipboard")
            clearClipboardImport()
            inputText = ""
            clipboardParseState = .notMatched
            return
        }

        guard case let .success(deck) = clipboardParseState else { return }
        session.importResearch(deck: deck, source: "clipboard")
        inputText = ""
        clipboardParseState = .notMatched
        clearClipboardImport()
    }

    private func refreshClipboardParseState() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clipboardParseState = .notMatched
            return
        }
        clipboardParseState = clipboardParser.validate(trimmed)
    }

    func loadClipboardFromPasteboard() {
#if canImport(UIKit)
        let pasteboardText = UIPasteboard.general.string ?? ""
        let trimmed = pasteboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clipboardImportDeck = nil
            clipboardImportError = String(localized: "chat.clipboard.error.emptyClipboard")
            return
        }

        switch clipboardParser.validate(trimmed) {
        case .success(let deck):
            clipboardImportDeck = deck
            clipboardImportError = nil
        case .failure(let message):
            clipboardImportDeck = nil
            clipboardImportError = message
        case .notMatched:
            clipboardImportDeck = nil
            clipboardImportError = String(localized: "chat.clipboard.error.notRecognized")
        }
        clipboardParseState = .notMatched
#else
        clipboardImportDeck = nil
        clipboardImportError = String(localized: "chat.clipboard.error.unavailable")
#endif
    }

    func clearClipboardImport() {
        clipboardImportDeck = nil
        clipboardImportError = nil
    }

    var clipboardTemplateText: String {
        """
        ### Translation.DeepResearch v1
        {\n  \"deck_name\": \"Sample Deck\",\n  \"generated_at\": \"2024-01-01T00:00:00Z\",\n  \"cards\": [\n    {\n      \"front\": \"keyword\",\n      \"front_note\": \"(optional)\",\n      \"back\": \"定義或解釋\",\n      \"back_note\": \"(optional example)\"\n    }\n  ]\n}
        """
    }

    func copyClipboardTemplate() {
#if canImport(UIKit)
        UIPasteboard.general.string = clipboardTemplateText
#endif
    }
}
