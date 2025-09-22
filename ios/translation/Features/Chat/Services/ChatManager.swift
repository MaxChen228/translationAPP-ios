import Foundation
import SwiftUI

@MainActor
final class ChatManager: ObservableObject {
    static let shared = ChatManager()

    @Published private(set) var activeSessions: [UUID: ChatSession] = [:]
    @Published var isBackgroundTaskActive: Bool = false

    private let service: ChatService
    private let repository: ChatSessionRepository
    private let backgroundCoordinator: ChatBackgroundCoordinating

    init(
        service: ChatService = ChatServiceFactory.makeDefault(),
        repository: ChatSessionRepository = FileChatSessionRepository(),
        backgroundCoordinator: ChatBackgroundCoordinating? = nil
    ) {
        self.service = service
        self.repository = repository
        self.backgroundCoordinator = backgroundCoordinator ?? ChatBackgroundCoordinator()

        self.backgroundCoordinator.configure { [weak self] in
            await self?.resumePendingChats()
        }

        restoreSessions()
    }

    func startChatSession(sessionID: UUID = UUID()) -> ChatSession {
        if let existing = activeSessions[sessionID] {
            return existing
        }
        if let restored = repository.loadSession(id: sessionID) {
            let session = ChatSession(from: restored, service: service, repository: repository)
            activeSessions[sessionID] = session
            return session
        }
        let session = ChatSession(id: sessionID, service: service, repository: repository)
        activeSessions[sessionID] = session
        return session
    }

    func sendMessage(sessionID: UUID, content: String, attachments: [ChatAttachment] = []) async {
        guard let session = activeSessions[sessionID] else { return }
        startBackgroundTaskIfNeeded()
        defer { endBackgroundTaskIfNeeded() }
        await session.sendMessage(content: content, attachments: attachments)
    }

    func runResearch(sessionID: UUID) async {
        guard let session = activeSessions[sessionID] else { return }
        startBackgroundTaskIfNeeded()
        defer { endBackgroundTaskIfNeeded() }
        await session.runResearch()
    }

    func removeSession(id: UUID) {
        activeSessions[id] = nil
        repository.delete(id: id)
    }

    // MARK: - Private Helpers

    private func restoreSessions() {
        let stored = repository.loadAll()
        for sessionData in stored {
            let session = ChatSession(from: sessionData, service: service, repository: repository)
            activeSessions[session.id] = session
        }
    }

    private func resumePendingChats() async {
        for session in activeSessions.values where session.hasPendingRequest {
            await session.resumePendingRequest()
        }
    }

    private func startBackgroundTaskIfNeeded() {
        backgroundCoordinator.startBackgroundTaskIfNeeded()
        isBackgroundTaskActive = backgroundCoordinator.isBackgroundTaskActive
    }

    private func endBackgroundTaskIfNeeded() {
        backgroundCoordinator.endBackgroundTaskIfNeeded()
        isBackgroundTaskActive = backgroundCoordinator.isBackgroundTaskActive
    }
}
