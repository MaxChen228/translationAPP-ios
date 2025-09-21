import SwiftUI

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
                .buttonStyle(DSSecondaryButtonCompact())
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
                Text("\(currentCount) / \(otherCount)")
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
                .buttonStyle(DSSecondaryButtonCompact())
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

private struct DecodedRecord: Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let rawJSON: String
    let stash: SavedStash
    let source: SavedSource
    let correction: ErrorSavePayload?
    let research: ResearchSavePayload?
}

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
            return DecodedRecord(
                id: rec.id,
                createdAt: rec.createdAt,
                rawJSON: rec.json,
                stash: rec.stash,
                source: rec.source,
                correction: correction,
                research: research
            )
        }
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
        DSCard(fill: DS.Palette.surface) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    summaryContent
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .foregroundStyle(.tertiary)
                        .dsAnimation(DS.AnimationToken.subtle, value: expanded)
                }
                .contentShape(Rectangle())
                .onTapGesture { onToggle() }

                if expanded {
                    expandedContent
                        .transition(DSTransition.fade)
                }
            }
        }
    }

    private var summaryContent: some View {
        Group {
            switch row.source {
            case .correction:
                if let payload = row.correction {
                    TagLabel(text: payload.error.type.displayName, color: payload.error.type.color)
                    sourceBadge(text: "saved.source.correction", color: DS.Brand.scheme.monument)
                    Text(summaryText(for: row))
                        .dsType(DS.Font.body)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                } else {
                    parseErrorText
                }
            case .research:
                if let payload = row.research {
                    TagLabel(text: payload.type.displayName, color: payload.type.color)
                    sourceBadge(text: "saved.source.research", color: DS.Brand.scheme.provence)
                    Text(summaryText(for: row))
                        .dsType(DS.Font.body)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                } else {
                    parseErrorText
                }
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        switch row.source {
        case .correction:
            if let payload = row.correction {
                correctionDetail(payload)
            } else {
                rawJSONView
            }
        case .research:
            if let payload = row.research {
                researchDetail(payload)
            } else {
                rawJSONView
            }
        }
    }

    private func correctionDetail(_ payload: ErrorSavePayload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !payload.error.explainZh.isEmpty {
                Text(payload.error.explainZh)
                    .dsType(DS.Font.body)
                    .foregroundStyle(.secondary)
            }
            if let suggestion = payload.error.suggestion, !suggestion.isEmpty {
                SuggestionChip(text: suggestion, color: payload.error.type.color)
            }
            Group {
                Text(String(localized: "label.zhPrefix", locale: locale) + payload.inputZh)
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
                Text(String(localized: "label.enOriginalPrefix", locale: locale) + payload.inputEn)
                    .dsType(DS.Font.body)
                Text(String(localized: "label.enCorrectedPrefix", locale: locale) + payload.correctedEn)
                    .dsType(DS.Font.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            footerActions
        }
    }

    private func researchDetail(_ payload: ResearchSavePayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(payload.explanation)
                .dsType(DS.Font.body, lineSpacing: 6)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "chat.research.context", locale: locale))
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
                Text(payload.context)
                    .dsType(DS.Font.body)
            }

            footerActions
        }
    }

    private var footerActions: some View {
        HStack(spacing: DS.Spacing.sm2) {
            Button {
                onCopy()
                DSMotion.run(DS.AnimationToken.subtle) { didCopy = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    didCopy = false
                }
            } label: {
                if didCopy {
                    Label(String(localized: "action.copied", locale: locale), systemImage: "checkmark")
                } else {
                    Label(String(localized: "action.copy", locale: locale), systemImage: "doc.on.doc")
                }
            }
            .buttonStyle(DSSecondaryButtonCompact())

            Spacer(minLength: 0)

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label(String(localized: "action.delete", locale: locale), systemImage: "trash")
            }
            .buttonStyle(DSSecondaryButtonCompact())
            .confirmationDialog(String(localized: "saved.delete.confirm", locale: locale), isPresented: $showDeleteConfirm, actions: {
                Button(String(localized: "action.delete", locale: locale), role: .destructive) { onDelete() }
            })
        }
    }

    private var parseErrorText: some View {
        Text(String(localized: "saved.unparsable", locale: locale))
            .dsType(DS.Font.body)
            .foregroundStyle(.secondary)
    }

    private func sourceBadge(text: LocalizedStringKey, color: Color) -> some View {
        Text(text)
            .dsType(DS.Font.caption)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.sm2)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    @ViewBuilder
    private var rawJSONView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            parseErrorText
            ScrollView(.horizontal, showsIndicators: true) {
                Text(row.rawJSON)
                    .font(DS.Font.monoSmall)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            footerActions
        }
    }

    private func summaryText(for row: DecodedRecord) -> String {
        switch row.source {
        case .correction:
            guard let payload = row.correction else { return String(localized: "saved.unparsable", locale: locale) }
            let span = payload.error.span
            if let suggestion = payload.error.suggestion, !suggestion.isEmpty {
                return "'\(span)' → '\(suggestion)'"
            }
            return "'\(span)' · \(payload.correctedEn)"
        case .research:
            guard let payload = row.research else { return String(localized: "saved.unparsable", locale: locale) }
            return payload.term
        }
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

            TextField(String(localized: "saved.deckName.placeholder", locale: locale), text: $text)
                .textFieldStyle(.roundedBorder)
                .disabled(isSaving)

            HStack {
                Button(role: .cancel) {
                    onAction(.cancel)
                    dismiss()
                } label: { Text("action.cancel", tableName: nil, bundle: .main) }
                .buttonStyle(DSSecondaryButtonCompact())
                .disabled(isSaving)

                Spacer()

                Button {
                    onAction(.save(text))
                    dismiss()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("action.save", tableName: nil, bundle: .main)
                    }
                }
                .buttonStyle(DSPrimaryButtonCompact())
                .disabled(isSaving)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }
}