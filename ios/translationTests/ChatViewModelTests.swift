import Foundation
import Testing
@testable import translation

@MainActor
struct ChatViewModelTests {

    // MARK: - Test Helpers

    private func makeViewModel(sessionID: UUID? = nil) -> (ChatViewModel, TestChatManager) {
        let manager = TestChatManager()
        let viewModel = ChatViewModel(sessionID: sessionID, chatManager: manager)
        return (viewModel, manager)
    }

    // MARK: - Initialization Tests

    @Test("ChatViewModel initializes with default state")
    func testInitialization() {
        let (viewModel, _) = makeViewModel()

        #expect(viewModel.inputText.isEmpty)
        #expect(!viewModel.isBackgroundActive)
        #expect(!viewModel.showContinuationBanner)
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.role == .assistant)
        #expect(!viewModel.isLoading)
    }

    @Test("ChatViewModel initializes with existing sessionID")
    func testInitializationWithSessionID() {
        let sessionID = UUID()
        let (viewModel, _) = makeViewModel(sessionID: sessionID)

        #expect(viewModel.inputText.isEmpty)
        #expect(!viewModel.isBackgroundActive)
        #expect(!viewModel.messages.isEmpty)
        #expect(viewModel.messages.first?.role == .assistant)
    }

    // MARK: - Input Text Tests

    @Test("ChatViewModel updates input text")
    func testInputTextUpdate() {
        let (viewModel, _) = makeViewModel()
        let testText = "Hello, world!"

        viewModel.inputText = testText

        #expect(viewModel.inputText == testText)
    }

    @Test("ChatViewModel clears input text")
    func testInputTextClear() {
        let (viewModel, _) = makeViewModel()
        viewModel.inputText = "Some text"

        viewModel.inputText = ""

        #expect(viewModel.inputText.isEmpty)
    }

    // MARK: - Message Management Tests

    @Test("ChatViewModel sends message")
    func testSendMessage() async {
        let (viewModel, _) = makeViewModel()
        let testMessage = "Test message"

        viewModel.inputText = testMessage

        await viewModel.sendMessage()

        #expect(viewModel.inputText.isEmpty)
        #expect(!viewModel.messages.isEmpty)
        let userMessages = viewModel.messages.filter { $0.role == .user }
        #expect(userMessages.last?.content == testMessage)
    }

    @Test("ChatViewModel does not send empty message")
    func testSendEmptyMessage() async {
        let (viewModel, _) = makeViewModel()
        let initialMessageCount = viewModel.messages.count

        viewModel.inputText = ""
        await viewModel.sendMessage()

        #expect(viewModel.messages.count == initialMessageCount)
    }

    @Test("ChatViewModel does not send whitespace-only message")
    func testSendWhitespaceMessage() async {
        let (viewModel, _) = makeViewModel()
        let initialMessageCount = viewModel.messages.count

        viewModel.inputText = "   \n\t  "
        await viewModel.sendMessage()

        #expect(viewModel.messages.count == initialMessageCount)
    }

    // MARK: - State Management Tests

    @Test("ChatViewModel handles loading state")
    func testLoadingState() async {
        let (viewModel, _) = makeViewModel()
        viewModel.inputText = "Test message"

        await viewModel.sendMessage()

        #expect(!viewModel.isLoading)
    }

    // MARK: - Continuation Banner Tests

    @Test("ChatViewModel shows continuation banner when appropriate")
    func testContinuationBanner() {
        let (viewModel, _) = makeViewModel()

        viewModel.showContinuationBanner = true
        #expect(viewModel.showContinuationBanner)

        viewModel.dismissContinuationBanner()
        #expect(!viewModel.showContinuationBanner)
    }

    @Test("ChatViewModel resumes pending request")
    func testResumePendingRequest() async {
        let (viewModel, _) = makeViewModel()
        viewModel.showContinuationBanner = true

        await viewModel.resumePendingRequest()

        #expect(!viewModel.showContinuationBanner)
    }

    // MARK: - Session Management Tests

    @Test("ChatViewModel resets conversation")
    func testResetConversation() async {
        let (viewModel, _) = makeViewModel()

        viewModel.inputText = "Test message"
        await viewModel.sendMessage()

        #expect(!viewModel.messages.isEmpty)

        viewModel.reset()

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.role == .assistant)
        #expect(!viewModel.showContinuationBanner)
    }

    // MARK: - Research Tests

    @Test("ChatViewModel runs research")
    func testRunResearch() async {
        let (viewModel, _) = makeViewModel()

        viewModel.inputText = "Test message"
        await viewModel.sendMessage()

        await viewModel.runResearch()
    }

    // MARK: - Background State Tests

    @Test("ChatViewModel tracks background state")
    func testBackgroundState() async {
        let (viewModel, manager) = makeViewModel()
        #expect(!viewModel.isBackgroundActive)

        manager.simulateBackgroundActivity(true)
        await Task.yield()
        #expect(viewModel.isBackgroundActive)

        manager.simulateBackgroundActivity(false)
        await Task.yield()
        #expect(!viewModel.isBackgroundActive)
    }
}
