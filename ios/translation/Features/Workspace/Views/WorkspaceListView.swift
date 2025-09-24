import SwiftUI

struct WorkspaceListView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @EnvironmentObject private var savedStore: SavedErrorsStore
    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var localProgress: LocalBankProgressStore
    @EnvironmentObject private var practiceRecords: PracticeRecordsStore
    @EnvironmentObject private var quickActions: QuickActionsStore
    @EnvironmentObject private var router: RouterStore
    @Environment(\.locale) private var locale
    @StateObject private var coordinator = WorkspaceHomeCoordinator()
    @State private var showWorkspaceBulkDeleteConfirm = false

    private var cols: [GridItem] { [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.lg)] }
    private var workspaceSelectedCount: Int { coordinator.workspaceEditController.selectedIDs.count }

    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    // 快速功能保留 Row 形式，但使用一致的區塊標題
                    QuickActionsRowView(
                        workspaceStore: store,
                        editController: coordinator.quickActionsEditController,
                        onToggleEditing: { coordinator.toggleQuickActionsEditing() },
                        onRequestAdd: { coordinator.handleAddQuickActionTapped() }
                    )

                    // 快速功能與 Workspaces 間加上 hairline 分隔
                    DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(DS.Opacity.border))
                        .padding(.vertical, DS.Spacing.sm)

                    ShelfGrid(titleKey: "home.workspaces", columns: cols) {

                    ForEach(store.workspaces) { workspace in
                        WorkspaceItemLink(
                            workspace: workspace,
                            viewModel: store.vm(for: workspace.id),
                            coordinator: coordinator,
                            editController: coordinator.workspaceEditController,
                            onRename: { coordinator.startRename(workspace) },
                            onDelete: { coordinator.deleteWorkspace(workspace.id) }
                        )
                        .environmentObject(savedStore)
                    }
                    // 將重排的動畫收斂到容器層，避免在 delegate 內多次觸發動畫
                    .dsAnimation(DS.AnimationToken.reorder, value: store.workspaces)

                    Button {
                        coordinator.addWorkspace()
                    } label: {
                        AddWorkspaceCard()
                    }
                    .buttonStyle(.plain)
                    // 允許拖到新增卡以移到清單尾端
                    .onDrop(of: [.text], delegate: WorkspaceAddToEndDropDelegate(coordinator: coordinator))
                    }
                    .overlay(alignment: .topTrailing) {
                        if workspaceSelectedCount > 0 {
                            WorkspaceBulkToolbar(
                                count: workspaceSelectedCount,
                                onDelete: { showWorkspaceBulkDeleteConfirm = true }
                            )
                            .padding(.top, DS.Spacing.sm)
                            .padding(.trailing, DS.Spacing.sm2)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
            }
            .id(locale.identifier)
            // 後備 drop：若使用者把項目拖到空白處或邊緣放下，確保 draggingID 能被清除
            .onDrop(of: [.text], delegate: WorkspaceClearDragDropDelegate(coordinator: coordinator))
            .contentShape(Rectangle())
            .gesture(
                TapGesture().onEnded {
                    if coordinator.workspaceEditController.isEditing {
                        coordinator.workspaceEditController.exitEditMode()
                    }
                },
                including: .gesture
            )
            .background(DS.Palette.background)
            .navigationTitle(Text("nav.workspace"))
            .navigationDestination(for: WorkspaceRoute.self) { route in
                switch route {
                case .workspace(let id):
                    ContentView(vm: store.vm(for: id)).environmentObject(savedStore)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SavedJSONListSheet().environmentObject(savedStore)
                    } label: {
                        Image(systemName: "tray.full")
                    }
                }
            }
            .sheet(item: $coordinator.renamingWorkspace) { workspace in
                RenameWorkspaceSheet(name: coordinator.renameDraft, onAction: { action in
                    switch action {
                    case .cancel:
                        coordinator.cancelRename()
                    case .save(let name):
                        coordinator.commitRename(newName: name, store: store)
                    }
                })
                .presentationDetents([.height(180)])
            }
            .sheet(isPresented: $coordinator.showQuickActionPicker) {
                QuickActionPickerView(isPresented: $coordinator.showQuickActionPicker) { type in
                    coordinator.appendQuickAction(type)
                }
            }
            .confirmationDialog(
                String(localized: "workspace.bulkDelete.confirm", defaultValue: "Delete selected workspaces?"),
                isPresented: $showWorkspaceBulkDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(String(localized: "action.deleteAll", defaultValue: "Delete All"), role: .destructive) {
                    coordinator.deleteSelectedWorkspaces()
                    showWorkspaceBulkDeleteConfirm = false
                }
                Button(String(localized: "action.cancel", locale: locale), role: .cancel) {
                    showWorkspaceBulkDeleteConfirm = false
                }
            }
            .onAppear {
                coordinator.configureIfNeeded(
                    workspaceStore: store,
                    quickActions: quickActions,
                    router: router
                )
                coordinator.handleViewAppear(
                    localBank: localBank,
                    localProgress: localProgress,
                    practiceRecords: practiceRecords
                )
            }
        }
        // 只在 ScrollView 範圍處理後備 drop；避免多層干擾
        .onChange(of: coordinator.quickActionsEditController.isEditing) { _, isEditing in
            coordinator.quickActionsEditingChanged(isEditing: isEditing)
        }
        .onChange(of: coordinator.workspaceEditController.isEditing) { _, isEditing in
            coordinator.workspaceEditingChanged(isEditing: isEditing)
        }
    }
}

private struct WorkspaceItemLink: View {
    let workspace: Workspace
    @ObservedObject var viewModel: CorrectionViewModel
    unowned let coordinator: WorkspaceHomeCoordinator
    @ObservedObject var editController: ShelfEditController<UUID>
    var onRename: () -> Void
    var onDelete: () -> Void
    @EnvironmentObject private var savedStore: SavedErrorsStore
    @Environment(\.locale) private var locale

    var statusKey: LocalizedStringKey {
        if viewModel.isLoading { return "workspace.status.loading" }
        if viewModel.session.response != nil { return "workspace.status.graded" }
        if !(viewModel.session.inputZh.isEmpty && viewModel.session.inputEn.isEmpty) { return "workspace.status.input" }
        return "workspace.status.empty"
    }

    var statusColor: Color {
        // 主色以藍、白、灰為基礎；完成狀態用暖色作為強調色
        if viewModel.isLoading { return DS.Palette.primary }
        if viewModel.session.response != nil { return DS.Brand.scheme.cornhusk }
        if !(viewModel.session.inputZh.isEmpty && viewModel.session.inputEn.isEmpty) { return DS.Brand.scheme.monument }
        return DS.Palette.border.opacity(DS.Opacity.muted)
    }

    var body: some View {
        let isEditing = editController.isEditing
        let isSelected = editController.isSelected(workspace.id)

        let card = WorkspaceCard(name: workspace.name, statusKey: statusKey, statusColor: statusColor)
            .shelfSelectable(isEditing: isEditing, isSelected: isSelected)

        let tile: AnyView = {
            if isEditing {
                return AnyView(
                    card
                        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                        .contextMenu {
                            Button(String(localized: "action.rename", locale: locale)) {
                                editController.exitEditMode()
                                onRename()
                            }
                            Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                                onDelete()
                            }
                        }
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                editController.toggleSelection(workspace.id)
                            }
                        )
                )
            } else {
                return AnyView(
                    NavigationLink {
                        ContentView(vm: viewModel).environmentObject(savedStore)
                    } label: {
                        card
                    }
                    .buttonStyle(DSCardLinkStyle())
                    .contextMenu {
                        Button(String(localized: "action.edit", locale: locale)) {
                            editController.enterEditMode()
                            Haptics.medium()
                        }
                        Button(String(localized: "action.rename", locale: locale)) {
                            editController.exitEditMode()
                            onRename()
                        }
                        Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                            onDelete()
                        }
                    }
                )
            }
        }()

        tile
            .shelfWiggle(isActive: isEditing)
            .shelfConditionalDrag(isEditing) {
                coordinator.beginWorkspaceDragging(workspace.id)
            }
            .onDrop(of: [.text], delegate: WorkspaceReorderDropDelegate(workspaceID: workspace.id, coordinator: coordinator))
    }
}

private struct WorkspaceCard: View {
    var name: String
    var statusKey: LocalizedStringKey
    var statusColor: Color
    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text(name)
                    .dsType(DS.Font.serifBody)
                    .fontWeight(.semibold)

                DSSeparator(color: DS.Palette.border.opacity(0.12))
                
                HStack(spacing: 10) {
                    StatusBadge(textKey: statusKey, color: statusColor)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(minHeight: DS.CardSize.minHeightStandard)
        }
        // 扁平化：去陰影（改用 DSOutlineCard）且不再加第二層彩色描邊
    }
}

private struct AddWorkspaceCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus").font(.title2)
            Text("quick.addWorkspace").dsType(DS.Font.caption).foregroundStyle(.secondary)
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

// 移除晶片變體：回到簡潔文本副標

private struct WorkspaceBulkToolbar: View {
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
        }
        .padding(.horizontal, DS.Spacing.sm2)
    }
}

private struct StatusBadge: View {
    var textKey: LocalizedStringKey
    var color: Color
    var body: some View {
        DSBadge(style: .outline(color: color.opacity(DS.Opacity.strong), lineWidth: DS.BorderWidth.emphatic)) {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(textKey).dsType(DS.Font.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct RenameWorkspaceSheet: View {
    enum Action { case cancel, save(String) }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var text: String
    let onAction: (Action) -> Void
    init(name: String, onAction: @escaping (Action) -> Void) {
        self._text = State(initialValue: name)
        self.onAction = onAction
    }
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
            Text(String(localized: "action.rename", locale: locale)).dsType(DS.Font.section)
            TextField(String(localized: "field.name", locale: locale), text: $text)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(String(localized: "action.cancel", locale: locale)) {
                    onAction(.cancel)
                    dismiss()
                }
                .buttonStyle(DSButton(style: .secondary, size: .compact))

                Button(String(localized: "action.done", locale: locale)) {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        onAction(.save(trimmed))
                    }
                    dismiss()
                }
                .buttonStyle(DSButton(style: .primary, size: .compact))
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Palette.background)
    }
}
