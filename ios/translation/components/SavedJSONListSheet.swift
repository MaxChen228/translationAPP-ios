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
    @Environment(\.locale) private var locale

    var body: some View {
            Group {
                if filteredDecoded.isEmpty {
                    VStack(spacing: 12) {
                        // 操作列：左右切換 + 清空/儲存（空狀態也顯示，方便切換）
                        HStack(spacing: DS.Spacing.md) {
                            Button(String(localized: "saved.clear", locale: locale), role: .destructive) { store.clear(activeStash) }
                                .buttonStyle(DSSecondaryButtonCompact())
                                .disabled(isSaving)
                            Spacer(minLength: 0)
                            HStack(spacing: 8) {
                                Button { DSMotion.run(DS.AnimationToken.bouncy) { activeStash = .left } } label: { Image(systemName: "chevron.left") }
                                    .buttonStyle(DSOutlineCircleButton())
                                    .disabled(activeStash == .left)
                                Text("\(currentCount) / \(otherCount)")
                                    .dsType(DS.Font.caption)
                                    .foregroundStyle(.secondary)
                                Button { DSMotion.run(DS.AnimationToken.bouncy) { activeStash = .right } } label: { Image(systemName: "chevron.right") }
                                    .buttonStyle(DSOutlineCircleButton())
                                    .disabled(activeStash == .right)
                            }
                            Spacer(minLength: 0)
                            Button {
                                if AppConfig.correctAPIURL == nil {
                                    bannerCenter.show(title: "未設定後端", subtitle: "請先設定 BACKEND_URL")
                                } else {
                                    proposedName = String(localized: "deck.untitled", locale: locale); showSaveDeckSheet = true
                                }
                            } label: { Text("saved.saveDeck") }
                                .buttonStyle(DSSecondaryButtonCompact())
                                .disabled(isSaving || filteredDecoded.isEmpty)
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.lg)

                        // 用同一套欄位呈現，支援滑入滑出
                        ZStack(alignment: .top) {
                            if activeStash == .left {
                                stashSection(for: .left)
                                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
                            } else {
                                stashSection(for: .right)
                                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                            }
                        }
                        .dsAnimation(DS.AnimationToken.snappy, value: activeStash)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(DS.Palette.background)
                } else {
                    ScrollView {
                        // 操作列：左右切換 + 清空/儲存
                        HStack(spacing: DS.Spacing.md) {
                            Button(String(localized: "saved.clear", locale: locale), role: .destructive) { store.clear(activeStash) }
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
                                Text("\(currentCount) / \(otherCount)")
                                    .dsType(DS.Font.caption)
                                    .foregroundStyle(.secondary)
                                Button { withAnimation { activeStash = .right } } label: {
                                    Image(systemName: "chevron.right")
                                }
                                .buttonStyle(DSOutlineCircleButton())
                                .disabled(activeStash == .right)
                            }
                            Spacer(minLength: 0)
                            Button {
                                if AppConfig.correctAPIURL == nil {
                                    bannerCenter.show(title: "未設定後端", subtitle: "請先設定 BACKEND_URL")
                                } else {
                                    proposedName = String(localized: "deck.untitled", locale: locale); showSaveDeckSheet = true
                                }
                            } label: { Text("saved.saveDeck") }
                                .buttonStyle(DSSecondaryButtonCompact())
                                .disabled(isSaving || filteredDecoded.isEmpty)
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.lg)

                        ZStack(alignment: .top) {
                            if activeStash == .left {
                                stashSection(for: .left)
                                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
                            } else {
                                stashSection(for: .right)
                                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                            }
                        }
                        .dsAnimation(DS.AnimationToken.snappy, value: activeStash)
                }
            }
            }
            .navigationTitle(Text("nav.savedJSON"))
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
                if isSaving { LoadingOverlay(textKey: "loading.making") }
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
        guard AppConfig.correctAPIURL != nil else {
            isSaving = false
            bannerCenter.show(title: "未設定後端", subtitle: "請先設定 BACKEND_URL")
            return
        }
        do {
            // Decode saved payloads
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payloads: [ErrorSavePayload] = store.items(in: activeStash).compactMap { rec in
                guard let data = rec.json.data(using: .utf8) else { return nil }
                return try? decoder.decode(ErrorSavePayload.self, from: data)
            }
            let effectiveName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "deck.untitled", locale: locale) : name
            let (resolvedName, cards) = try await deckService.makeDeck(name: effectiveName, from: payloads)
            _ = decksStore.add(name: resolvedName, cards: cards)
            showSaveDeckSheet = false
            // Show confirmation banner (bottom-right, via BannerHost)
            let subtitle = "\(resolvedName) • " + String(format: String(localized: "deck.cards.count", locale: locale), cards.count)
            bannerCenter.show(title: String(localized: "banner.deckSaved.title", locale: locale), subtitle: subtitle)
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
    var emptyText: String { String(localized: "saved.empty", locale: locale) }
    var currentCount: Int { store.count(in: activeStash) }
    var otherCount: Int { store.count(in: activeStash == .left ? .right : .left) }

    @ViewBuilder
    func stashSection(for stash: SavedStash) -> some View {
        let rows = decoded.filter { $0.stash == stash }
        if rows.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
                Text(String(localized: "saved.empty", locale: locale)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 300)
        } else {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.md) {
                ForEach(rows) { row in
                    SwipeableRow(
                        allowLeft: stash == .right,
                        allowRight: stash == .left,
                        onTriggerLeft: {
                            store.move(row.id, to: .left)
                            Haptics.success()
                        },
                        onTriggerRight: {
                            store.move(row.id, to: .right)
                            Haptics.success()
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
            .dsAnimation(DS.AnimationToken.reorder, value: rows.map { $0.id })
        }
    }
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
    @Environment(\.locale) private var locale

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
                        Text(String(localized: "saved.unparsable", locale: locale))
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
                                Text(String(localized: "label.zhPrefix", locale: locale) + p.inputZh).dsType(DS.Font.caption).foregroundStyle(.secondary)
                                Text(String(localized: "label.enOriginalPrefix", locale: locale) + p.inputEn).dsType(DS.Font.body)
                                Text(String(localized: "label.enCorrectedPrefix", locale: locale) + p.correctedEn).dsType(DS.Font.body)
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
                                        if didCopy { Label(String(localized: "action.copied", locale: locale), systemImage: "checkmark.seal.fill") }
                                        else { Label(String(localized: "action.copyJSON", locale: locale), systemImage: "doc.on.doc") }
                                    }
                                        .buttonStyle(DSSecondaryButtonCompact())
                                    Button(role: .destructive) { showDeleteConfirm = true } label: { Label(String(localized: "action.delete", locale: locale), systemImage: "trash") }
                                        .buttonStyle(DSSecondaryButtonCompact())
                                }
                            }
                            .padding(.top, 2)
                            .confirmationDialog(String(localized: "saved.confirm.delete", locale: locale), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                                Button(String(localized: "action.delete", locale: locale), role: .destructive) { onDelete(); Haptics.warning() }
                                Button(String(localized: "action.cancel", locale: locale), role: .cancel) {}
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
                                    if didCopy { Label(String(localized: "action.copied", locale: locale), systemImage: "checkmark.seal.fill") }
                                    else { Label(String(localized: "action.copyJSON", locale: locale), systemImage: "doc.on.doc") }
                                }
                                    .buttonStyle(DSSecondaryButtonCompact())
                                Button(role: .destructive) { showDeleteConfirm = true } label: { Label(String(localized: "action.delete", locale: locale), systemImage: "trash") }
                                    .buttonStyle(DSSecondaryButtonCompact())
                            }
                        }
                        .padding(.top, 2)
                        .transition(.opacity)
                        .confirmationDialog(String(localized: "saved.confirm.delete", locale: locale), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                            Button(String(localized: "action.delete", locale: locale), role: .destructive) { onDelete(); Haptics.warning() }
                            Button(String(localized: "action.cancel", locale: locale), role: .cancel) {}
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
    @Environment(\.locale) private var locale
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
            Text(String(localized: "saved.saveDeck", locale: locale))
                .dsType(DS.Font.section)
            Text(String(localized: "saved.saveDeck.prompt", locale: locale) + " \(count)")
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)
            TextField(String(localized: "deck.untitled", locale: locale), text: $text)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(String(localized: "action.cancel", locale: locale)) { onAction(.cancel) }
                Button(isSaving ? String(localized: "loading.making", locale: locale) : String(localized: "action.save", locale: locale)) {
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
