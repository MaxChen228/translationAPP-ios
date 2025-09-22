import XCTest
@testable import translation

final class QuickActionsCoordinatorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // 清空 UserDefaults，避免跨測試干擾
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
    }

    @MainActor
    func testHandleLocalPracticeCreatesWorkspaceAndRoutes() {
        let workspaceStore = WorkspaceStore(correctionRunner: StubCorrectionRunner())
        let quickActions = makeQuickActionsStore()
        let router = RouterStore()
        let localBank = LocalBankStore()
        let localProgress = LocalBankProgressStore()
        let editController = ShelfEditController<UUID>()

        let coordinator = QuickActionsCoordinator(
            workspaceStore: workspaceStore,
            quickActions: quickActions,
            router: router,
            localBank: localBank,
            localProgress: localProgress,
            editController: editController
        )

        let initialCount = workspaceStore.workspaces.count
        let item = BankItem(
            id: "bank-1",
            zh: "測試題目",
            hints: [BankHint(category: .lexical, text: "hint")],
            suggestions: []
        )

        coordinator.handleLocalPractice(bookName: "日常會話", item: item, tag: "tag")

        XCTAssertEqual(workspaceStore.workspaces.count, initialCount + 1)
        guard let opened = router.openWorkspaceID else {
            XCTFail("Router 未接收到新的 Workspace ID")
            return
        }

        XCTAssertEqual(workspaceStore.workspaces.last?.id, opened)

        let vm = workspaceStore.vm(for: opened)
        XCTAssertEqual(vm.practice.practiceSource, .local(bookName: "日常會話"))
        XCTAssertEqual(vm.practice.currentBankItemId, item.id)
    }

    @MainActor
    func testMoveReorderRespectsIndices() {
        let workspaceStore = WorkspaceStore(correctionRunner: StubCorrectionRunner())
        let quickActions = makeQuickActionsStore()
        let router = RouterStore()
        let localBank = LocalBankStore()
        let localProgress = LocalBankProgressStore()
        let editController = ShelfEditController<UUID>()

        let coordinator = QuickActionsCoordinator(
            workspaceStore: workspaceStore,
            quickActions: quickActions,
            router: router,
            localBank: localBank,
            localProgress: localProgress,
            editController: editController
        )

        let items = quickActions.items
        guard items.count >= 3 else {
            XCTFail("預設快速入口數量不足")
            return
        }

        coordinator.move(draggingID: items[0].id, above: items[1].id)

        XCTAssertEqual(quickActions.items[0].id, items[1].id)
        XCTAssertEqual(quickActions.items[2].id, items[0].id)
    }

    @MainActor
    func testMoveToEndAppends() {
        let workspaceStore = WorkspaceStore(correctionRunner: StubCorrectionRunner())
        let quickActions = makeQuickActionsStore()
        let router = RouterStore()
        let localBank = LocalBankStore()
        let localProgress = LocalBankProgressStore()
        let editController = ShelfEditController<UUID>()

        let coordinator = QuickActionsCoordinator(
            workspaceStore: workspaceStore,
            quickActions: quickActions,
            router: router,
            localBank: localBank,
            localProgress: localProgress,
            editController: editController
        )

        let firstID = quickActions.items.first!.id

        coordinator.moveToEnd(draggingID: firstID)

        XCTAssertEqual(quickActions.items.last?.id, firstID)
    }

    @MainActor
    private func makeQuickActionsStore() -> QuickActionsStore {
        let suite = "QuickActionsCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return QuickActionsStore(userDefaults: defaults)
    }
}

private struct StubCorrectionRunner: CorrectionRunning {
    func runCorrection(zh: String, en: String, bankItemId: String?, deviceId: String?, hints: [BankHint]?, suggestion: String?) async throws -> AICorrectionResult {
        AICorrectionResult(
            response: AIResponse(corrected: en, score: 0, errors: []),
            originalHighlights: nil,
            correctedHighlights: nil
        )
    }
}
