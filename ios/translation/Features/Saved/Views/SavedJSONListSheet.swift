import SwiftUI
import Foundation

struct SavedJSONListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: SavedErrorsStore
    @EnvironmentObject var decksStore: FlashcardDecksStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    @State private var showSaveDeckSheet = false
    @State private var proposedName: String = String(localized: "deck.untitled")
    @State private var isSaving = false
    @State private var saveError: String? = nil
    private let deckService: DeckService = DeckServiceFactory.makeDefault()

    // Decoded rows and UI state (expand/collapse)
    @State private var decoded: [DecodedRecord] = []
    @State private var expanded: Set<UUID> = []
    // Two temporary stashes: left/right
    @State private var activeStash: SavedStash = .left
    @State private var editingRecord: DecodedRecord? = nil
    @State private var editDraft: String = ""
    @Environment(\.locale) private var locale

    var body: some View {
        Group {
            if filteredDecoded.isEmpty {
                emptyState
            } else {
                populatedState
            }
        }
        .navigationTitle(Text("nav.savedJSON"))
        .sheet(isPresented: $showSaveDeckSheet) {
            SaveDeckNameSheet(name: proposedName, count: filteredDecoded.count, isSaving: isSaving) { action in
                switch action {
                case .cancel:
                    showSaveDeckSheet = false
                case .save(let name):
                    saveDeck(named: name)
                }
            }
            .presentationDetents([.height(220)])
        }
        .sheet(item: $editingRecord, onDismiss: { editDraft = "" }) { record in
            SavedRecordEditSheet(record: record, text: $editDraft) {
                guard validateEditedJSON() else { return }
                store.update(record.id, json: editDraft)
                bannerCenter.show(title: String(localized: "saved.edit.success", locale: locale), subtitle: nil)
                editDraft = ""
                editingRecord = nil
            } onCancel: {
                editDraft = ""
                editingRecord = nil
            }
        }
        .alert(saveError ?? "", isPresented: Binding(get: { saveError != nil }, set: { _ in saveError = nil })) {}
        .overlay(alignment: .center) {
            if isSaving { LoadingOverlay(textKey: "loading.making") }
        }
        .overlay(alignment: .bottomTrailing) {
            BannerHost().environmentObject(bannerCenter)
        }
        .onAppear { rebuildDecoded() }
        .onChange(of: store.items, initial: false) { _, _ in rebuildDecoded() }
        .id(locale.identifier)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            controlBar
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DS.Palette.background)
    }

    private var populatedState: some View {
        VStack(spacing: 0) {
            controlBar
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)

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
        .background(DS.Palette.background)
    }

    private var controlBar: some View {
        HStack(spacing: DS.Spacing.md) {
            Button(String(localized: "saved.clear", locale: locale), role: .destructive) { store.clear(activeStash) }
                .buttonStyle(DSButton(style: .secondary, size: .compact))
                .disabled(isSaving)

            Spacer(minLength: 0)

            let stashTitle = activeStash == .left
                ? String(localized: "saved.stash.left", locale: locale)
                : String(localized: "saved.stash.right", locale: locale)

            HStack(spacing: 8) {
                DSQuickActionIconButton(
                    systemName: "chevron.left",
                    labelKey: "saved.switchLeft",
                    action: { DSMotion.run(DS.AnimationToken.bouncy) { activeStash = .left } },
                    shape: .circle,
                    style: .outline,
                    size: 32
                )
                .disabled(activeStash == .left)

                Text("\(stashTitle) · \(currentCount)")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity)

                DSQuickActionIconButton(
                    systemName: "chevron.right",
                    labelKey: "saved.switchRight",
                    action: { DSMotion.run(DS.AnimationToken.bouncy) { activeStash = .right } },
                    shape: .circle,
                    style: .outline,
                    size: 32
                )
                .disabled(activeStash == .right)
            }
            .frame(minWidth: 120, idealWidth: 140, maxWidth: 160)

            Spacer(minLength: 0)

            Button {
                if AppConfig.correctAPIURL == nil {
                    bannerCenter.show(title: String(localized: "banner.backend.missing.title", locale: locale), subtitle: String(localized: "banner.backend.missing.subtitle", locale: locale))
                } else {
                    proposedName = String(localized: "deck.untitled", locale: locale)
                    showSaveDeckSheet = true
                }
            } label: { Text("saved.saveDeck") }
                .buttonStyle(DSButton(style: .secondary, size: .compact))
                .disabled(isSaving || filteredDecoded.isEmpty)
        }
    }

    private func saveDeck(named name: String) {
        guard !isSaving else { return }
        guard AppConfig.correctAPIURL != nil else {
            bannerCenter.show(title: String(localized: "banner.backend.missing.title", locale: locale), subtitle: String(localized: "banner.backend.missing.subtitle", locale: locale))
            return
        }

        let stash = activeStash
        let records = store.items(in: stash)
        if records.isEmpty {
            bannerCenter.show(title: String(localized: "saved.empty", locale: locale), subtitle: nil)
            return
        }

        let effectiveName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "deck.untitled", locale: locale) : name
        let deckService = self.deckService
        let decksStore = self.decksStore
        let savedStore = self.store
        let bannerCenter = self.bannerCenter
        let locale = self.locale

        isSaving = true

        Task.detached(priority: .userInitiated) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var requestItems: [DeckMakeRequest.Item] = []
            requestItems.reserveCapacity(records.count)
            var nextIndex = 1
            for rec in records {
                guard let data = rec.json.data(using: .utf8),
                      let payload = try? decoder.decode(KnowledgeSavePayload.self, from: data) else { continue }
                requestItems.append(.knowledge(payload, index: nextIndex))
                nextIndex += 1
            }

            do {
                let (resolvedName, cards) = try await deckService.makeDeck(name: effectiveName, concepts: requestItems)
                let recordIDs = records.map(\.id)
                await MainActor.run {
                    savedStore.markDecked(recordIDs)
                    _ = decksStore.add(name: resolvedName, cards: cards)
                    showSaveDeckSheet = false
                    isSaving = false
                    let subtitle = "\(resolvedName) • " + String(format: String(localized: "deck.cards.count", locale: locale), cards.count)
                    bannerCenter.show(title: String(localized: "banner.deckSaved.title", locale: locale), subtitle: subtitle)
                }
            } catch {
                await MainActor.run {
                    saveError = (error as NSError).localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Helpers / Models

private extension SavedJSONListSheet {
    func rebuildDecoded() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoded = store.items.map { rec in
            let payload = rec.json.data(using: .utf8).flatMap { try? decoder.decode(KnowledgeSavePayload.self, from: $0) }
            let display = Self.makeDisplay(for: payload, locale: locale)
            return DecodedRecord(
                id: rec.id,
                createdAt: rec.createdAt,
                rawJSON: rec.json,
                stash: rec.stash,
                deckedAt: rec.deckedAt,
                payload: payload,
                display: display
            )
        }
        decoded.sort { $0.createdAt > $1.createdAt }
    }

    static func makeDisplay(for payload: KnowledgeSavePayload?, locale: Locale) -> DecodedRecordDisplay {
        guard let payload else {
            let fallback = String(localized: "saved.unparsable", locale: locale)
            return DecodedRecordDisplay(title: fallback, explanation: "", correctExample: "", note: nil)
        }
        return DecodedRecordDisplay(
            title: payload.title,
            explanation: payload.explanation,
            correctExample: payload.correctExample,
            note: payload.note
        )
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

    func beginEdit(_ row: DecodedRecord) {
        editDraft = row.rawJSON
        editingRecord = row
    }

    func validateEditedJSON() -> Bool {
        guard let data = editDraft.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            bannerCenter.show(title: String(localized: "saved.edit.invalid", locale: locale), subtitle: nil)
            return false
        }
        return true
    }

    var filteredDecoded: [DecodedRecord] { decoded.filter { $0.stash == activeStash } }
    var currentCount: Int { store.count(in: activeStash) }
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
            List {
                ForEach(rows) { row in
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
                        onEdit: { beginEdit(row) },
                        onDelete: { deleteRow(row.id) }
                    )
                    .swipeActions(edge: .leading, allowsFullSwipe: stash == .left) {
                        if stash == .left {
                            Button {
                                store.move(row.id, to: .right)
                                Haptics.success()
                            } label: {
                                Label(String(localized: "saved.moveRight", locale: locale), systemImage: "arrow.uturn.forward.circle")
                            }
                            .tint(DS.Brand.scheme.classicBlue)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: stash == .right) {
                        if stash == .right {
                            Button {
                                store.move(row.id, to: .left)
                                Haptics.success()
                            } label: {
                                Label(String(localized: "saved.moveLeft", locale: locale), systemImage: "arrow.uturn.backward.circle")
                            }
                            .tint(DS.Brand.scheme.provence)
                        }
                    }
                    .listRowInsets(.init(top: 0, leading: DS.Spacing.lg, bottom: DS.Spacing.md, trailing: DS.Spacing.lg))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DS.Palette.background)
            .dsAnimation(DS.AnimationToken.reorder, value: rows.map { $0.id })
        }
    }
}
