import Foundation
import Combine
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

actor InMemoryChatSessionStore: ChatSessionPersisting {
    private var storage: [UUID: ChatSessionData]
    private var saveCallCount: Int = 0
    private var deleteCallCount: Int = 0

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

    func storedSessions() -> [UUID: ChatSessionData] {
        storage
    }

    func savedCount() -> Int {
        saveCallCount
    }

    func deletedCount() -> Int {
        deleteCallCount
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

@MainActor
final class TestChatManager: ChatManaging, ObservableObject {
    @Published private var isBackgroundActiveInternal: Bool = false
    private let repository: InMemoryChatSessionStore
    private let service: MockChatService
    private let backgroundCoordinator: MockBackgroundCoordinator
    private var sessions: [UUID: ChatSession] = [:]

    init(
        service: MockChatService? = nil,
        repository: InMemoryChatSessionStore? = nil,
        backgroundCoordinator: MockBackgroundCoordinator? = nil
    ) {
        self.service = service ?? MockChatService()
        self.repository = repository ?? InMemoryChatSessionStore()
        self.backgroundCoordinator = backgroundCoordinator ?? MockBackgroundCoordinator()
    }

    var backgroundActivityPublisher: AnyPublisher<Bool, Never> {
        $isBackgroundActiveInternal.eraseToAnyPublisher()
    }

    func startChatSession(sessionID: UUID) -> ChatSession {
        if let existing = sessions[sessionID] {
            return existing
        }
        let session = ChatSession(id: sessionID, service: service, persister: repository)
        sessions[sessionID] = session
        Task { [weak session] in
            guard let data = await repository.loadSession(id: sessionID) else { return }
            guard let session else { return }
            await session.applyPersistedData(data)
        }
        return session
    }

    func sendMessage(sessionID: UUID, content: String, attachments: [ChatAttachment] = []) async {
        guard let session = sessions[sessionID] else { return }
        backgroundCoordinator.startBackgroundTaskIfNeeded()
        isBackgroundActiveInternal = true
        await session.sendMessage(content: content, attachments: attachments)
        isBackgroundActiveInternal = false
        backgroundCoordinator.endBackgroundTaskIfNeeded()
    }

    func runResearch(sessionID: UUID) async {
        guard let session = sessions[sessionID] else { return }
        backgroundCoordinator.startBackgroundTaskIfNeeded()
        isBackgroundActiveInternal = true
        await session.runResearch()
        isBackgroundActiveInternal = false
        backgroundCoordinator.endBackgroundTaskIfNeeded()
    }

    func removeSession(id: UUID) {
        sessions[id] = nil
        Task {
            await repository.delete(id: id)
        }
    }

    func simulateBackgroundActivity(_ active: Bool) {
        isBackgroundActiveInternal = active
    }
}
