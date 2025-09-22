import SwiftUI
import Combine

enum WorkspaceRoute: Hashable {
    case workspace(UUID)
}

@MainActor
final class WorkspaceHomeCoordinator: ObservableObject {
    @Published var navigationPath: [WorkspaceRoute] = []
    @Published var renamingWorkspace: Workspace?
    @Published var renameDraft: String = ""
    @Published var showQuickActionPicker: Bool = false

    let workspaceEditController = ShelfEditController<UUID>()
    let quickActionsEditController = ShelfEditController<UUID>()

    private weak var workspaceStore: WorkspaceStore?
    private weak var quickActionsStore: QuickActionsStore?
    private weak var router: RouterStore?

    private var cancellables: Set<AnyCancellable> = []
    private var isConfigured = false

    func configureIfNeeded(
        workspaceStore: WorkspaceStore,
        quickActions: QuickActionsStore,
        router: RouterStore
    ) {
        guard !isConfigured else { return }
        self.workspaceStore = workspaceStore
        self.quickActionsStore = quickActions
        self.router = router
        isConfigured = true

        router.$openWorkspaceID
            .compactMap { $0 }
            .sink { [weak self] id in
                guard let self else { return }
                self.navigationPath.append(.workspace(id))
                self.router?.openWorkspaceID = nil
            }
            .store(in: &cancellables)
    }

    func addWorkspace() {
        workspaceEditController.exitEditMode()
        _ = workspaceStore?.addWorkspace()
    }

    func deleteWorkspace(_ id: UUID) {
        workspaceStore?.remove(id)
    }

    func startRename(_ workspace: Workspace) {
        workspaceEditController.exitEditMode()
        quickActionsEditController.exitEditMode()
        renameDraft = workspace.name
        renamingWorkspace = workspace
    }

    func cancelRename() {
        renamingWorkspace = nil
    }

    func commitRename(newName: String, store: WorkspaceStore) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let workspace = renamingWorkspace else {
            renamingWorkspace = nil
            return
        }
        store.rename(workspace.id, to: trimmed)
        renamingWorkspace = nil
    }

    func toggleQuickActionsEditing() {
        if quickActionsEditController.isEditing {
            showQuickActionPicker = false
            quickActionsEditController.exitEditMode()
        } else {
            workspaceEditController.exitEditMode()
            quickActionsEditController.enterEditMode()
        }
    }

    func handleAddQuickActionTapped() {
        if !quickActionsEditController.isEditing {
            quickActionsEditController.enterEditMode()
        }
        showQuickActionPicker = true
    }

    func appendQuickAction(_ type: QuickActionType) {
        quickActionsStore?.append(type)
        showQuickActionPicker = false
    }

    func quickActionsEditingChanged(isEditing: Bool) {
        if isEditing {
            workspaceEditController.exitEditMode()
        }
    }

    func workspaceEditingChanged(isEditing: Bool) {
        if isEditing {
            quickActionsEditController.exitEditMode()
        }
    }

    func handleWorkspaceDropEntered(targetID: UUID) {
        guard workspaceEditController.isEditing,
              let store = workspaceStore,
              let draggingID = workspaceEditController.draggingID,
              draggingID != targetID,
              let from = store.index(of: draggingID),
              let to = store.index(of: targetID) else { return }
        store.moveWorkspace(id: draggingID, to: to > from ? to + 1 : to)
        Haptics.lightTick()
    }

    @discardableResult
    func handleWorkspaceDrop() -> Bool {
        guard workspaceEditController.isEditing else { return false }
        workspaceEditController.endDragging()
        Haptics.success()
        return true
    }

    @discardableResult
    func handleWorkspaceDropToEnd() -> Bool {
        guard workspaceEditController.isEditing,
              let store = workspaceStore,
              let draggingID = workspaceEditController.draggingID else { return false }
        store.moveWorkspace(id: draggingID, to: store.workspaces.count)
        workspaceEditController.endDragging()
        Haptics.success()
        return true
    }

    @discardableResult
    func clearWorkspaceDrag() -> Bool {
        guard workspaceEditController.isEditing else { return false }
        workspaceEditController.endDragging()
        return true
    }
}
