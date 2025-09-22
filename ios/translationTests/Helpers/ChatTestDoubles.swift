import Foundation
@testable import translation

enum MockChatError: Error {
    case failure
}

@MainActor
final class MockChatService: ChatService {
    private var sendResult: Result<ChatTurnResponse, Error>
    private var researchResult: Result<ChatResearchResponse, Error>

    private(set) var sendRequests: [[ChatMessage]] = []
    private(set) var researchRequests: [[ChatMessage]] = []

    init(
        sendResult: Result<ChatTurnResponse, Error> = .success(ChatTurnResponse(reply: "Mock reply", state: .ready, checklist: ["item"])),
        researchResult: Result<ChatResearchResponse, Error> = .success(ChatResearchResponse(items: [ChatResearchItem(term: "term", explanation: "explanation", context: "context", type: .lexical)]))
    ) {
        self.sendResult = sendResult
        self.researchResult = researchResult
    }

    func setSendResult(_ result: Result<ChatTurnResponse, Error>) {
        sendResult = result
    }

    func setResearchResult(_ result: Result<ChatResearchResponse, Error>) {
        researchResult = result
    }

    func send(messages: [ChatMessage]) async throws -> ChatTurnResponse {
        sendRequests.append(messages)
        switch sendResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func research(messages: [ChatMessage]) async throws -> ChatResearchResponse {
        researchRequests.append(messages)
        switch researchResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}

final class InMemoryChatSessionRepository: ChatSessionRepository {
    private(set) var storage: [UUID: ChatSessionData]
    private(set) var saveCallCount: Int = 0
    private(set) var deleteCallCount: Int = 0

    init(initial: [UUID: ChatSessionData] = [:]) {
        self.storage = initial
    }

    func save(_ session: ChatSessionData) {
        storage[session.id] = session
        saveCallCount += 1
    }

    func loadSession(id: UUID) -> ChatSessionData? {
        storage[id]
    }

    func loadAll() -> [ChatSessionData] {
        Array(storage.values)
    }

    func delete(id: UUID) {
        storage[id] = nil
        deleteCallCount += 1
    }

    func clearAll() {
        storage.removeAll()
    }
}

@MainActor
final class MockBackgroundCoordinator: ChatBackgroundCoordinating {
    private(set) var isBackgroundTaskActive: Bool = false
    private var resumeHandler: (() async -> Void)?

    private(set) var startCallCount: Int = 0
    private(set) var endCallCount: Int = 0

    func configure(resumeHandler: @escaping () async -> Void) {
        self.resumeHandler = resumeHandler
    }

    func startBackgroundTaskIfNeeded() {
        startCallCount += 1
        isBackgroundTaskActive = true
    }

    func endBackgroundTaskIfNeeded() {
        endCallCount += 1
        isBackgroundTaskActive = false
    }

    func triggerResume() async {
        await resumeHandler?()
    }
}
