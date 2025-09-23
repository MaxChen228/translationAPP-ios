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
                HStack(spacing: 4) {
                    if activeStash == .left {
                        Text(String(localized: "saved.stash.left", locale: locale))
                    } else {
                        Text(String(localized: "saved.stash.right", locale: locale))
                    }
                    Text("\(currentCount)")
                }
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)
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

    private func saveDeck(named name: String) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        guard AppConfig.correctAPIURL != nil else {
            bannerCenter.show(title: String(localized: "banner.backend.missing.title", locale: locale), subtitle: String(localized: "banner.backend.missing.subtitle", locale: locale))
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let records = store.items(in: activeStash)
            var requestItems: [DeckMakeRequest.Item] = []
            requestItems.reserveCapacity(records.count)
            for rec in records {
                guard let data = rec.json.data(using: .utf8) else { continue }
                switch rec.source {
                case .correction:
                    if let payload = try? decoder.decode(ErrorSavePayload.self, from: data) {
                        requestItems.append(.correction(payload))
                    }
                case .research:
                    if let payload = try? decoder.decode(ResearchSavePayload.self, from: data) {
                        requestItems.append(.research(payload))
                    }
                }
            }
            let effectiveName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "deck.untitled", locale: locale) : name
            let (resolvedName, cards) = try await deckService.makeDeck(name: effectiveName, items: requestItems)
            _ = decksStore.add(name: resolvedName, cards: cards)
            showSaveDeckSheet = false
            let subtitle = "\(resolvedName) • " + String(format: String(localized: "deck.cards.count", locale: locale), cards.count)
            bannerCenter.show(title: String(localized: "banner.deckSaved.title", locale: locale), subtitle: subtitle)
        } catch {
            saveError = (error as NSError).localizedDescription
        }
    }
}

// MARK: - Helpers / Models

private extension SavedJSONListSheet {
    func rebuildDecoded() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoded = store.items.map { rec in
            let correction: ErrorSavePayload?
            let research: ResearchSavePayload?
            let data = rec.json.data(using: .utf8)
            switch rec.source {
            case .correction:
                correction = data.flatMap { try? decoder.decode(ErrorSavePayload.self, from: $0) }
                research = nil
            case .research:
                research = data.flatMap { try? decoder.decode(ResearchSavePayload.self, from: $0) }
                correction = nil
            }
            let display = Self.makeDisplay(for: rec, correction: correction, research: research, locale: locale)
            return DecodedRecord(
                id: rec.id,
                createdAt: rec.createdAt,
                rawJSON: rec.json,
                stash: rec.stash,
                source: rec.source,
                correction: correction,
                research: research,
                display: display
            )
        }
        decoded.sort { $0.createdAt > $1.createdAt }
    }

    static func makeDisplay(for record: SavedErrorRecord, correction: ErrorSavePayload?, research: ResearchSavePayload?, locale: Locale) -> DecodedRecordDisplay {
        let unparsable = String(localized: "saved.unparsable", locale: locale)
        switch record.source {
        case .correction:
            guard let payload = correction else {
                return DecodedRecordDisplay(summary: unparsable, explanation: nil, zhLine: nil, originalLine: nil, correctedLine: nil, contextTitle: nil, context: nil, hintBefore: nil, hintAfter: nil)
            }
            let summary: String
            if let suggestion = payload.error.suggestion, !suggestion.isEmpty {
                summary = "'\(payload.error.span)' → '\(suggestion)'"
            } else {
                summary = "'\(payload.error.span)' · \(payload.correctedEn)"
            }
            let zhPrefix = String(localized: "label.zhPrefix", locale: locale)
            let originalPrefix = String(localized: "label.enOriginalPrefix", locale: locale)
            let correctedPrefix = String(localized: "label.enCorrectedPrefix", locale: locale)
            let explanation = payload.error.explainZh.isEmpty ? nil : payload.error.explainZh
            return DecodedRecordDisplay(
                summary: summary,
                explanation: explanation,
                zhLine: zhPrefix + payload.inputZh,
                originalLine: originalPrefix + payload.inputEn,
                correctedLine: correctedPrefix + payload.correctedEn,
                contextTitle: nil,
                context: nil,
                hintBefore: payload.error.hints?.before,
                hintAfter: payload.error.hints?.after
            )
        case .research:
            guard let payload = research else {
                return DecodedRecordDisplay(summary: unparsable, explanation: nil, zhLine: nil, originalLine: nil, correctedLine: nil, contextTitle: nil, context: nil, hintBefore: nil, hintAfter: nil)
            }
            let contextTitle = String(localized: "chat.research.context", locale: locale)
            return DecodedRecordDisplay(
                summary: payload.term,
                explanation: payload.explanation,
                zhLine: nil,
                originalLine: nil,
                correctedLine: nil,
                contextTitle: contextTitle,
                context: payload.context,
                hintBefore: nil,
                hintAfter: nil
            )
        }
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

