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
    var response: ChatResearchResponse
    @EnvironmentObject private var savedStore: SavedErrorsStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    @State private var savedItemIDs: Set<UUID> = []
    @State private var isExpanded: Bool = false
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Button {
                guard !response.items.isEmpty else { return }
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

                    if !response.items.isEmpty {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if response.items.isEmpty {
                Text(String(localized: "chat.research.ready"))
                    .dsType(DS.Font.body)
                    .foregroundStyle(.secondary)
            } else if isExpanded {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(response.items) { item in
                        ResearchItemCard(
                            item: item,
                            isSaved: savedItemIDs.contains(item.id),
                            onSave: { saveItem(item) }
                        )
                    }
                }
            } else {
                Text(collapsedHint(for: response.items.count))
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
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
        .onChange(of: response.id) { _, _ in
            savedItemIDs.removeAll()
            isExpanded = false
        }
    }

    private func saveItem(_ item: ChatResearchItem) {
        guard !savedItemIDs.contains(item.id) else { return }
        let payload = ResearchSavePayload(
            term: item.term,
            explanation: item.explanation,
            context: item.context,
            type: item.type,
            savedAt: Date()
        )
        savedStore.add(research: payload)
        savedItemIDs.insert(item.id)
        Haptics.success()
        bannerCenter.show(
            title: String(localized: "banner.researchSaved.title"),
            subtitle: item.term
        )
    }

    private func collapsedHint(for count: Int) -> String {
        let template = String(localized: "chat.research.collapsedHint", locale: locale)
        return String(format: template, locale: locale, count)
    }
}

struct ResearchItemCard: View {
    var item: ChatResearchItem
    var isSaved: Bool
    var onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm2) {
                    TagLabel(text: item.type.displayName, color: item.type.color)
                    Text(item.term)
                        .dsType(DS.Font.section)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }

                Text(item.explanation)
                    .dsType(DS.Font.body, lineSpacing: 4)
                    .foregroundStyle(.secondary)

                if !item.context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("chat.research.context")
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                        Text(item.context)
                            .dsType(DS.Font.body, lineSpacing: 4)
                            .foregroundStyle(.primary)
                    }
                }
            }

            DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(0.35))

            HStack {
                Spacer()
                Button(action: onSave) {
                    if isSaved {
                        Label(String(localized: "chat.research.saved"), systemImage: "checkmark.seal.fill")
                    } else {
                        Label(String(localized: "chat.research.save"), systemImage: "tray.and.arrow.down")
                    }
                }
                .buttonStyle(DSButton(style: .secondary, size: .compact))
                .disabled(isSaved)
            }
        }
        .padding(DS.Spacing.md2)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(item.type.color.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.hairline)
                .overlay(
                    Rectangle()
                        .fill(item.type.color)
                        .frame(width: DS.IconSize.dividerThin)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Component.Stripe.cornerRadius, style: .continuous))
                        .padding(.vertical, DS.Component.Stripe.paddingVertical), alignment: .leading
                )
        )
    }
}
