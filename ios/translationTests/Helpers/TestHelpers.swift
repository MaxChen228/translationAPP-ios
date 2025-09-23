import Foundation
@testable import translation

/// 測試輔助工具
enum TestHelpers {

    /// 創建測試用的臨時目錄
    static func createTempDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TranslationTests")
            .appendingPathComponent(UUID().uuidString)

        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// 清理測試用的臨時目錄
    static func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// 等待異步操作完成
    static func waitForAsync(timeout: TimeInterval = 2.0) async {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }

    /// 創建測試用的 ChatMessage
    static func createTestMessage(role: ChatMessage.Role, content: String) -> ChatMessage {
        return ChatMessage(role: role, content: content)
    }

    /// 創建測試用的 ChatSessionData
    static func createTestSessionData(
        id: UUID = UUID(),
        messages: [ChatMessage] = [],
        state: ChatTurnResponse.State = .ready
    ) -> ChatSessionData {
        return ChatSessionData(
            id: id,
            messages: messages,
            state: state,
            checklist: nil,
            researchDeck: nil,
            hasPendingRequest: false,
            pendingRequestType: nil
        )
    }
}
