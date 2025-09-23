import SwiftUI

@MainActor
struct QuickActionsCoordinator {
    let workspaceStore: WorkspaceStore
    let quickActions: QuickActionsStore
    let router: RouterStore
    let localBank: LocalBankStore
    let localProgress: LocalBankProgressStore
    let editController: ShelfEditController<UUID>

    func items() -> [QuickActionItem] { quickActions.items }

    func remove(_ item: QuickActionItem) {
        quickActions.remove(id: item.id)
        editController.selectedIDs.remove(item.id)
    }

    func remove(ids: Set<UUID>) {
        quickActions.remove(ids: ids)
        editController.clearSelection()
    }

    func move(draggingID: UUID, above targetID: UUID) {
        let selection = orderedSelection(for: draggingID)
        guard !selection.contains(targetID) else { return }
        quickActions.move(ids: selection, before: targetID)
    }

    func moveToEnd(draggingID: UUID) {
        let selection = orderedSelection(for: draggingID)
        quickActions.move(ids: selection, before: nil)
    }

    func beginDragging(_ id: UUID) -> NSItemProvider {
        editController.beginDragging(id)
        let ids = orderedSelection(for: id)
        let payload = ShelfDragPayload(
            primaryID: id.uuidString,
            selectedIDs: ids.map { $0.uuidString }
        )
        return NSItemProvider(object: payload.encodedString() as NSString)
    }

    func endDragging() {
        editController.endDragging()
    }

    func handleLocalPractice(bookName: String, item: BankItem, tag: String?) {
        let newWorkspace = workspaceStore.addWorkspace()
        let newViewModel = workspaceStore.vm(for: newWorkspace.id)
        newViewModel.bindLocalBankStores(localBank: localBank, progress: localProgress)
        newViewModel.startLocalPractice(bookName: bookName, item: item, tag: tag)
        router.open(workspaceID: newWorkspace.id)
    }

    @ViewBuilder
    func navigationLink<Content: View>(for item: QuickActionItem,
                                       chatViewModel: ChatViewModel,
                                       @ViewBuilder content: () -> Content) -> some View {
        switch item.type {
        case .chat:
            NavigationLink { ChatWorkspaceView(viewModel: chatViewModel) } label: { content() }
        case .flashcards:
            NavigationLink { FlashcardDecksView() } label: { content() }
        case .bank:
            if let workspace = workspaceStore.workspaces.first {
                NavigationLink {
                    BankBooksView(
                        vm: workspaceStore.vm(for: workspace.id),
                        onPracticeLocal: { book, bankItem, tag in
                            handleLocalPractice(bookName: book, item: bankItem, tag: tag)
                        }
                    )
                } label: { content() }
            } else {
                content()
                    .opacity(0.5)
            }
        case .calendar:
            NavigationLink { CalendarView() } label: { content() }
        case .settings:
            NavigationLink { SettingsView() } label: { content() }
        }
    }
}

private extension QuickActionsCoordinator {
    func orderedSelection(for anchor: UUID) -> [UUID] {
        let selected = editController.selectedIDs
        guard selected.contains(anchor), !selected.isEmpty else { return [anchor] }
        let ordered = quickActions.items.compactMap { item -> UUID? in
            selected.contains(item.id) ? item.id : nil
        }
        return ordered.isEmpty ? [anchor] : ordered
    }
}
