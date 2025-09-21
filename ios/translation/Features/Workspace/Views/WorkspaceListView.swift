import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceListView: View {
    @StateObject private var store = WorkspaceStore()
    @StateObject private var workspaceEditController = ShelfEditController<UUID>()
    @EnvironmentObject private var savedStore: SavedErrorsStore
    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var localProgress: LocalBankProgressStore
    @EnvironmentObject private var practiceRecords: PracticeRecordsStore
    @EnvironmentObject private var quickActions: QuickActionsStore
    @EnvironmentObject private var router: RouterStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    @Environment(\.locale) private var locale
    @State private var showSavedSheet = false // legacy: replaced by NavigationLink

    // Rename state
    @State private var renaming: Workspace? = nil
    @State private var newName: String = ""

    private var cols: [GridItem] { [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.lg)] }
    // Navigation via typed routes to avoid off-stage pushes
    private enum Route: Hashable { case workspace(UUID) }
    @State private var path: [Route] = []
    @State private var isEditingQuickActions = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    // 快速功能保留 Row 形式，但使用一致的區塊標題
                    QuickActionsRow(
                        store: store,
                        isEditing: $isEditingQuickActions,
                        onToggleEditing: toggleQuickActionsEditing,
                        onRequestAdd: handleAddQuickAction
                    )

                    // 快速功能與 Workspaces 間加上 hairline 分隔
                    DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(DS.Opacity.border))
                        .padding(.vertical, DS.Spacing.sm)

                    ShelfGrid(titleKey: "home.workspaces", columns: cols) {

                    ForEach(store.workspaces) { ws in
                        WorkspaceItemLink(
                            ws: ws,
                            vm: store.vm(for: ws.id),
                            store: store,
                            editController: workspaceEditController
                        ) {
                            startRename(ws)
                        } onDelete: {
                            store.remove(ws.id)
                        }
                        .environmentObject(savedStore)
                    }
                    // 將重排的動畫收斂到容器層，避免在 delegate 內多次觸發動畫
                    .dsAnimation(DS.AnimationToken.reorder, value: store.workspaces)

                    Button {
                        workspaceEditController.exitEditMode()
                        _ = store.addWorkspace()
                    } label: {
                        AddWorkspaceCard()
                    }
                    .buttonStyle(.plain)
                    // 允許拖到新增卡以移到清單尾端
                    .onDrop(of: [.text], delegate: AddToEndDropDelegate(store: store, editController: workspaceEditController))
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
            }
            .id(locale.identifier)
            // 後備 drop：若使用者把項目拖到空白處或邊緣放下，確保 draggingID 能被清除
            .onDrop(of: [.text], delegate: ClearDragStateDropDelegate(editController: workspaceEditController))
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    if workspaceEditController.isEditing {
                        workspaceEditController.exitEditMode()
                    }
                },
                including: .gesture
            )
            .background(DS.Palette.background)
            .navigationTitle(Text("nav.workspace"))
            .navigationDestination(for: Route.self) { route in
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
            .sheet(item: $renaming) { ws in
                RenameWorkspaceSheet(name: ws.name) { new in
                    store.rename(ws.id, to: new)
                }
                .presentationDetents([.height(180)])
            }
            .sheet(isPresented: $showQuickActionPicker) {
                QuickActionPickerView(isPresented: $showQuickActionPicker) { type in
                    quickActions.append(type)
                }
            }
            .onAppear {
                // Bind stores to WorkspaceStore
                store.localBankStore = localBank
                store.localProgressStore = localProgress
                store.practiceRecordsStore = practiceRecords
                // Rebind all existing ViewModels to ensure they have the latest store references
                store.rebindAllStores()
                workspaceEditController.exitEditMode()
            }
        }
        // 只在 ScrollView 範圍處理後備 drop；避免多層干擾
        // banner 監聽已移到 App root，這裡只處理 Router 指令
        .onReceive(router.$openWorkspaceID) { id in
            guard let id else { return }
            path.append(.workspace(id))
            router.openWorkspaceID = nil
        }
    }

    private func startRename(_ ws: Workspace) {
        newName = ws.name
        renaming = ws
    }

    private func toggleQuickActionsEditing() {
        if isEditingQuickActions {
            showQuickActionPicker = false
        }
        if !isEditingQuickActions {
            workspaceEditController.exitEditMode()
        }
        isEditingQuickActions.toggle()
    }

    @State private var showQuickActionPicker = false

    private func handleAddQuickAction() {
        if !isEditingQuickActions {
            isEditingQuickActions = true
        }
        showQuickActionPicker = true
    }
}

// MARK: - 拖曳重排 Delegate / 尾端 Drop Delegate

private struct ReorderDropDelegate: DropDelegate {
    let item: Workspace
    let store: WorkspaceStore
    let editController: ShelfEditController<UUID>

    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func dropEntered(info: DropInfo) {
        guard let draggingID = editController.draggingID, draggingID != item.id else { return }
        guard let from = store.index(of: draggingID), let to = store.index(of: item.id) else { return }
        if from != to {
            store.moveWorkspace(id: draggingID, to: to > from ? to + 1 : to)
            Haptics.lightTick()
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        editController.endDragging()
        Haptics.success()
        return true
    }
}

private struct AddToEndDropDelegate: DropDelegate {
    let store: WorkspaceStore
    let editController: ShelfEditController<UUID>
    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }
    func dropEntered(info: DropInfo) { }
    func performDrop(info: DropInfo) -> Bool {
        guard let draggingID = editController.draggingID else { return false }
        store.moveWorkspace(id: draggingID, to: store.workspaces.count)
        editController.endDragging()
        Haptics.success()
        return true
    }
}

private struct ClearDragStateDropDelegate: DropDelegate {
    let editController: ShelfEditController<UUID>
    func validateDrop(info: DropInfo) -> Bool { true }
    // 使用 .move 以確保 performDrop 會被呼叫（部分情境下 .cancel 可能不觸發 performDrop）
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        AppLog.uiDebug("[drag] clear-drop performDrop (fallback)")
        editController.endDragging()
        return true
    }
}

// 以 isTargeted 監控拖放生命週期，會話結束時確保清理狀態
// removed watcher overlay; simplified drag lifecycle

private struct WorkspaceItemLink: View {
    let ws: Workspace
    @ObservedObject var vm: CorrectionViewModel
    let store: WorkspaceStore
    @ObservedObject var editController: ShelfEditController<UUID>
    var onRename: () -> Void
    var onDelete: () -> Void
    @EnvironmentObject private var savedStore: SavedErrorsStore
    @Environment(\.locale) private var locale

    var statusKey: LocalizedStringKey {
        if vm.isLoading { return "workspace.status.loading" }
        if vm.response != nil { return "workspace.status.graded" }
        if !(vm.inputZh.isEmpty && vm.inputEn.isEmpty) { return "workspace.status.input" }
        return "workspace.status.empty"
    }

    var statusColor: Color {
        // 主色以藍、白、灰為基礎；完成狀態用暖色作為強調色
        if vm.isLoading { return DS.Palette.primary }
        if vm.response != nil { return DS.Brand.scheme.cornhusk }
        if !(vm.inputZh.isEmpty && vm.inputEn.isEmpty) { return DS.Brand.scheme.monument }
        return DS.Palette.border.opacity(DS.Opacity.muted)
    }

    var body: some View {
        NavigationLink {
            ContentView(vm: vm).environmentObject(savedStore)
        } label: {
            WorkspaceCard(name: ws.name, statusKey: statusKey, statusColor: statusColor)
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
                        editController.exitEditMode()
                        onDelete()
                    }
                }
        }
        .buttonStyle(DSCardLinkStyle())
        .shelfWiggle(isActive: editController.isEditing)
        .onDrag {
            guard editController.isEditing else { return NSItemProvider() }
            editController.beginDragging(ws.id)
            return NSItemProvider(object: ws.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: ReorderDropDelegate(item: ws, store: store, editController: editController))
        .simultaneousGesture(
            editController.isEditing ?
            TapGesture().onEnded {
                editController.exitEditMode()
            } : nil
        )
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

private struct AddQuickActionCard: View {
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle").font(.title2)
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

private struct FlashcardsEntryCard: View {
    @Environment(\.locale) private var locale
    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSCardTitle(
                    icon: "rectangle.on.rectangle.angled",
                    title: "quick.flashcards.title",
                    accentColor: DS.Brand.scheme.provence
                )
                DSSeparator(color: DS.Palette.border.opacity(0.12))
                Text("quick.flashcards.subtitle")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: DS.CardSize.minHeightStandard)
        }
    }
}

private struct ChatEntryCard: View {
    @Environment(\.locale) private var locale
    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSCardTitle(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "chat.title",
                    accentColor: DS.Brand.scheme.classicBlue
                )
                DSSeparator(color: DS.Palette.border.opacity(0.12))
                Text("chat.subtitle")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: DS.CardSize.minHeightStandard)
        }
    }
}

private struct QuickActionsRow: View {
    @ObservedObject var store: WorkspaceStore
    @Binding var isEditing: Bool
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
        VStack(alignment: .leading, spacing: 8) {
            header(isEmpty: isEmpty)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(quickActions.items) { item in
                        quickActionTile(for: item)
                    }
                    if isEditing || isEmpty {
                        AddQuickActionCard()
                            .frame(width: DS.IconSize.entryCardWidth)
                            .onTapGesture { onRequestAdd() }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func header(isEmpty: Bool) -> some View {
        DSSectionHeader(titleKey: "quick.title", subtitleKey: nil, accentUnderline: true)
            .overlay(alignment: .topTrailing) {
                if isEmpty {
                    Button(String(localized: "quick.addEntry", locale: locale)) {
                        if !isEditing { onToggleEditing() }
                        onRequestAdd()
                    }
                    .buttonStyle(DSButton(style: .secondary, size: .compact))
                    .padding(.top, 4)
                } else {
                    Button(isEditing ? String(localized: "action.done", locale: locale) : String(localized: "action.edit", locale: locale)) {
                        onToggleEditing()
                    }
                    .buttonStyle(DSButton(style: .secondary, size: .compact))
                    .padding(.top, 4)
                }
            }
    }

    @ViewBuilder
    private func quickActionTile(for item: QuickActionItem) -> some View {
        let card = cardView(for: item)
            .frame(width: DS.IconSize.entryCardWidth)

        if isEditing {
            card
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
        } else {
            navigationWrapper(for: item) {
                card
            }
            .buttonStyle(DSCardLinkStyle())
        }
    }

    @ViewBuilder
    private func cardView(for item: QuickActionItem) -> some View {
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
    private func navigationWrapper<Content: View>(for item: QuickActionItem, @ViewBuilder content: () -> Content) -> some View {
        switch item.type {
        case .chat:
            NavigationLink { ChatWorkspaceView(viewModel: sharedChatViewModel) } label: { content() }
        case .flashcards:
            NavigationLink { FlashcardDecksView() } label: { content() }
        case .bank:
            if let workspace = store.workspaces.first {
                NavigationLink {
                    BankBooksView(vm: store.vm(for: workspace.id), onPracticeLocal: { bookName, item, tag in
                        let newWorkspace = store.addWorkspace()
                        let newVM = store.vm(for: newWorkspace.id)
                        newVM.bindLocalBankStores(localBank: localBank, progress: localProgress)
                        newVM.startLocalPractice(bookName: bookName, item: item, tag: tag)
                        router.open(workspaceID: newWorkspace.id)
                    })
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

private struct BankBooksEntryCard: View {
    @Environment(\.locale) private var locale
    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSCardTitle(
                    icon: "books.vertical",
                    title: "quick.bank.title",
                    accentColor: DS.Brand.scheme.stucco
                )
                DSSeparator(color: DS.Palette.border.opacity(0.12))
                Text("quick.bank.subtitle")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: DS.CardSize.minHeightStandard)
        }
    }
}

private struct SettingsEntryCard: View {
    @Environment(\.locale) private var locale
    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSCardTitle(
                    icon: "gearshape",
                    title: "quick.settings.title",
                    accentColor: DS.Palette.primary
                )
                DSSeparator(color: DS.Palette.border.opacity(0.12))
                Text("quick.settings.subtitle")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: DS.CardSize.minHeightStandard)
        }
    }
}

// 移除晶片變體：回到簡潔文本副標

private struct StatusBadge: View {
    var textKey: LocalizedStringKey
    var color: Color
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(textKey).dsType(DS.Font.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .overlay(
            Capsule().stroke(color.opacity(DS.Opacity.strong), lineWidth: 1.6)
        )
    }
}

private struct RenameWorkspaceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var text: String
    let onDone: (String) -> Void
    init(name: String, onDone: @escaping (String) -> Void) {
        self._text = State(initialValue: name)
        self.onDone = onDone
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "action.rename", locale: locale)).dsType(DS.Font.section)
            TextField(String(localized: "field.name", locale: locale), text: $text)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(String(localized: "action.cancel", locale: locale)) { dismiss() }
                Button(String(localized: "action.done", locale: locale)) {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { onDone(trimmed) }
                    dismiss()
                }
                .buttonStyle(DSButton(style: .primary, size: .full))
                .frame(width: DS.ButtonSize.standard)
            }
        }
        .padding(16)
        .background(DS.Palette.background)
    }
}
