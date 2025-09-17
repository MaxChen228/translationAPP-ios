import SwiftUI

struct SavedJSONListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: SavedErrorsStore
    @EnvironmentObject var decksStore: FlashcardDecksStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    @State private var showSaveDeckSheet = false
    @State private var proposedName: String = "未命名"
    @State private var isSaving = false
    @State private var saveError: String? = nil
    private let deckService: DeckService = DeckServiceFactory.makeDefault()

    // Decoded rows and UI state (expand/collapse)
    @State private var decoded: [DecodedRecord] = []
    @State private var expanded: Set<UUID> = []
    // Two temporary stashes: left/right
    @State private var activeStash: SavedStash = .left

    var body: some View {
            Group {
                if filteredDecoded.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(emptyText)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DS.Palette.background)
                } else {
                    ScrollView {
                        // 操作列：左右切換 + 清空/儲存
                        HStack(spacing: DS.Spacing.md) {
                            Button("清空", role: .destructive) { store.clear(activeStash) }
                                .buttonStyle(DSSecondaryButtonCompact())
                                .disabled(isSaving)
                            Spacer(minLength: 0)
                            // Stash switcher with counts
                            HStack(spacing: 8) {
                                Button { withAnimation { activeStash = .left } } label: {
                                    Image(systemName: "chevron.left")
                                }
                                .buttonStyle(DSOutlineCircleButton())
                                .disabled(activeStash == .left)
                                Text("\(store.count(in: .left)) / \(store.count(in: .right))")
                                    .dsType(DS.Font.caption)
                                    .foregroundStyle(.secondary)
                                Button { withAnimation { activeStash = .right } } label: {
                                    Image(systemName: "chevron.right")
                                }
                                .buttonStyle(DSOutlineCircleButton())
                                .disabled(activeStash == .right)
                            }
                            Spacer(minLength: 0)
                            Button("儲存單字卡") { proposedName = "未命名"; showSaveDeckSheet = true }
                                .buttonStyle(DSSecondaryButtonCompact())
                                .disabled(isSaving || filteredDecoded.isEmpty)
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.lg)

                        LazyVStack(alignment: .leading, spacing: DS.Spacing.md) {
                            ForEach(filteredDecoded) { row in
                                SwipeableRow(
                                    allowLeft: activeStash == .right,
                                    allowRight: activeStash == .left,
                                    onTriggerLeft: {
                                        // Move back to left but stay on right stash
                                        store.move(row.id, to: .left)
                                        Haptics.success()
                                    },
                                    onTriggerRight: {
                                        // Move to right and switch to right stash
                                        store.move(row.id, to: .right)
                                        Haptics.success()
                                        withAnimation { activeStash = .right }
                                    }
                                ) {
                                    SavedErrorRowCard(
                                        row: row,
                                        expanded: expanded.contains(row.id),
                                        onToggle: {
                                            DSMotion.run(DS.AnimationToken.subtle) {
                                                if expanded.contains(row.id) { expanded.remove(row.id) }
                                                else { expanded.insert(row.id) }
                                            }
                                        },
                                        onCopy: { copyJSON(row.rawJSON) },
                                        onDelete: { deleteRow(row.id) }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.md)
                        .padding(.bottom, DS.Spacing.lg)
                    }
                }
            }
            .navigationTitle("已儲存 JSON")
            .navigationBarBackButtonHidden(isSaving)
            .sheet(isPresented: $showSaveDeckSheet) {
                SaveDeckNameSheet(name: proposedName, count: filteredDecoded.count, isSaving: isSaving) { action in
                    switch action {
                    case .cancel:
                        showSaveDeckSheet = false
                    case .save(let name):
                        Task { await saveDeck(named: name) }
                    }
                }
                .presentationDetents([.height(220)])
            }
            .alert(saveError ?? "", isPresented: Binding(get: { saveError != nil }, set: { _ in saveError = nil })) {}
            // 進行中轉圈圈（不會被中斷）；顯示在本 sheet 之上
            .overlay(alignment: .center) {
                if isSaving { LoadingOverlay(text: "製作中…") }
            }
            // 橫幅位階最高：在本 sheet 也疊一層 BannerHost
            .overlay(alignment: .bottomTrailing) {
                BannerHost().environmentObject(bannerCenter)
            }
        .onAppear { rebuildDecoded() }
        .onChange(of: store.items, initial: false) { _, _ in rebuildDecoded() }
    }

    private func saveDeck(named name: String) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            // Decode saved payloads
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payloads: [ErrorSavePayload] = store.items(in: activeStash).compactMap { rec in
                guard let data = rec.json.data(using: .utf8) else { return nil }
                return try? decoder.decode(ErrorSavePayload.self, from: data)
            }
            let effectiveName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名" : name
            let (resolvedName, cards) = try await deckService.makeDeck(name: effectiveName, from: payloads)
            _ = decksStore.add(name: resolvedName, cards: cards)
            showSaveDeckSheet = false
            // Show confirmation banner (bottom-right, via BannerHost)
            let subtitle = "\(resolvedName) • \(cards.count) 張"
            bannerCenter.show(title: "已儲存單字卡", subtitle: subtitle)
        } catch {
            saveError = (error as NSError).localizedDescription
        }
    }
}

// MARK: - Helpers / Models

private struct DecodedRecord: Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let rawJSON: String
    let payload: ErrorSavePayload?
    let stash: SavedStash
}

private extension SavedJSONListSheet {
    func rebuildDecoded() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoded = store.items.map { rec in
            let payload: ErrorSavePayload? = {
                guard let data = rec.json.data(using: .utf8) else { return nil }
                return try? decoder.decode(ErrorSavePayload.self, from: data)
            }()
            return DecodedRecord(id: rec.id, createdAt: rec.createdAt, rawJSON: rec.json, payload: payload, stash: rec.stash)
        }
        // 以時間倒序
        decoded.sort { $0.createdAt > $1.createdAt }
    }

    func copyJSON(_ s: String) {
        #if os(iOS)
        UIPasteboard.general.string = s
        #endif
    }

    func deleteRow(_ id: UUID) {
        store.remove(id)
        expanded.remove(id)
        decoded.removeAll { $0.id == id }
    }

    var filteredDecoded: [DecodedRecord] { decoded.filter { $0.stash == activeStash } }
    var emptyText: String { activeStash == .left ? "左暫存尚未儲存任何錯誤" : "右暫存尚未儲存任何錯誤" }
}

// MARK: - Row Card

private struct SavedErrorRowCard: View {
    let row: DecodedRecord
    let expanded: Bool
    let onToggle: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    @State private var didCopy = false
    @State private var showDeleteConfirm = false

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: 8) {
                // Summary (single line)
                HStack(spacing: 8) {
                    if let p = row.payload {
                        TagLabel(text: p.error.type.displayName, color: p.error.type.color)
                        Text(summaryText(p))
                            .dsType(DS.Font.body)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                    } else {
                        Text("無法解析此筆資料")
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .foregroundStyle(.tertiary)
                        .dsAnimation(DS.AnimationToken.subtle, value: expanded)
                }
                .contentShape(Rectangle())
                .onTapGesture { onToggle() }

                if expanded {
                    if let p = row.payload {
                        VStack(alignment: .leading, spacing: 8) {
                            if !p.error.explainZh.isEmpty {
                                Text(p.error.explainZh)
                                    .dsType(DS.Font.body)
                                    .foregroundStyle(.secondary)
                            }
                            if let s = p.error.suggestion, !s.isEmpty {
                                SuggestionChip(text: s, color: p.error.type.color)
                            }
                            Group {
                                Text("中文：\(p.inputZh)").dsType(DS.Font.caption).foregroundStyle(.secondary)
                                Text("原句：\(p.inputEn)").dsType(DS.Font.body)
                                Text("修正版：\(p.correctedEn)").dsType(DS.Font.body)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Footer actions
                            VStack(spacing: 6) {
                                DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(DS.Opacity.accentLight))
                                HStack {
                                    Spacer()
                                    Button {
                                        onCopy(); Haptics.success(); withAnimation(DS.AnimationToken.subtle) { didCopy = true }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { didCopy = false } }
                                    } label: {
                                        if didCopy { Label("已複製", systemImage: "checkmark.seal.fill") }
                                        else { Label("複製JSON", systemImage: "doc.on.doc") }
                                    }
                                        .buttonStyle(DSSecondaryButtonCompact())
                                    Button(role: .destructive) { showDeleteConfirm = true } label: { Label("刪除", systemImage: "trash") }
                                        .buttonStyle(DSSecondaryButtonCompact())
                                }
                            }
                            .padding(.top, 2)
                            .confirmationDialog("確定要刪除這筆紀錄嗎？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                                Button("刪除", role: .destructive) { onDelete(); Haptics.warning() }
                                Button("取消", role: .cancel) {}
                            }
                        }
                        .transition(.opacity)
                    } else {
                        // Fallback: show raw JSON (monospace) when parse fails
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(row.rawJSON)
                                .font(DS.Font.monoSmall)
                                .textSelection(.enabled)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        VStack(spacing: 6) {
                            DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(DS.Opacity.accentLight))
                            HStack {
                                Spacer()
                                Button {
                                    onCopy(); Haptics.success(); withAnimation(DS.AnimationToken.subtle) { didCopy = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { didCopy = false } }
                                } label: {
                                    if didCopy { Label("已複製", systemImage: "checkmark.seal.fill") }
                                    else { Label("複製JSON", systemImage: "doc.on.doc") }
                                }
                                    .buttonStyle(DSSecondaryButtonCompact())
                                Button(role: .destructive) { showDeleteConfirm = true } label: { Label("刪除", systemImage: "trash") }
                                    .buttonStyle(DSSecondaryButtonCompact())
                            }
                        }
                        .padding(.top, 2)
                        .transition(.opacity)
                        .confirmationDialog("確定要刪除這筆紀錄嗎？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                            Button("刪除", role: .destructive) { onDelete(); Haptics.warning() }
                            Button("取消", role: .cancel) {}
        }
        .zIndex(expanded ? 1 : 0)
        .animation(DS.AnimationToken.subtle, value: expanded)
    }
}
            }
        }
    }

    private func summaryText(_ p: ErrorSavePayload) -> String {
        let span = p.error.span
        let sug = p.error.suggestion ?? ""
        if !sug.isEmpty {
            return "'\(span)' → '\(sug)'"
        }
        // 若無 suggestion，就取 corrected 前 1 段當作摘要
        let corrected = p.correctedEn
        return "'\(span)' · \(corrected)"
    }
}

private struct SaveDeckNameSheet: View {
    enum Action { case cancel, save(String) }
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    let count: Int
    let isSaving: Bool
    let onAction: (Action) -> Void
    init(name: String, count: Int, isSaving: Bool, onAction: @escaping (Action) -> Void) {
        self._text = State(initialValue: name)
        self.count = count
        self.isSaving = isSaving
        self.onAction = onAction
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("儲存單字卡")
                .dsType(DS.Font.section)
            Text("將 \(count) 筆已儲存內容整理為卡片集。請命名：")
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)
            TextField("未命名", text: $text)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") { onAction(.cancel) }
                Button(isSaving ? "製作中…" : "儲存") {
                    onAction(.save(text))
                }
                .disabled(isSaving)
                .buttonStyle(DSPrimaryButton())
                .frame(width: 120)
            }
        }
        .padding(16)
        .background(DS.Palette.background)
    }
}

#Preview {
    SavedJSONListSheet().environmentObject(SavedErrorsStore())
}
