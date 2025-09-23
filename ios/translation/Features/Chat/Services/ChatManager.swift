import Foundation
import SwiftUI
import Combine

@MainActor
protocol ChatManaging: AnyObject {
    var backgroundActivityPublisher: AnyPublisher<Bool, Never> { get }
    func startChatSession(sessionID: UUID) -> ChatSession
    func sendMessage(sessionID: UUID, content: String, attachments: [ChatAttachment]) async
    func runResearch(sessionID: UUID) async
    func removeSession(id: UUID)
}

@MainActor
final class ChatManager: ObservableObject, ChatManaging {
    static let shared = ChatManager()

    @Published private(set) var activeSessions: [UUID: ChatSession] = [:]
    @Published var isBackgroundTaskActive: Bool = false

    private let service: ChatService
    private let persister: ChatSessionPersisting
    private let backgroundCoordinator: ChatBackgroundCoordinating

    init(
        service: ChatService = ChatServiceFactory.makeDefault(),
        persister: ChatSessionPersisting = FileChatSessionStore(),
        backgroundCoordinator: ChatBackgroundCoordinating? = nil
    ) {
        self.service = service
        self.persister = persister
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
        let session = ChatSession(id: sessionID, service: service, persister: persister)
        activeSessions[sessionID] = session
        Task { @MainActor [weak session] in
            guard let data = await persister.loadSession(id: sessionID) else { return }
            guard let session else { return }
            await session.applyPersistedData(data)
        }
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
        Task {
            await persister.delete(id: id)
        }
    }

    // MARK: - Private Helpers

    private func restoreSessions() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let stored = await persister.loadAll()
            for sessionData in stored {
                if let existing = activeSessions[sessionData.id] {
                    existing.applyPersistedData(sessionData)
                } else {
                    let session = ChatSession(from: sessionData, service: service, persister: persister)
                    activeSessions[session.id] = session
                }
            }
        }
    }

    private func resumePendingChats() async {
        for session in activeSessions.values where session.hasPendingRequest {
            await session.resumePendingRequest()
        }
    }

    var backgroundActivityPublisher: AnyPublisher<Bool, Never> {
        $isBackgroundTaskActive.eraseToAnyPublisher()
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
