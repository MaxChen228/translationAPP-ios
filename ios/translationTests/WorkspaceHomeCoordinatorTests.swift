import XCTest
@testable import translation

final class WorkspaceHomeCoordinatorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
    }

    @MainActor
    func testAddWorkspaceAppends() {
        let store = WorkspaceStore(correctionRunner: StubCorrectionRunner())
        let quickActions = makeQuickActionsStore()
        let router = RouterStore()
        let coordinator = WorkspaceHomeCoordinator()
        coordinator.configureIfNeeded(workspaceStore: store, quickActions: quickActions, router: router)

        let initial = store.workspaces.count
        coordinator.addWorkspace()

        XCTAssertEqual(store.workspaces.count, initial + 1)
    }

    @MainActor
    func testDeleteWorkspaceRemoves() {
        let store = WorkspaceStore(correctionRunner: StubCorrectionRunner())
        let quickActions = makeQuickActionsStore()
        let router = RouterStore()
        let coordinator = WorkspaceHomeCoordinator()
        coordinator.configureIfNeeded(workspaceStore: store, quickActions: quickActions, router: router)

        let id = store.workspaces.first!.id
        coordinator.deleteWorkspace(id)

        XCTAssertFalse(store.workspaces.contains(where: { $0.id == id }))
    }

    @MainActor
    func testToggleQuickActionsEditing() {
        let store = WorkspaceStore(correctionRunner: StubCorrectionRunner())
        let quickActions = makeQuickActionsStore()
        let router = RouterStore()
        let coordinator = WorkspaceHomeCoordinator()
        coordinator.configureIfNeeded(workspaceStore: store, quickActions: quickActions, router: router)

        coordinator.workspaceEditController.enterEditMode()
        coordinator.toggleQuickActionsEditing()

        XCTAssertTrue(coordinator.quickActionsEditController.isEditing)
        XCTAssertFalse(coordinator.workspaceEditController.isEditing)

        coordinator.toggleQuickActionsEditing()
        XCTAssertFalse(coordinator.quickActionsEditController.isEditing)
    }

    @MainActor
    func testWorkspaceDropReorders() {
        let store = WorkspaceStore(correctionRunner: StubCorrectionRunner())
        _ = store.addWorkspace()
        _ = store.addWorkspace()

        let quickActions = makeQuickActionsStore()
        let router = RouterStore()
        let coordinator = WorkspaceHomeCoordinator()
        coordinator.configureIfNeeded(workspaceStore: store, quickActions: quickActions, router: router)

        let firstID = store.workspaces[0].id
        let secondID = store.workspaces[1].id

        coordinator.workspaceEditController.enterEditMode()
        coordinator.workspaceEditController.beginDragging(firstID)

        coordinator.handleWorkspaceDropEntered(targetID: secondID)

        XCTAssertEqual(store.index(of: firstID), 1)
        XCTAssertEqual(store.index(of: secondID), 0)

        XCTAssertTrue(coordinator.handleWorkspaceDrop())
        XCTAssertNil(coordinator.workspaceEditController.draggingID)
    }

    @MainActor
    func testAppendQuickActionUpdatesStore() {
        let store = WorkspaceStore(correctionRunner: StubCorrectionRunner())
        let quickActions = makeQuickActionsStore()
        let router = RouterStore()
        let coordinator = WorkspaceHomeCoordinator()
        coordinator.configureIfNeeded(workspaceStore: store, quickActions: quickActions, router: router)

        let initialCount = quickActions.items.count
        coordinator.appendQuickAction(.calendar)

        XCTAssertEqual(quickActions.items.count, initialCount + 1)
        XCTAssertFalse(coordinator.showQuickActionPicker)
    }

    @MainActor
    func testHandleViewAppearBindsWorkspaceStores() {
        let store = WorkspaceStore(correctionRunner: StubCorrectionRunner())
        let quickActions = makeQuickActionsStore()
        let router = RouterStore()
        let coordinator = WorkspaceHomeCoordinator()
        coordinator.configureIfNeeded(workspaceStore: store, quickActions: quickActions, router: router)

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "local.bank.books")
        defaults.removeObject(forKey: "local.bank.progress")

        let localBank = LocalBankStore()
        let localProgress = LocalBankProgressStore()
        let practiceRecords = makePracticeRecordsStore()

        coordinator.handleViewAppear(
            localBank: localBank,
            localProgress: localProgress,
            practiceRecords: practiceRecords
        )

        XCTAssertTrue(store.localBankStore === localBank)
        XCTAssertTrue(store.localProgressStore === localProgress)
        XCTAssertTrue(store.practiceRecordsStore === practiceRecords)

        defaults.removeObject(forKey: "local.bank.books")
        defaults.removeObject(forKey: "local.bank.progress")
    }

    @MainActor
    private func makeQuickActionsStore() -> QuickActionsStore {
        let suite = "WorkspaceHomeCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return QuickActionsStore(userDefaults: defaults)
    }

    @MainActor
    private func makePracticeRecordsStore() -> PracticeRecordsStore {
        let repository = PracticeRecordsRepository(provider: MemoryPersistenceProvider())
        return PracticeRecordsStore(repository: repository)
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
