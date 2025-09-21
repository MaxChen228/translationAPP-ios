import Foundation
import Testing
@testable import translation

@MainActor
struct WorkspaceStoreTests {

    // MARK: - Test Helpers

    private func createTestStore() -> WorkspaceStore {
        // 為測試創建獨立的 store，避免持久化影響
        let store = WorkspaceStore()
        // 清空現有數據（使用實際的 remove 方法）
        let existingIDs = store.workspaces.map { $0.id }
        for id in existingIDs {
            store.remove(id)
        }
        return store
    }

    // MARK: - Initialization Tests

    @Test("WorkspaceStore initializes with default workspace")
    func testInitialization() {
        let store = WorkspaceStore()

        // 應該至少有一個預設工作區
        #expect(!store.workspaces.isEmpty)
        #expect(store.workspaces.first?.name == "Workspace 1")
    }

    @Test("WorkspaceStore creates workspace with UUID")
    func testWorkspaceHasUUID() {
        let store = createTestStore()
        let workspace = store.addWorkspace(name: "Test Workspace")

        #expect(workspace.id != UUID())
        #expect(workspace.name == "Test Workspace")
    }

    // MARK: - Workspace Management Tests

    @Test("WorkspaceStore adds new workspace")
    func testAddWorkspace() {
        let store = createTestStore()
        let initialCount = store.workspaces.count

        let workspace = store.addWorkspace(name: "New Workspace")

        #expect(store.workspaces.count == initialCount + 1)
        #expect(store.workspaces.contains(workspace))
        #expect(workspace.name == "New Workspace")
    }

    @Test("WorkspaceStore adds workspace with auto-generated name")
    func testAddWorkspaceWithAutoName() {
        let store = createTestStore()

        let workspace1 = store.addWorkspace()
        let workspace2 = store.addWorkspace()

        #expect(workspace1.name == "Workspace 1")
        #expect(workspace2.name == "Workspace 2")
    }

    @Test("WorkspaceStore removes workspace")
    func testRemoveWorkspace() {
        let store = createTestStore()
        let workspace = store.addWorkspace(name: "To Remove")
        let initialCount = store.workspaces.count

        store.remove(workspace.id)

        #expect(store.workspaces.count == initialCount - 1)
        #expect(!store.workspaces.contains(workspace))
    }

    @Test("WorkspaceStore removes non-existent workspace safely")
    func testRemoveNonExistentWorkspace() {
        let store = createTestStore()
        let initialCount = store.workspaces.count
        let nonExistentID = UUID()

        store.remove(nonExistentID)

        #expect(store.workspaces.count == initialCount)
    }

    @Test("WorkspaceStore updates workspace name")
    func testUpdateWorkspaceName() {
        let store = createTestStore()
        let workspace = store.addWorkspace(name: "Original Name")
        let newName = "Updated Name"

        store.rename(workspace.id, to: newName)

        let updatedWorkspace = store.workspaces.first { $0.id == workspace.id }
        #expect(updatedWorkspace?.name == newName)
    }

    @Test("WorkspaceStore updates non-existent workspace safely")
    func testUpdateNonExistentWorkspace() {
        let store = createTestStore()
        let originalWorkspaces = store.workspaces
        let nonExistentID = UUID()

        store.rename(nonExistentID, to: "New Name")

        #expect(store.workspaces == originalWorkspaces)
    }

    // MARK: - ViewModel Management Tests

    @Test("WorkspaceStore creates ViewModel for workspace")
    func testCreateViewModel() {
        let store = createTestStore()
        let workspace = store.addWorkspace(name: "Test Workspace")

        let viewModel = store.vm(for: workspace.id)

        #expect(viewModel != nil)
        // 再次請求相同的 ViewModel 應該返回同一個實例
        let sameViewModel = store.vm(for: workspace.id)
        #expect(viewModel === sameViewModel)
    }

    @Test("WorkspaceStore creates different ViewModels for different workspaces")
    func testCreateDifferentViewModels() {
        let store = createTestStore()
        let workspace1 = store.addWorkspace(name: "Workspace 1")
        let workspace2 = store.addWorkspace(name: "Workspace 2")

        let viewModel1 = store.vm(for: workspace1.id)
        let viewModel2 = store.vm(for: workspace2.id)

        #expect(viewModel1 !== viewModel2)
    }

    // MARK: - Persistence Tests

    @Test("WorkspaceStore persists workspaces")
    func testPersistence() {
        let store1 = createTestStore()
        let workspace = store1.addWorkspace(name: "Persistent Workspace")

        // 創建新的 store 實例來測試持久化
        let store2 = WorkspaceStore()

        // 新 store 應該包含之前添加的工作區
        let foundWorkspace = store2.workspaces.first { $0.id == workspace.id }
        #expect(foundWorkspace?.name == "Persistent Workspace")
    }

    @Test("WorkspaceStore clears all workspaces")
    func testClearAllWorkspaces() {
        let store = createTestStore()
        store.addWorkspace(name: "Workspace 1")
        store.addWorkspace(name: "Workspace 2")

        // 清理所有工作區
        let allIDs = store.workspaces.map { $0.id }
        for id in allIDs {
            store.remove(id)
        }

        #expect(store.workspaces.isEmpty)
    }

    // MARK: - Workspace Ordering Tests

    @Test("WorkspaceStore maintains workspace order")
    func testWorkspaceOrder() {
        let store = createTestStore()

        let workspace1 = store.addWorkspace(name: "First")
        let workspace2 = store.addWorkspace(name: "Second")
        let workspace3 = store.addWorkspace(name: "Third")

        #expect(store.workspaces[0].name == "First")
        #expect(store.workspaces[1].name == "Second")
        #expect(store.workspaces[2].name == "Third")
    }

    @Test("WorkspaceStore reorders workspaces")
    func testReorderWorkspaces() {
        let store = createTestStore()

        let workspace1 = store.addWorkspace(name: "First")
        let workspace2 = store.addWorkspace(name: "Second")
        let workspace3 = store.addWorkspace(name: "Third")

        // 重新排序：將第三個移到第一個位置
        store.moveWorkspace(id: workspace3.id, to: 0)

        #expect(store.workspaces[0].name == "Third")
        #expect(store.workspaces[1].name == "First")
        #expect(store.workspaces[2].name == "Second")
    }

    // MARK: - Edge Cases Tests

    @Test("WorkspaceStore handles empty workspace name")
    func testEmptyWorkspaceName() {
        let store = createTestStore()

        let workspace = store.addWorkspace(name: "")

        #expect(workspace.name.isEmpty)
        #expect(store.workspaces.contains(workspace))
    }

    @Test("WorkspaceStore handles very long workspace name")
    func testLongWorkspaceName() {
        let store = createTestStore()
        let longName = String(repeating: "A", count: 1000)

        let workspace = store.addWorkspace(name: longName)

        #expect(workspace.name == longName)
        #expect(store.workspaces.contains(workspace))
    }

    @Test("WorkspaceStore handles special characters in name")
    func testSpecialCharactersInName() {
        let store = createTestStore()
        let specialName = "工作區 🚀 Test & Co. (2024)"

        let workspace = store.addWorkspace(name: specialName)

        #expect(workspace.name == specialName)
        #expect(store.workspaces.contains(workspace))
    }

    // MARK: - Performance Tests

    @Test("WorkspaceStore handles many workspaces efficiently")
    func testManyWorkspaces() {
        let store = createTestStore()
        let workspaceCount = 100

        let startTime = CFAbsoluteTimeGetCurrent()

        for i in 1...workspaceCount {
            store.addWorkspace(name: "Workspace \(i)")
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        #expect(store.workspaces.count == workspaceCount)
        #expect(duration < 1.0) // 應該在 1 秒內完成
    }
}

// MARK: - Test Notes
// 測試使用了 WorkspaceStore 的實際 API：
// - addWorkspace(name:) -> Workspace
// - remove(_:)
// - rename(_:to:)
// - moveWorkspace(id:to:)