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
    @State private var showBulkDeleteConfirm = false

    var body: some View {
        let coordinator = QuickActionsCoordinator(
            workspaceStore: workspaceStore,
            quickActions: quickActions,
            router: router,
            localBank: localBank,
            localProgress: localProgress,
            editController: editController
        )
        let items = coordinator.items()
        let isEmpty = items.isEmpty
        let selectedCount = editController.selectedIDs.count

        VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
            QuickActionsHeaderView(
                isEmpty: isEmpty,
                isEditing: editController.isEditing,
                onToggleEditing: onToggleEditing,
                onRequestAdd: onRequestAdd
            )

            if selectedCount > 0 {
                QuickActionsBulkToolbar(
                    count: selectedCount,
                    onDelete: { showBulkDeleteConfirm = true }
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm2) {
                    ForEach(items) { item in
                        quickActionTile(for: item, coordinator: coordinator)
                    }

                    if editController.isEditing || isEmpty {
                        AddQuickActionCard()
                            .frame(width: DS.IconSize.entryCardWidth)
                            .onTapGesture { onRequestAdd() }
                            .onDrop(of: [.text], delegate: QuickActionsAppendDropDelegate(coordinator: coordinator))
                    }
                }
                .onDrop(of: [.text], delegate: QuickActionsClearDragDropDelegate(coordinator: coordinator))
            }
            .contentShape(Rectangle())
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            if editController.isEditing {
                                editController.exitEditMode()
                            }
                        }
                    )
            )
        }
        .confirmationDialog(
            String(localized: "quick.bulkDelete.confirm", defaultValue: "確認刪除選取的快速功能？"),
            isPresented: $showBulkDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "action.deleteAll", defaultValue: "Delete All"), role: .destructive) {
                let ids = editController.selectedIDs
                coordinator.remove(ids: ids)
                showBulkDeleteConfirm = false
            }
            Button(String(localized: "action.cancel", locale: locale), role: .cancel) {
                showBulkDeleteConfirm = false
            }
        }
    }

    @ViewBuilder
    private func quickActionTile(for item: QuickActionItem, coordinator: QuickActionsCoordinator) -> some View {
        let isEditing = editController.isEditing
        let isSelected = editController.isSelected(item.id)

        let baseCard = quickActionCard(for: item)
            .frame(width: DS.IconSize.entryCardWidth)
            .shelfSelectable(isEditing: isEditing, isSelected: isSelected)

        let tile: AnyView = {
            if isEditing {
                return AnyView(
                    baseCard
                        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                        .contextMenu {
                            Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                                coordinator.remove(item)
                            }
                        }
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                editController.toggleSelection(item.id)
                            }
                        )
                )
            } else {
                return AnyView(
                    coordinator.navigationLink(for: item, chatViewModel: sharedChatViewModel) {
                        baseCard
                    }
                    .buttonStyle(DSCardLinkStyle())
                    .contextMenu {
                        Button(String(localized: "action.edit", locale: locale)) {
                            editController.enterEditMode()
                            Haptics.medium()
                        }
                        Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                            coordinator.remove(item)
                        }
                    }
                )
            }
        }()

        tile
            .shelfWiggle(isActive: isEditing)
            .shelfConditionalDrag(isEditing) {
                coordinator.beginDragging(item.id)
            }
            .onDrop(of: [.text], delegate: QuickActionsReorderDropDelegate(item: item, coordinator: coordinator))
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

private struct QuickActionsBulkToolbar: View {
    var count: Int
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button(action: onDelete) {
                Label(String(localized: "action.deleteAll", defaultValue: "Delete All"), systemImage: "trash")
            }
            .buttonStyle(DSButton(style: .secondary, size: .compact))

            Text(String(format: String(localized: "bulk.selectionCount", defaultValue: "已選 %d 項"), count))
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, DS.Spacing.xs)
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
