import Foundation
import Testing
@testable import translation

struct ChatPersistenceManagerTests {

    // MARK: - Test Helpers

    private func createTestManager() -> ChatPersistenceManager {
        return ChatPersistenceManager()
    }

    private func createTestSessionData(id: UUID = UUID()) -> ChatSessionData {
        let messages = [
            TestHelpers.createTestMessage(role: .user, content: "Hello"),
            TestHelpers.createTestMessage(role: .assistant, content: "Hi there!")
        ]

        return ChatSessionData(
            id: id,
            messages: messages,
            state: .ready,
            checklist: ["Task 1", "Task 2"],
            researchResult: nil,
            hasPendingRequest: false,
            pendingRequestType: nil
        )
    }

    // MARK: - Initialization Tests

    @Test("ChatPersistenceManager initializes successfully")
    func testInitialization() {
        let manager = createTestManager()

        // 管理器應該成功初始化
        #expect(manager != nil)
    }

    // MARK: - Save Session Tests

    @Test("ChatPersistenceManager saves session successfully")
    func testSaveSession() {
        let manager = createTestManager()
        let sessionData = createTestSessionData()

        // 保存會話
        manager.save(sessionData)

        // 嘗試加載會話來驗證保存成功
        let loadedSession = manager.loadSession(id: sessionData.id)

        #expect(loadedSession != nil)
        #expect(loadedSession?.id == sessionData.id)
        #expect(loadedSession?.messages.count == sessionData.messages.count)
        #expect(loadedSession?.state == sessionData.state)
    }

    @Test("ChatPersistenceManager saves session with different states")
    func testSaveSessionDifferentStates() {
        let manager = createTestManager()

        let states: [ChatTurnResponse.State] = [.gathering, .ready, .completed]

        for state in states {
            let sessionData = ChatSessionData(
                id: UUID(),
                messages: [],
                state: state,
                checklist: nil,
                researchResult: nil,
                hasPendingRequest: false,
                pendingRequestType: nil
            )

            manager.save(sessionData)
            let loadedSession = manager.loadSession(id: sessionData.id)

            #expect(loadedSession?.state == state)
        }
    }

    // MARK: - Load Session Tests

    @Test("ChatPersistenceManager loads existing session")
    func testLoadExistingSession() {
        let manager = createTestManager()
        let sessionData = createTestSessionData()

        // 先保存會話
        manager.save(sessionData)

        // 然後加載會話
        let loadedSession = manager.loadSession(id: sessionData.id)

        #expect(loadedSession != nil)
        #expect(loadedSession?.id == sessionData.id)
        #expect(loadedSession?.messages.count == sessionData.messages.count)
        #expect(loadedSession?.messages.first?.content == "Hello")
        #expect(loadedSession?.messages.first?.role == .user)
        #expect(loadedSession?.checklist?.count == 2)
        #expect(loadedSession?.checklist?.first == "Task 1")
    }

    @Test("ChatPersistenceManager returns nil for non-existent session")
    func testLoadNonExistentSession() {
        let manager = createTestManager()
        let nonExistentID = UUID()

        let loadedSession = manager.loadSession(id: nonExistentID)

        #expect(loadedSession == nil)
    }

    // MARK: - Load Active Sessions Tests

    @Test("ChatPersistenceManager loads multiple active sessions")
    func testLoadActiveSessions() {
        let manager = createTestManager()

        // 清理現有會話
        manager.clearAll()

        // 創建多個會話
        let session1 = createTestSessionData()
        let session2 = createTestSessionData()
        let session3 = createTestSessionData()

        // 保存會話
        manager.save(session1)
        manager.save(session2)
        manager.save(session3)

        // 加載活躍會話
        let activeSessions = manager.loadAll()

        #expect(activeSessions.count == 3)

        let sessionIDs = Set(activeSessions.map { $0.id })
        #expect(sessionIDs.contains(session1.id))
        #expect(sessionIDs.contains(session2.id))
        #expect(sessionIDs.contains(session3.id))
    }

    @Test("ChatPersistenceManager returns empty array when no active sessions")
    func testLoadActiveSessionsEmpty() {
        let manager = createTestManager()

        // 清理所有會話
        manager.clearAll()

        let activeSessions = manager.loadAll()

        #expect(activeSessions.isEmpty)
    }

    // MARK: - Delete Session Tests

    @Test("ChatPersistenceManager deletes session successfully")
    func testDeleteSession() {
        let manager = createTestManager()
        let sessionData = createTestSessionData()

        // 先保存會話
        manager.save(sessionData)

        // 驗證會話存在
        let loadedSession = manager.loadSession(id: sessionData.id)
        #expect(loadedSession != nil)

        // 刪除會話
        manager.delete(id: sessionData.id)

        // 驗證會話已被刪除
        let deletedSession = manager.loadSession(id: sessionData.id)
        #expect(deletedSession == nil)
    }

    @Test("ChatPersistenceManager deletes non-existent session safely")
    func testDeleteNonExistentSession() {
        let manager = createTestManager()
        let nonExistentID = UUID()

        // 刪除不存在的會話應該安全執行
        manager.delete(id: nonExistentID)

        // 應該沒有崩潰或錯誤
        #expect(true)
    }

    // MARK: - Clear All Sessions Tests

    @Test("ChatPersistenceManager clears all sessions")
    func testClearAllSessions() {
        let manager = createTestManager()

        // 創建多個會話
        let session1 = createTestSessionData()
        let session2 = createTestSessionData()

        manager.save(session1)
        manager.save(session2)

        // 驗證會話存在
        #expect(manager.loadAll().count >= 2)

        // 清理所有會話
        manager.clearAll()

        // 驗證所有會話已被清理
        let activeSessions = manager.loadAll()
        #expect(activeSessions.isEmpty)
    }

    // MARK: - Data Integrity Tests

    @Test("ChatPersistenceManager preserves message order")
    func testMessageOrder() {
        let manager = createTestManager()

        let messages = [
            TestHelpers.createTestMessage(role: .user, content: "First message"),
            TestHelpers.createTestMessage(role: .assistant, content: "Second message"),
            TestHelpers.createTestMessage(role: .user, content: "Third message"),
            TestHelpers.createTestMessage(role: .assistant, content: "Fourth message")
        ]

        let sessionData = ChatSessionData(
            id: UUID(),
            messages: messages,
            state: .ready,
            checklist: nil,
            researchResult: nil,
            hasPendingRequest: false,
            pendingRequestType: nil
        )

        manager.save(sessionData)
        let loadedSession = manager.loadSession(id: sessionData.id)

        #expect(loadedSession?.messages.count == 4)
        #expect(loadedSession?.messages[0].content == "First message")
        #expect(loadedSession?.messages[1].content == "Second message")
        #expect(loadedSession?.messages[2].content == "Third message")
        #expect(loadedSession?.messages[3].content == "Fourth message")
    }

    @Test("ChatPersistenceManager preserves checklist data")
    func testChecklistPreservation() {
        let manager = createTestManager()

        let checklist = [
            "Complete task A",
            "Review task B",
            "Submit task C"
        ]

        let sessionData = ChatSessionData(
            id: UUID(),
            messages: [],
            state: .ready,
            checklist: checklist,
            researchResult: nil,
            hasPendingRequest: false,
            pendingRequestType: nil
        )

        manager.save(sessionData)
        let loadedSession = manager.loadSession(id: sessionData.id)

        #expect(loadedSession?.checklist != nil)
        #expect(loadedSession?.checklist?.count == 3)
        #expect(loadedSession?.checklist?[0] == "Complete task A")
        #expect(loadedSession?.checklist?[1] == "Review task B")
        #expect(loadedSession?.checklist?[2] == "Submit task C")
    }

    @Test("ChatPersistenceManager handles nil checklist")
    func testNilChecklist() {
        let manager = createTestManager()

        let sessionData = ChatSessionData(
            id: UUID(),
            messages: [],
            state: .ready,
            checklist: nil,
            researchResult: nil,
            hasPendingRequest: false,
            pendingRequestType: nil
        )

        manager.save(sessionData)
        let loadedSession = manager.loadSession(id: sessionData.id)

        #expect(loadedSession?.checklist == nil)
    }

    // MARK: - Edge Cases Tests

    @Test("ChatPersistenceManager handles empty messages")
    func testEmptyMessages() {
        let manager = createTestManager()

        let sessionData = ChatSessionData(
            id: UUID(),
            messages: [],
            state: .ready,
            checklist: nil,
            researchResult: nil,
            hasPendingRequest: false,
            pendingRequestType: nil
        )

        manager.save(sessionData)
        let loadedSession = manager.loadSession(id: sessionData.id)

        #expect(loadedSession?.messages.isEmpty == true)
    }

    @Test("ChatPersistenceManager handles very long messages")
    func testLongMessages() {
        let manager = createTestManager()

        let longContent = String(repeating: "A", count: 10000)
        let messages = [
            TestHelpers.createTestMessage(role: .user, content: longContent)
        ]

        let sessionData = ChatSessionData(
            id: UUID(),
            messages: messages,
            state: .ready,
            checklist: nil,
            researchResult: nil,
            hasPendingRequest: false,
            pendingRequestType: nil
        )

        manager.save(sessionData)
        let loadedSession = manager.loadSession(id: sessionData.id)

        #expect(loadedSession?.messages.first?.content == longContent)
    }

    @Test("ChatPersistenceManager handles special characters in messages")
    func testSpecialCharacters() {
        let manager = createTestManager()

        let specialContent = "Hello 👋 世界 🌍 Test & Co. (2024) 100% 💯"
        let messages = [
            TestHelpers.createTestMessage(role: .user, content: specialContent)
        ]

        let sessionData = ChatSessionData(
            id: UUID(),
            messages: messages,
            state: .ready,
            checklist: nil,
            researchResult: nil,
            hasPendingRequest: false,
            pendingRequestType: nil
        )

        manager.save(sessionData)
        let loadedSession = manager.loadSession(id: sessionData.id)

        #expect(loadedSession?.messages.first?.content == specialContent)
    }

    // MARK: - Concurrent Access Tests

    @Test("ChatPersistenceManager handles concurrent operations")
    func testConcurrentOperations() async {
        let manager = createTestManager()

        // 並行創建多個會話
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let sessionData = ChatSessionData(
                        id: UUID(),
                        messages: [TestHelpers.createTestMessage(role: .user, content: "Message \(i)")],
                        state: .ready,
                        checklist: nil,
                        researchResult: nil,
                        hasPendingRequest: false,
                        pendingRequestType: nil
                    )
                    manager.save(sessionData)
                }
            }
        }

        // 驗證所有會話都被保存
        let activeSessions = manager.loadAll()
        #expect(activeSessions.count >= 10)
    }
}