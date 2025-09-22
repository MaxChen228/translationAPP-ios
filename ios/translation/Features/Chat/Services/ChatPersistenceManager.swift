import Foundation

protocol ChatSessionRepository {
    func save(_ session: ChatSessionData)
    func loadSession(id: UUID) -> ChatSessionData?
    func loadAll() -> [ChatSessionData]
    func delete(id: UUID)
    func clearAll()
}

enum ChatPendingRequestType: Codable, Equatable {
    case message(content: String, attachments: [ChatAttachment])
    case research
}

struct ChatSessionData: Codable, Equatable {
    let id: UUID
    let messages: [ChatMessage]
    let state: ChatTurnResponse.State
    let checklist: [String]?
    let researchResult: ChatResearchResponse?
    let hasPendingRequest: Bool
    let pendingRequestType: ChatPendingRequestType?
    let savedAt: Date

    init(
        id: UUID,
        messages: [ChatMessage],
        state: ChatTurnResponse.State,
        checklist: [String]?,
        researchResult: ChatResearchResponse?,
        hasPendingRequest: Bool,
        pendingRequestType: ChatPendingRequestType?,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.messages = messages
        self.state = state
        self.checklist = checklist
        self.researchResult = researchResult
        self.hasPendingRequest = hasPendingRequest
        self.pendingRequestType = pendingRequestType
        self.savedAt = savedAt
    }
}

final class FileChatSessionRepository: ChatSessionRepository {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let directory: URL

    init(baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        if let baseDirectory {
            self.directory = baseDirectory.appendingPathComponent("ChatSessions", isDirectory: true)
        } else {
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.directory = documents.appendingPathComponent("ChatSessions", isDirectory: true)
        }
        createDirectoriesIfNeeded()
    }

    func save(_ session: ChatSessionData) {
        do {
            let data = try encoder.encode(session)
            try data.write(to: fileURL(for: session.id), options: .atomic)
        } catch {
            AppLog.chatError("Failed to save chat session: \(error)")
        }
    }

    func loadSession(id: UUID) -> ChatSessionData? {
        do {
            let data = try Data(contentsOf: fileURL(for: id))
            return try decoder.decode(ChatSessionData.self, from: data)
        } catch {
            AppLog.chatError("Failed to load chat session \(id): \(error)")
            return nil
        }
    }

    func loadAll() -> [ChatSessionData] {
        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            return files.compactMap { url in
                do {
                    let data = try Data(contentsOf: url)
                    return try decoder.decode(ChatSessionData.self, from: data)
                } catch {
                    return nil
                }
            }
        } catch {
            AppLog.chatError("Failed to load chat sessions: \(error)")
            return []
        }
    }

    func delete(id: UUID) {
        do {
            try fileManager.removeItem(at: fileURL(for: id))
        } catch {
            AppLog.chatError("Failed to delete chat session \(id): \(error)")
        }
    }

    func clearAll() {
        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
        } catch {
            AppLog.chatError("Failed to clear chat sessions: \(error)")
        }
    }

    private func createDirectoriesIfNeeded() {
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            AppLog.chatError("Failed to create chat session directory: \(error)")
        }
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}

typealias ChatPersistenceManager = FileChatSessionRepository
