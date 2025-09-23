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

        workspaceEditController.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        quickActionsEditController.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

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
        workspaceEditController.selectedIDs.remove(id)
    }

    func beginWorkspaceDragging(_ id: UUID) -> NSItemProvider {
        workspaceEditController.beginDragging(id)
        let ids = orderedWorkspaceSelection(anchor: id)
        let payload = ShelfDragPayload(
            primaryID: id.uuidString,
            selectedIDs: ids.map { $0.uuidString }
        )
        return NSItemProvider(object: payload.encodedString() as NSString)
    }

    func deleteSelectedWorkspaces() {
        guard let store = workspaceStore else { return }
        let ids = workspaceEditController.selectedIDs
        guard !ids.isEmpty else { return }
        store.remove(ids: ids)
        workspaceEditController.clearSelection()
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

    func handleViewAppear(
        localBank: LocalBankStore,
        localProgress: LocalBankProgressStore,
        practiceRecords: PracticeRecordsStore
    ) {
        bindWorkspaceStores(
            localBank: localBank,
            localProgress: localProgress,
            practiceRecords: practiceRecords
        )
        workspaceEditController.exitEditMode()
    }

    func handleWorkspaceDropEntered(targetID: UUID) {
        guard workspaceEditController.isEditing,
              let store = workspaceStore,
              let draggingID = workspaceEditController.draggingID,
              draggingID != targetID else { return }
        let selection = orderedWorkspaceSelection(anchor: draggingID)
        guard !selection.contains(targetID) else { return }
        store.moveWorkspaces(ids: selection, before: targetID)
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
        let selection = orderedWorkspaceSelection(anchor: draggingID)
        store.moveWorkspaces(ids: selection, before: nil)
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

    private func bindWorkspaceStores(
        localBank: LocalBankStore,
        localProgress: LocalBankProgressStore,
        practiceRecords: PracticeRecordsStore
    ) {
        guard let store = workspaceStore else { return }
        store.localBankStore = localBank
        store.localProgressStore = localProgress
        store.practiceRecordsStore = practiceRecords
        store.rebindAllStores()
    }
}

private extension WorkspaceHomeCoordinator {
    func orderedWorkspaceSelection(anchor: UUID) -> [UUID] {
        let selected = workspaceEditController.selectedIDs
        guard selected.contains(anchor), !selected.isEmpty else { return [anchor] }
        guard let store = workspaceStore else { return [anchor] }
        let ordered = store.workspaces.compactMap { workspace -> UUID? in
            selected.contains(workspace.id) ? workspace.id : nil
        }
        return ordered.isEmpty ? [anchor] : ordered
    }
}
