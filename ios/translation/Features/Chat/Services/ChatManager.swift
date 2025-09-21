import Foundation
import BackgroundTasks
import SwiftUI
import UIKit

/// 全域聊天管理器，處理後台持續與狀態恢復
@MainActor
final class ChatManager: ObservableObject {
    static let shared = ChatManager()

    @Published var activeSessions: [UUID: ChatSession] = [:]
    @Published var isBackgroundTaskActive: Bool = false

    private let service: ChatService
    private let persistenceManager: ChatPersistenceManager
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private init() {
        self.service = ChatServiceFactory.makeDefault()
        self.persistenceManager = ChatPersistenceManager()
        setupBackgroundTaskHandler()
        restoreActiveSessions()
    }

    // MARK: - Public API

    /// 開始新的聊天會話
    func startChatSession(sessionID: UUID = UUID()) -> ChatSession {
        if let existing = activeSessions[sessionID] {
            return existing
        }

        if let restored = persistenceManager.loadSession(id: sessionID) {
            let session = ChatSession(from: restored, service: service, persistenceManager: persistenceManager)
            activeSessions[sessionID] = session
            return session
        }

        let session = ChatSession(
            id: sessionID,
            service: service,
            persistenceManager: persistenceManager
        )
        activeSessions[sessionID] = session
        return session
    }

    /// 發送訊息（後台安全）
    func sendMessage(sessionID: UUID, content: String, attachments: [ChatAttachment] = []) async {
        guard let session = activeSessions[sessionID] else { return }

        await startBackgroundTaskIfNeeded()
        await session.sendMessage(content: content, attachments: attachments)
        await endBackgroundTaskIfNeeded()
    }

    /// 執行研究（後台安全）
    func runResearch(sessionID: UUID) async {
        guard let session = activeSessions[sessionID] else { return }

        await startBackgroundTaskIfNeeded()
        await session.runResearch()
        await endBackgroundTaskIfNeeded()
    }

    // MARK: - Background Task Management

    private func setupBackgroundTaskHandler() {
        // 註冊後台任務處理器
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.translation.chat.background", using: nil) { task in
            self.handleBackgroundTask(task: task as! BGAppRefreshTask)
        }
    }

    private func startBackgroundTaskIfNeeded() async {
        guard backgroundTaskID == .invalid else { return }

        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "ChatGeneration") {
            Task { @MainActor in
                await self.endBackgroundTaskIfNeeded()
            }
        }

        isBackgroundTaskActive = true
        print("🔄 Started background task for chat")
    }

    private func endBackgroundTaskIfNeeded() async {
        guard backgroundTaskID != .invalid else { return }

        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
        isBackgroundTaskActive = false
        print("✅ Ended background task for chat")
    }

    private func handleBackgroundTask(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // 處理未完成的聊天請求
        Task {
            await resumePendingChats()
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - State Persistence & Recovery

    private func restoreActiveSessions() {
        let sessions = persistenceManager.loadActiveSessions()
        for sessionData in sessions {
            let session = ChatSession(
                from: sessionData,
                service: service,
                persistenceManager: persistenceManager
            )
            activeSessions[session.id] = session
        }
    }

    private func resumePendingChats() async {
        for session in activeSessions.values {
            if session.hasPendingRequest {
                await session.resumePendingRequest()
            }
        }
    }
}

/// 個別聊天會話
@MainActor
final class ChatSession: ObservableObject, Identifiable {
    let id: UUID
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var state: ChatTurnResponse.State = .gathering
    @Published var checklist: [String]? = nil
    @Published var researchResult: ChatResearchResponse? = nil
    @Published var errorMessage: String? = nil
    @Published var hasPendingRequest: Bool = false

    private let service: ChatService
    private let persistenceManager: ChatPersistenceManager
    private var pendingRequestType: PendingRequestType?

    enum PendingRequestType: Codable {
        case message(content: String, attachments: [ChatAttachment])
        case research
    }

    init(id: UUID = UUID(), service: ChatService, persistenceManager: ChatPersistenceManager) {
        self.id = id
        self.service = service
        self.persistenceManager = persistenceManager
        self.messages = [ChatMessage(role: .assistant, content: String(localized: "chat.greeting"))]
        persistState()
    }

    init(from sessionData: ChatSessionData, service: ChatService, persistenceManager: ChatPersistenceManager) {
        self.id = sessionData.id
        self.service = service
        self.persistenceManager = persistenceManager
        self.messages = sessionData.messages
        self.state = sessionData.state
        self.checklist = sessionData.checklist
        self.researchResult = sessionData.researchResult
        self.hasPendingRequest = sessionData.hasPendingRequest
        self.pendingRequestType = sessionData.pendingRequestType
    }

    func sendMessage(content: String, attachments: [ChatAttachment] = [], appendUserMessage: Bool = true) async {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !attachments.isEmpty else { return }

        if appendUserMessage {
            messages.append(ChatMessage(role: .user, content: trimmed, attachments: attachments))
        }

        pendingRequestType = .message(content: trimmed, attachments: attachments)
        hasPendingRequest = true
        persistState()

        isLoading = true

        do {
            let resp = try await service.send(messages: messages)
            checklist = resp.checklist
            state = resp.state
            messages.append(ChatMessage(role: .assistant, content: resp.reply))
            errorMessage = nil

            pendingRequestType = nil
            hasPendingRequest = false
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }

        isLoading = false
        persistState()
    }

    func runResearch() async {
        guard !messages.isEmpty else { return }

        pendingRequestType = .research
        hasPendingRequest = true
        persistState()

        isLoading = true

        do {
            let res = try await service.research(messages: messages)
            researchResult = res
            let bulletList = res.items.map { "• \($0.term)" }.joined(separator: "\n")
            let messageText = bulletList.isEmpty ? String(localized: "chat.research.ready") : bulletList
            messages.append(ChatMessage(role: .assistant, content: messageText))
            errorMessage = nil

            pendingRequestType = nil
            hasPendingRequest = false
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }

        isLoading = false
        persistState()
    }

    func resumePendingRequest() async {
        guard let pendingType = pendingRequestType else { return }

        switch pendingType {
        case .message(let content, let attachments):
            await sendMessage(content: content, attachments: attachments, appendUserMessage: false)
        case .research:
            await runResearch()
        }
    }

    func reset() {
        messages = [ChatMessage(role: .assistant, content: String(localized: "chat.greeting"))]
        checklist = nil
        researchResult = nil
        state = .gathering
        pendingRequestType = nil
        hasPendingRequest = false
        persistState()
    }

    private func persistState() {
        let sessionData = ChatSessionData(
            id: id,
            messages: messages,
            state: state,
            checklist: checklist,
            researchResult: researchResult,
            hasPendingRequest: hasPendingRequest,
            pendingRequestType: pendingRequestType
        )
        persistenceManager.saveSession(sessionData)
    }
}
