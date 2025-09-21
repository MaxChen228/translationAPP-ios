import Foundation

/// 聊天狀態持久化管理器
final class ChatPersistenceManager {
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var chatSessionsDirectory: URL {
        documentsDirectory.appendingPathComponent("ChatSessions", isDirectory: true)
    }

    init() {
        createDirectoriesIfNeeded()
    }

    // MARK: - Session Management

    func saveSession(_ sessionData: ChatSessionData) {
        do {
            let data = try encoder.encode(sessionData)
            let fileURL = sessionFileURL(for: sessionData.id)
            try data.write(to: fileURL)
        } catch {
            AppLog.chatError("Failed to save chat session: \(error)")
        }
    }

    func loadSession(id: UUID) -> ChatSessionData? {
        do {
            let fileURL = sessionFileURL(for: id)
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(ChatSessionData.self, from: data)
        } catch {
            AppLog.chatError("Failed to load chat session \(id): \(error)")
            return nil
        }
    }

    func loadActiveSessions() -> [ChatSessionData] {
        do {
            let sessionFiles = try fileManager.contentsOfDirectory(at: chatSessionsDirectory, includingPropertiesForKeys: nil)
            return sessionFiles.compactMap { fileURL in
                do {
                    let data = try Data(contentsOf: fileURL)
                    return try decoder.decode(ChatSessionData.self, from: data)
                } catch {
                    return nil
                }
            }
        } catch {
            AppLog.chatError("Failed to load active sessions: \(error)")
            return []
        }
    }

    func deleteSession(id: UUID) {
        do {
            let fileURL = sessionFileURL(for: id)
            try fileManager.removeItem(at: fileURL)
        } catch {
            AppLog.chatError("Failed to delete session \(id): \(error)")
        }
    }

    func clearAllSessions() {
        do {
            let sessionFiles = try fileManager.contentsOfDirectory(at: chatSessionsDirectory, includingPropertiesForKeys: nil)
            for fileURL in sessionFiles {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            AppLog.chatError("Failed to clear sessions: \(error)")
        }
    }

    // MARK: - Helper Methods

    private func createDirectoriesIfNeeded() {
        do {
            try fileManager.createDirectory(at: chatSessionsDirectory, withIntermediateDirectories: true)
        } catch {
            AppLog.chatError("Failed to create chat sessions directory: \(error)")
        }
    }

    private func sessionFileURL(for sessionID: UUID) -> URL {
        chatSessionsDirectory.appendingPathComponent("\(sessionID.uuidString).json")
    }
}

/// 聊天會話數據結構
struct ChatSessionData: Codable {
    let id: UUID
    let messages: [ChatMessage]
    let state: ChatTurnResponse.State
    let checklist: [String]?
    let researchResult: ChatResearchResponse?
    let hasPendingRequest: Bool
    let pendingRequestType: ChatSession.PendingRequestType?
    let savedAt: Date

    init(
        id: UUID,
        messages: [ChatMessage],
        state: ChatTurnResponse.State,
        checklist: [String]?,
        researchResult: ChatResearchResponse?,
        hasPendingRequest: Bool,
        pendingRequestType: ChatSession.PendingRequestType?
    ) {
        self.id = id
        self.messages = messages
        self.state = state
        self.checklist = checklist
        self.researchResult = researchResult
        self.hasPendingRequest = hasPendingRequest
        self.pendingRequestType = pendingRequestType
        self.savedAt = Date()
    }
}