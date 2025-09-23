import SwiftUI

struct ChatChecklistCard: View {
    var titleKey: LocalizedStringKey
    var items: [String]
    var showResearchButton: Bool = false
    var isResearchButtonEnabled: Bool = true
    var onResearch: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .center, spacing: DS.Spacing.sm) {
                Label {
                    Text(titleKey).dsType(DS.Font.section)
                } icon: {
                    Image(systemName: "checklist")
                        .foregroundStyle(DS.Brand.scheme.classicBlue)
                }

                Spacer(minLength: 0)

                if showResearchButton, let onResearch {
                    Button(action: onResearch) {
                        Label("chat.research", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(DSButton(style: .secondary, size: .compact))
                    .disabled(!isResearchButtonEnabled)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(DS.Palette.primary)
                            .padding(.top, 5)
                        Text(item)
                            .dsType(DS.Font.body, lineSpacing: 4)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.thin)
        )
    }
}

struct ChatResearchCard: View {
    var deck: ChatResearchDeck
    @EnvironmentObject private var decksStore: FlashcardDecksStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    @Environment(\.locale) private var locale

    @State private var isExpanded: Bool = true
    @State private var deckName: String
    @State private var isSaving: Bool = false
    @State private var hasSaved: Bool = false

    init(deck: ChatResearchDeck) {
        self.deck = deck
        _deckName = State(initialValue: deck.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            header

            nameField

            if deck.cards.isEmpty {
                Text(String(localized: "chat.research.empty"))
                    .dsType(DS.Font.body)
                    .foregroundStyle(.secondary)
            } else {
                saveButton

                if isExpanded {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        ForEach(deck.cards) { card in
                            FlashcardPreviewCard(card: card)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Text(summaryText)
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.thin)
        )
        .shadow(color: DS.Shadow.card.color, radius: DS.Shadow.card.radius, x: DS.Shadow.card.x, y: DS.Shadow.card.y)
        .onChange(of: deck.id) { _, _ in resetState() }
    }

    private var header: some View {
        Button {
            guard !deck.cards.isEmpty else { return }
            withAnimation(DS.AnimationToken.subtle) { isExpanded.toggle() }
        } label: {
            HStack(alignment: .center, spacing: DS.Spacing.sm) {
                Label {
                    Text("chat.researchResult").dsType(DS.Font.section)
                } icon: {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(DS.Brand.scheme.peachQuartz)
                }

                Spacer(minLength: 0)

                if !deck.cards.isEmpty {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, DS.Spacing.sm)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(String(localized: "chat.research.deckName"))
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)
            TextField(String(localized: "chat.research.deckName.placeholder"), text: $deckName)
                .textFieldStyle(.plain)
                .padding(.vertical, 10)
                .padding(.horizontal, DS.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .stroke(DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.thin)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .fill(DS.Palette.surfaceAlt.opacity(DS.Opacity.fill))
                        )
                )
        }
    }

    private var saveButton: some View {
        Button {
            Task { await saveDeck() }
        } label: {
            Label(String(localized: hasSaved ? "chat.research.deckSaved" : "chat.research.saveDeck"), systemImage: hasSaved ? "checkmark.seal.fill" : "tray.and.arrow.down")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(DSButton(style: hasSaved ? .secondary : .primary, size: .full))
        .disabled(isSaving || deck.cards.isEmpty || hasSaved)
    }

    private var summaryText: String {
        let countString = String(format: String(localized: "deck.cards.count", locale: locale), deck.cards.count)
        let dateText = deck.generatedAt.formatted(date: .abbreviated, time: .shortened)
        let template = String(localized: "chat.research.deckSummary", locale: locale)
        return String(format: template, locale: locale, countString, dateText)
    }

    private func resetState() {
        deckName = deck.name
        hasSaved = false
        isSaving = false
        isExpanded = true
    }

    @MainActor
    private func saveDeck() async {
        guard !deck.cards.isEmpty else { return }
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let trimmed = deckName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? String(localized: "chat.research.deckDefaultName", locale: locale) : trimmed
        let deck = decksStore.add(name: resolvedName, cards: deck.cards)
        hasSaved = true
        Haptics.success()
        let subtitleCount = String(format: String(localized: "deck.cards.count", locale: locale), deck.cards.count)
        let subtitle = "\(resolvedName) • \(subtitleCount)"
        bannerCenter.show(title: String(localized: "banner.deckSaved.title", locale: locale), subtitle: subtitle)
    }
}

private struct FlashcardPreviewCard: View {
    var card: Flashcard

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("chat.research.front")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
                Text(card.front)
                    .dsType(DS.Font.bodyEmph, lineSpacing: 6)
                    .foregroundStyle(.primary)
                if let note = card.frontNote, !note.isEmpty {
                    Text(note)
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("chat.research.back")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
                Text(card.back)
                    .dsType(DS.Font.body, lineSpacing: 6)
                    .foregroundStyle(.primary)
                if let note = card.backNote, !note.isEmpty {
                    Text(note)
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Palette.surfaceAlt.opacity(DS.Opacity.fill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.hairline)
        )
    }
}
