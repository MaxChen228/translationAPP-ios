import Foundation
import Testing
@testable import translation

@MainActor
struct ChatManagerTests {

    @Test("ChatManager caches sessions per identifier")
    func testStartChatSessionCachesInstance() {
        let service = MockChatService()
        let repository = InMemoryChatSessionStore()
        let background = MockBackgroundCoordinator()
        let manager = ChatManager(service: service, persister: repository, backgroundCoordinator: background)

        let id = UUID()
        let sessionA = manager.startChatSession(sessionID: id)
        let sessionB = manager.startChatSession(sessionID: id)

        #expect(sessionA === sessionB)
        #expect(manager.activeSessions[id] === sessionA)
    }

    @Test("ChatManager restores persisted sessions on init")
    func testRestoreSessions() async {
        let id = UUID()
        let persisted = TestHelpers.createTestSessionData(
            id: id,
            messages: [ChatMessage(role: .assistant, content: "Restored")],
            state: .ready
        )
        let repository = InMemoryChatSessionStore(initial: [id: persisted])
        let manager = ChatManager(service: MockChatService(), persister: repository, backgroundCoordinator: MockBackgroundCoordinator())

        await waitFor {
            manager.activeSessions[id] != nil
        }

        let restored = manager.activeSessions[id]
        #expect(restored != nil)
        #expect(restored?.messages.first?.content == "Restored")
    }

    @Test("ChatManager sendMessage delegates to session and background coordinator")
    func testSendMessageDelegation() async {
        let service = MockChatService()
        let repository = InMemoryChatSessionStore()
        let background = MockBackgroundCoordinator()
        let manager = ChatManager(service: service, persister: repository, backgroundCoordinator: background)

        let id = UUID()
        _ = manager.startChatSession(sessionID: id)

        await manager.sendMessage(sessionID: id, content: "Hi")

        let sends = service.sendRequests
        #expect(sends.count == 1)
        #expect(background.startCallCount == 1)
        #expect(background.endCallCount == 1)
        #expect(manager.isBackgroundTaskActive == false)
    }

    @Test("ChatManager runResearch uses background coordinator")
    func testRunResearchUsesBackgroundCoordinator() async {
        let service = MockChatService()
        let repository = InMemoryChatSessionStore()
        let background = MockBackgroundCoordinator()
        let manager = ChatManager(service: service, persister: repository, backgroundCoordinator: background)

        let id = UUID()
        let session = manager.startChatSession(sessionID: id)
        await session.sendMessage(content: "Prompt")

        await manager.runResearch(sessionID: id)

        let researchCalls = service.researchRequests
        #expect(researchCalls.count == 1)
        #expect(background.startCallCount >= 1)
        #expect(background.endCallCount >= 1)
        #expect(manager.isBackgroundTaskActive == false)
    }

    @Test("ChatManager background resume processes pending chats")
    func testBackgroundResumeProcessesPendingChats() async {
        let id = UUID()
        let pending = ChatSessionData(
            id: id,
            messages: [ChatMessage(role: .user, content: "Resume me")],
            state: .gathering,
            checklist: nil,
            researchResult: nil,
            hasPendingRequest: true,
            pendingRequestType: .message(content: "Resume me", attachments: [])
        )
        let repository = InMemoryChatSessionStore(initial: [id: pending])
        let service = MockChatService()
        let background = MockBackgroundCoordinator()
        let manager = ChatManager(service: service, persister: repository, backgroundCoordinator: background)

        await waitFor {
            manager.activeSessions[id] != nil
        }

        await background.triggerResume()

        let sends = service.sendRequests
        #expect(sends.count == 1)
        #expect(manager.activeSessions[id]?.hasPendingRequest == false)
    }

    @Test("ChatManager removeSession clears repository storage")
    func testRemoveSession() async {
        let id = UUID()
        let repository = InMemoryChatSessionStore()
        let manager = ChatManager(service: MockChatService(), persister: repository, backgroundCoordinator: MockBackgroundCoordinator())
        _ = manager.startChatSession(sessionID: id)

        manager.removeSession(id: id)

        #expect(manager.activeSessions[id] == nil)
        await waitFor {
            let snapshot = await repository.storedSessions()
            return snapshot[id] == nil
        }
        let snapshot = await repository.storedSessions()
        #expect(snapshot[id] == nil)
    }

    private func waitFor(timeout: TimeInterval = 0.2, predicate: @escaping @Sendable () async -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await predicate() { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
