import Foundation
import Testing
@testable import translation

@MainActor
struct ChatSessionTests {

    @Test("ChatSession sendMessage persists and appends assistant reply")
    func testSendMessagePersists() async {
        let repository = InMemoryChatSessionStore()
        let service = MockChatService()
        let session = ChatSession(service: service, persister: repository)

        await session.sendMessage(content: "Hello")

        #expect(session.messages.count == 3) // greeting + user + assistant
        #expect(session.messages.last?.role == .assistant)
        #expect(session.hasPendingRequest == false)
        let snapshot = await repository.storedSessions()
        #expect(snapshot[session.id]?.messages.count == session.messages.count)
        let saveCount = await repository.savedCount()
        #expect(saveCount >= 2)

        let requests = service.sendRequests
        #expect(requests.count == 1)
        #expect(requests.first?.last?.content == "Hello")
    }

    @Test("ChatSession keeps pending state when send fails")
    func testSendMessageFailureKeepsPending() async {
        let repository = InMemoryChatSessionStore()
        let service = MockChatService()
        service.setSendResult(.failure(MockChatError.failure))
        let session = ChatSession(service: service, persister: repository)

        await session.sendMessage(content: "Needs retry")

        #expect(session.hasPendingRequest)
        #expect(session.errorMessage != nil)
        let snapshot = await repository.storedSessions()
        let saved = snapshot[session.id]
        #expect(saved?.hasPendingRequest == true)
        switch saved?.pendingRequestType {
        case .message(let content, _)?:
            #expect(content == "Needs retry")
        default:
            Issue.record("Expected pending message request to persist")
        }
    }

    @Test("ChatSession runResearch appends summary and clears pending")
    func testRunResearch() async {
        let repository = InMemoryChatSessionStore()
        let service = MockChatService()
        let session = ChatSession(service: service, persister: repository)

        await session.sendMessage(content: "Prompt")
        await session.runResearch()

        #expect(session.researchResult != nil)
        #expect(session.messages.last?.role == .assistant)
        #expect(session.hasPendingRequest == false)
        let snapshot = await repository.storedSessions()
        #expect(snapshot[session.id]?.hasPendingRequest == false)

        let researchCalls = service.researchRequests
        #expect(researchCalls.count == 1)
    }

    @Test("ChatSession resumePendingRequest retries failed message")
    func testResumePendingMessage() async {
        let repository = InMemoryChatSessionStore()
        let service = MockChatService()
        service.setSendResult(.failure(MockChatError.failure))
        let session = ChatSession(service: service, persister: repository)

        await session.sendMessage(content: "Retry me")
        #expect(session.hasPendingRequest)

        service.setSendResult(.success(ChatTurnResponse(reply: "ok", state: .ready, checklist: nil)))
        await session.resumePendingRequest()

        #expect(session.hasPendingRequest == false)
        #expect(session.messages.last?.content == "ok")
        let snapshot = await repository.storedSessions()
        #expect(snapshot[session.id]?.hasPendingRequest == false)

        let requests = service.sendRequests
        #expect(requests.count == 2)
    }

    @Test("ChatSession reset clears conversation state")
    func testReset() {
        let repository = InMemoryChatSessionStore()
        let service = MockChatService()
        let session = ChatSession(service: service, persister: repository)

        session.reset()

        #expect(session.messages.count == 1)
        #expect(session.messages.first?.role == .assistant)
        #expect(session.hasPendingRequest == false)
        let snapshot = await repository.storedSessions()
        #expect(snapshot[session.id]?.hasPendingRequest == false)
    }
}
