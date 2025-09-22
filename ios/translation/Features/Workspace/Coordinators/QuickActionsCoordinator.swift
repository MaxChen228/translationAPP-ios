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
    }

    func move(draggingID: UUID, above targetID: UUID) {
        guard let from = quickActions.index(of: draggingID),
              let to = quickActions.index(of: targetID) else { return }
        quickActions.move(from: from, to: to > from ? to + 1 : to)
    }

    func moveToEnd(draggingID: UUID) {
        guard let from = quickActions.index(of: draggingID) else { return }
        quickActions.move(from: from, to: quickActions.items.count)
    }

    func beginDragging(_ id: UUID) -> NSItemProvider {
        editController.beginDragging(id)
        return NSItemProvider(object: id.uuidString as NSString)
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
