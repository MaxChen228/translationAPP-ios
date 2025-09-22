import SwiftUI

struct QuickActionsRowView: View {
    @ObservedObject var workspaceStore: WorkspaceStore
    @ObservedObject var editController: ShelfEditController<UUID>
    var onToggleEditing: () -> Void
    var onRequestAdd: () -> Void

    @EnvironmentObject private var quickActions: QuickActionsStore
    @EnvironmentObject private var router: RouterStore
    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var localProgress: LocalBankProgressStore
    @Environment(\.locale) private var locale
    @StateObject private var sharedChatViewModel = ChatViewModel()

    var body: some View {
        let isEmpty = quickActions.items.isEmpty

        VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
            QuickActionsHeaderView(
                isEmpty: isEmpty,
                isEditing: editController.isEditing,
                onToggleEditing: onToggleEditing,
                onRequestAdd: onRequestAdd
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(quickActions.items) { item in
                        quickActionTile(for: item)
                    }

                    if editController.isEditing || isEmpty {
                        AddQuickActionCard()
                            .frame(width: DS.IconSize.entryCardWidth)
                            .onTapGesture { onRequestAdd() }
                            .onDrop(of: [.text], delegate: QuickActionsAppendDropDelegate(store: quickActions, editController: editController))
                    }
                }
                .padding(.horizontal, 2)
                .onDrop(of: [.text], delegate: QuickActionsClearDragDropDelegate(editController: editController))
            }
        }
    }

    @ViewBuilder
    private func quickActionTile(for item: QuickActionItem) -> some View {
        let baseCard = quickActionCard(for: item)
            .frame(width: DS.IconSize.entryCardWidth)

        Group {
            if editController.isEditing {
                editingTile(baseCard: baseCard, item: item)
            } else {
                navigationTile(baseCard: baseCard, item: item)
            }
        }
        .shelfWiggle(isActive: editController.isEditing)
        .shelfConditionalDrag(editController.isEditing) {
            editController.beginDragging(item.id)
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .simultaneousGesture(editController.isEditing ? TapGesture().onEnded { editController.exitEditMode() } : nil)
        .onDrop(of: [.text], delegate: QuickActionsReorderDropDelegate(item: item, store: quickActions, editController: editController))
    }

    @ViewBuilder
    private func quickActionCard(for item: QuickActionItem) -> some View {
        switch item.type {
        case .chat:
            ChatEntryCard()
        case .flashcards:
            FlashcardsEntryCard()
        case .bank:
            BankBooksEntryCard()
        case .calendar:
            CalendarEntryCard()
        case .settings:
            SettingsEntryCard()
        }
    }

    @ViewBuilder
    private func navigationTile<Content: View>(baseCard: Content, item: QuickActionItem) -> some View {
        navigationWrapper(for: item) {
            baseCard
        }
        .buttonStyle(DSCardLinkStyle())
        .contextMenu {
            Button(String(localized: "action.edit", locale: locale)) {
                editController.enterEditMode()
                Haptics.medium()
            }
            Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                quickActions.remove(id: item.id)
            }
        }
    }

    private func editingTile<Content: View>(baseCard: Content, item: QuickActionItem) -> some View {
        baseCard
            .overlay(alignment: .topTrailing) {
                Button(role: .destructive) {
                    quickActions.remove(id: item.id)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.red)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            .contextMenu {
                Button(String(localized: "action.done", locale: locale)) {
                    editController.exitEditMode()
                }
                Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                    quickActions.remove(id: item.id)
                }
            }
    }

    @ViewBuilder
    private func navigationWrapper<Content: View>(for item: QuickActionItem, @ViewBuilder content: () -> Content) -> some View {
        switch item.type {
        case .chat:
            NavigationLink { ChatWorkspaceView(viewModel: sharedChatViewModel) } label: { content() }
        case .flashcards:
            NavigationLink { FlashcardDecksView() } label: { content() }
        case .bank:
            if let workspace = workspaceStore.workspaces.first {
                NavigationLink {
                    BankBooksView(
                        vm: workspaceStore.vm(for: workspace.id),
                        onPracticeLocal: handleLocalPractice
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

    private func handleLocalPractice(bookName: String, item: BankItem, tag: String?) {
        let newWorkspace = workspaceStore.addWorkspace()
        let newViewModel = workspaceStore.vm(for: newWorkspace.id)
        newViewModel.bindLocalBankStores(localBank: localBank, progress: localProgress)
        newViewModel.startLocalPractice(bookName: bookName, item: item, tag: tag)
        router.open(workspaceID: newWorkspace.id)
    }
}

// MARK: - Subviews

private struct QuickActionsHeaderView: View {
    var isEmpty: Bool
    var isEditing: Bool
    var onToggleEditing: () -> Void
    var onRequestAdd: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        DSSectionHeader(titleKey: "quick.title", subtitleKey: nil, accentUnderline: true)
            .overlay(alignment: .topTrailing) {
                if isEmpty {
                    Button(String(localized: "quick.addEntry", locale: locale)) {
                        if !isEditing { onToggleEditing() }
                        onRequestAdd()
                    }
                    .buttonStyle(DSButton(style: .secondary, size: .compact))
                    .padding(.top, 4)
                }
            }
    }
}

private struct AddQuickActionCard: View {
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.title2)
            Text(String(localized: "quick.addEntry", locale: locale))
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: DS.CardSize.minHeightCompact)
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.md)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: DS.BorderWidth.regular, dash: [5, 4]))
                .foregroundStyle(DS.Palette.border.opacity(0.45))
        )
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }
}

private struct ChatEntryCard: View {
    var body: some View {
        QuickEntryCard(
            icon: "bubble.left.and.bubble.right.fill",
            title: "chat.title",
            accentColor: DS.Brand.scheme.classicBlue
        ) {
            Text("chat.subtitle")
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FlashcardsEntryCard: View {
    var body: some View {
        QuickEntryCard(
            icon: "rectangle.on.rectangle.angled",
            title: "quick.flashcards.title",
            accentColor: DS.Brand.scheme.provence
        ) {
            Text("quick.flashcards.subtitle")
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct BankBooksEntryCard: View {
    var body: some View {
        QuickEntryCard(
            icon: "books.vertical",
            title: "quick.bank.title",
            accentColor: DS.Brand.scheme.stucco
        ) {
            Text("quick.bank.subtitle")
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsEntryCard: View {
    var body: some View {
        QuickEntryCard(
            icon: "gearshape",
            title: "quick.settings.title",
            accentColor: DS.Palette.primary
        ) {
            Text("quick.settings.subtitle")
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Drag & Drop Delegates

private struct QuickActionsReorderDropDelegate: DropDelegate {
    let item: QuickActionItem
    let store: QuickActionsStore
    let editController: ShelfEditController<UUID>

    func validateDrop(info: DropInfo) -> Bool { editController.isEditing }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func dropEntered(info: DropInfo) {
        guard editController.isEditing,
              let draggingID = editController.draggingID,
              draggingID != item.id,
              let from = store.index(of: draggingID),
              let to = store.index(of: item.id) else { return }

        if from != to {
            store.move(from: from, to: to > from ? to + 1 : to)
            Haptics.lightTick()
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard editController.isEditing else { return false }
        editController.endDragging()
        Haptics.success()
        return true
    }
}

private struct QuickActionsAppendDropDelegate: DropDelegate {
    let store: QuickActionsStore
    let editController: ShelfEditController<UUID>

    func validateDrop(info: DropInfo) -> Bool { editController.isEditing }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        guard editController.isEditing,
              let draggingID = editController.draggingID,
              let from = store.index(of: draggingID) else { return false }

        store.move(from: from, to: store.items.count)
        editController.endDragging()
        Haptics.success()
        return true
    }
}

private struct QuickActionsClearDragDropDelegate: DropDelegate {
    let editController: ShelfEditController<UUID>
    func validateDrop(info: DropInfo) -> Bool { editController.isEditing }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        editController.endDragging()
        return true
    }
}
