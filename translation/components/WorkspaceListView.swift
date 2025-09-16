import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceListView: View {
    @StateObject private var store = WorkspaceStore()
    @EnvironmentObject private var savedStore: SavedErrorsStore
    @EnvironmentObject private var router: RouterStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    @State private var showSavedSheet = false

    // Rename state
    @State private var renaming: Workspace? = nil
    @State private var newName: String = ""

    private var cols: [GridItem] { [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.lg)] }
    @State private var programmaticOpenVM: CorrectionViewModel? = nil
    @State private var openActive: Bool = false
    // 拖曳中的項目（以 ID 辨識）。供重排使用。
    @State private var draggingID: UUID? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    // Quick actions row (visual separation,減少混雜感)
                    QuickActionsRow(store: store)

                    LazyVGrid(columns: cols, spacing: DS.Spacing.lg) {

                    ForEach(store.workspaces) { ws in
                        WorkspaceItemLink(ws: ws, vm: store.vm(for: ws.id), store: store, draggingID: $draggingID) {
                            startRename(ws)
                        } onDelete: {
                            store.remove(ws.id)
                        }
                        .environmentObject(savedStore)
                    }
                    // 將重排的動畫收斂到容器層，避免在 delegate 內多次觸發動畫
                    .animation(DS.AnimationToken.reorder, value: store.workspaces)

                    Button {
                        _ = store.addWorkspace()
                    } label: {
                        AddWorkspaceCard()
                    }
                    .buttonStyle(.plain)
                    // 允許拖到新增卡以移到清單尾端
                    .onDrop(of: [.text], delegate: AddToEndDropDelegate(store: store, draggingID: $draggingID))
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
            }
            // 後備 drop：若使用者把項目拖到空白處或邊緣放下，確保 draggingID 能被清除
            .onDrop(of: [.text], delegate: ClearDragStateDropDelegate(draggingID: $draggingID))
            .background(DS.Palette.background)
            .navigationTitle("Workspace")
            .background(
                NavigationLink(isActive: $openActive) {
                    if let vm = programmaticOpenVM { ContentView(vm: vm).environmentObject(savedStore) }
                } label: { EmptyView() }
                .opacity(0)
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSavedSheet = true
                    } label: {
                        Image(systemName: "tray.full")
                    }
                }
            }
            .sheet(isPresented: $showSavedSheet) {
                SavedJSONListSheet().environmentObject(savedStore)
            }
            .sheet(item: $renaming) { ws in
                RenameWorkspaceSheet(name: ws.name) { new in
                    store.rename(ws.id, to: new)
                }
                .presentationDetents([.height(180)])
            }
            .onAppear { draggingID = nil }
        }
        // 只在 ScrollView 範圍處理後備 drop；避免多層干擾
        // banner 監聽已移到 App root，這裡只處理 Router 指令
        .onReceive(router.$openWorkspaceID) { id in
            guard let id else { return }
            programmaticOpenVM = store.vm(for: id)
            openActive = true
            router.openWorkspaceID = nil
        }
    }

    private func startRename(_ ws: Workspace) {
        newName = ws.name
        renaming = ws
    }
}

// MARK: - 拖曳重排 Delegate / 尾端 Drop Delegate

private struct ReorderDropDelegate: DropDelegate {
    let item: Workspace
    let store: WorkspaceStore
    @Binding var draggingID: UUID?

    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != item.id else { return }
        guard let from = store.index(of: draggingID), let to = store.index(of: item.id) else { return }
        if from != to {
            store.moveWorkspace(id: draggingID, to: to > from ? to + 1 : to)
            Haptics.lightTick()
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        Haptics.success()
        return true
    }
}

private struct AddToEndDropDelegate: DropDelegate {
    let store: WorkspaceStore
    @Binding var draggingID: UUID?
    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }
    func dropEntered(info: DropInfo) { }
    func performDrop(info: DropInfo) -> Bool {
        guard let draggingID else { return false }
        withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.86)) {
            store.moveWorkspace(id: draggingID, to: store.workspaces.count)
        }
        self.draggingID = nil
        Haptics.success()
        return true
    }
}

private struct ClearDragStateDropDelegate: DropDelegate {
    @Binding var draggingID: UUID?
    func validateDrop(info: DropInfo) -> Bool { true }
    // 使用 .move 以確保 performDrop 會被呼叫（部分情境下 .cancel 可能不觸發 performDrop）
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { AppLog.uiDebug("[drag] clear-drop performDrop (fallback)"); draggingID = nil; return true }
}

// 以 isTargeted 監控拖放生命週期，會話結束時確保清理狀態
// removed watcher overlay; simplified drag lifecycle

private struct WorkspaceItemLink: View {
    let ws: Workspace
    @ObservedObject var vm: CorrectionViewModel
    let store: WorkspaceStore
    @Binding var draggingID: UUID?
    var onRename: () -> Void
    var onDelete: () -> Void
    @EnvironmentObject private var savedStore: SavedErrorsStore

    var status: String {
        if vm.isLoading { return "批改中…" }
        if vm.response != nil { return "已批改" }
        if !(vm.inputZh.isEmpty && vm.inputEn.isEmpty) { return "已輸入" }
        return "空白"
    }

    var statusColor: Color {
        // 主色以藍、白、灰為基礎；完成狀態用暖色作為強調色
        if vm.isLoading { return DS.Palette.primary }
        if vm.response != nil { return DS.Brand.scheme.cornhusk }
        if !(vm.inputZh.isEmpty && vm.inputEn.isEmpty) { return DS.Brand.scheme.monument }
        return DS.Palette.border.opacity(0.6)
    }

    var body: some View {
        NavigationLink {
            ContentView(vm: vm).environmentObject(savedStore)
        } label: {
            WorkspaceCard(name: ws.name, status: status, statusColor: statusColor)
                .contextMenu {
                    Button("重新命名") { onRename() }
                    Button("刪除", role: .destructive) { onDelete() }
                }
                // 移除長按手勢避免與拖曳啟動衝突（改由 context menu）
        }
        .buttonStyle(DSCardLinkStyle())
        .onDrag {
            self.draggingID = ws.id
            return NSItemProvider(object: ws.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: ReorderDropDelegate(item: ws, store: store, draggingID: $draggingID))
    }
}

private struct WorkspaceCard: View {
    var name: String
    var status: String
    var statusColor: Color
    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text(name)
                    .dsType(DS.Font.serifBody)
                    .fontWeight(.semibold)

                DSSeparator(color: DS.Palette.border.opacity(0.12))
                
                HStack(spacing: 10) {
                    StatusBadge(text: status, color: statusColor)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(minHeight: 104)
        }
        // 扁平化：去陰影（改用 DSOutlineCard）且不再加第二層彩色描邊
    }
}

private struct AddWorkspaceCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus").font(.title2)
            Text("新增 Workspace").dsType(DS.Font.caption).foregroundStyle(.secondary)
        }
        .frame(minHeight: 96)
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
    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.title3)
                        .foregroundStyle(DS.Brand.scheme.provence.opacity(0.85))
                        .frame(width: 28)
                    Text("單字卡")
                        .dsType(DS.Font.serifBody)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                DSSeparator(color: DS.Palette.border.opacity(0.12))
                Text("Markdown 正反面")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 104)
        }
    }
}

private struct QuickActionsRow: View {
    @ObservedObject var store: WorkspaceStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("快速功能").dsType(DS.Font.section).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    NavigationLink { FlashcardDecksView() } label: { FlashcardsEntryCard().frame(width: 220) }
                        .buttonStyle(DSCardLinkStyle())
                    if let first = store.workspaces.first {
                        NavigationLink { BankBooksView(vm: store.vm(for: first.id)) } label: { BankBooksEntryCard().frame(width: 220) }
                            .buttonStyle(DSCardLinkStyle())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

private struct BankBooksEntryCard: View {
    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: 10) {
                    Image(systemName: "books.vertical")
                        .font(.title3)
                        .foregroundStyle(DS.Brand.scheme.stucco.opacity(0.85))
                        .frame(width: 28)
                    Text("題庫本")
                        .dsType(DS.Font.serifBody)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                DSSeparator(color: DS.Palette.border.opacity(0.12))
                Text("主題書本 / 練習題庫")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 104)
        }
    }
}

// 移除晶片變體：回到簡潔文本副標

private struct StatusBadge: View {
    var text: String
    var color: Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).dsType(DS.Font.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .overlay(Capsule().stroke(DS.Palette.border.opacity(0.45), lineWidth: DS.BorderWidth.regular))
    }
}

private struct RenameWorkspaceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    let onDone: (String) -> Void
    init(name: String, onDone: @escaping (String) -> Void) {
        self._text = State(initialValue: name)
        self.onDone = onDone
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("重新命名").dsType(DS.Font.section)
            TextField("名稱", text: $text)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("完成") {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { onDone(trimmed) }
                    dismiss()
                }
                .buttonStyle(DSPrimaryButton())
                .frame(width: 120)
            }
        }
        .padding(16)
        .background(DS.Palette.background)
    }
}
