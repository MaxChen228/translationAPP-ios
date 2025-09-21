import Foundation
import Testing
import Combine
@testable import translation

@MainActor
struct ChatViewModelTests {

    // MARK: - Test Helpers

    private func createMockChatManager() -> ChatManager {
        // 使用真實的 ChatManager 但可以 mock 其依賴
        return ChatManager.shared
    }

    // MARK: - Initialization Tests

    @Test("ChatViewModel initializes with default state")
    func testInitialization() {
        let viewModel = ChatViewModel()

        #expect(viewModel.inputText.isEmpty)
        #expect(!viewModel.isBackgroundActive)
        #expect(!viewModel.showContinuationBanner)
        #expect(viewModel.messages.isEmpty)
        #expect(!viewModel.isLoading)
    }

    @Test("ChatViewModel initializes with existing sessionID")
    func testInitializationWithSessionID() {
        let sessionID = UUID()
        let viewModel = ChatViewModel(sessionID: sessionID)

        #expect(viewModel.inputText.isEmpty)
        #expect(!viewModel.isBackgroundActive)
    }

    // MARK: - Input Text Tests

    @Test("ChatViewModel updates input text")
    func testInputTextUpdate() {
        let viewModel = ChatViewModel()
        let testText = "Hello, world!"

        viewModel.inputText = testText

        #expect(viewModel.inputText == testText)
    }

    @Test("ChatViewModel clears input text")
    func testInputTextClear() {
        let viewModel = ChatViewModel()
        viewModel.inputText = "Some text"

        viewModel.inputText = ""

        #expect(viewModel.inputText.isEmpty)
    }

    // MARK: - Message Management Tests

    @Test("ChatViewModel sends message")
    func testSendMessage() async {
        let viewModel = ChatViewModel()
        let testMessage = "Test message"

        viewModel.inputText = testMessage

        // 測試發送訊息
        await viewModel.sendMessage()

        // 驗證輸入已清空
        #expect(viewModel.inputText.isEmpty)

        // 驗證訊息已添加到 messages
        #expect(!viewModel.messages.isEmpty)
        #expect(viewModel.messages.last?.content == testMessage)
        #expect(viewModel.messages.last?.role == .user)
    }

    @Test("ChatViewModel does not send empty message")
    func testSendEmptyMessage() async {
        let viewModel = ChatViewModel()
        let initialMessageCount = viewModel.messages.count

        viewModel.inputText = ""
        await viewModel.sendMessage()

        #expect(viewModel.messages.count == initialMessageCount)
    }

    @Test("ChatViewModel does not send whitespace-only message")
    func testSendWhitespaceMessage() async {
        let viewModel = ChatViewModel()
        let initialMessageCount = viewModel.messages.count

        viewModel.inputText = "   \n\t  "
        await viewModel.sendMessage()

        #expect(viewModel.messages.count == initialMessageCount)
    }

    // MARK: - State Management Tests

    @Test("ChatViewModel handles loading state")
    func testLoadingState() async {
        let viewModel = ChatViewModel()

        // 發送訊息會觸發 loading 狀態
        viewModel.inputText = "Test message"

        // 發送訊息並等待完成
        await viewModel.sendMessage()

        // 完成後應該不再 loading
        #expect(!viewModel.isLoading)
    }

    // MARK: - Continuation Banner Tests

    @Test("ChatViewModel shows continuation banner when appropriate")
    func testContinuationBanner() {
        let viewModel = ChatViewModel()

        // 測試 banner 顯示邏輯
        viewModel.showContinuationBanner = true
        #expect(viewModel.showContinuationBanner)

        viewModel.dismissContinuationBanner()
        #expect(!viewModel.showContinuationBanner)
    }

    @Test("ChatViewModel resumes pending request")
    func testResumePendingRequest() async {
        let viewModel = ChatViewModel()
        viewModel.showContinuationBanner = true

        await viewModel.resumePendingRequest()

        // Banner 應該被隱藏
        #expect(!viewModel.showContinuationBanner)
    }

    // MARK: - Session Management Tests

    @Test("ChatViewModel resets conversation")
    func testResetConversation() async {
        let viewModel = ChatViewModel()

        // 添加一些測試訊息
        viewModel.inputText = "Test message"
        await viewModel.sendMessage()

        // 驗證有訊息
        #expect(!viewModel.messages.isEmpty)

        viewModel.reset()

        // 對話應該被清空
        #expect(viewModel.messages.isEmpty)
        #expect(!viewModel.showContinuationBanner)
    }

    // MARK: - Research Tests

    @Test("ChatViewModel runs research")
    func testRunResearch() async {
        let viewModel = ChatViewModel()

        // 需要先有訊息才能執行研究
        viewModel.inputText = "Test message"
        await viewModel.sendMessage()

        await viewModel.runResearch()

        // 這個測試檢查研究功能是否被調用
        // 實際的研究結果取決於 API 回應
    }

    // MARK: - Background State Tests

    @Test("ChatViewModel tracks background state")
    func testBackgroundState() {
        let viewModel = ChatViewModel()

        // 初始狀態應該是非背景
        #expect(!viewModel.isBackgroundActive)

        // 這個測試檢查背景狀態追蹤
        // 實際的背景狀態變化由 ChatManager 控制
    }
}

// MARK: - Test Notes
// 這些測試依賴於實際的 ChatSession 實現
// 在真實的應用中，可能需要 dependency injection 來進行更好的測試隔離