import SwiftUI

struct BankItemCard<TrailingContent: View>: View {
    let item: BankItem
    let bookName: String?
    @Binding var isExpanded: Bool
    let trailingContent: () -> TrailingContent

    init(
        item: BankItem,
        bookName: String? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent
    ) {
        self.item = item
        self.bookName = bookName
        self._isExpanded = isExpanded
        self.trailingContent = trailingContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md2) {
            mainTextCard
            HStack(alignment: .center, spacing: DS.Spacing.sm) {
                metadataSection
                Spacer(minLength: 0)
                trailingContent()
            }
            HintListSection(
                hints: item.hints,
                isExpanded: $isExpanded
            )
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    private var mainTextCard: some View {
        Text(item.zh)
            .dsType(DS.Font.serifTitle, lineSpacing: 6, tracking: 0.1)
            .padding(.vertical, DS.Spacing.md)
            .padding(.horizontal, DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(DS.Palette.border.opacity(DS.Opacity.muted), lineWidth: DS.BorderWidth.regular)
                    .background(DS.Palette.surface.opacity(0.0001))
            )
    }

    private var metadataSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            difficultyBadge
            if let bookName, !bookName.isEmpty {
                Text(bookName)
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            if let tags = item.tags, !tags.isEmpty {
                Text(tags.joined(separator: ", "))
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var difficultyBadge: some View {
        Text(BankItemDifficulty.romanNumeral(for: item.difficulty))
            .dsType(DS.Font.labelSm)
            .foregroundStyle(DS.Palette.primary.opacity(0.8))
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs2)
            .background(
                Capsule().fill(DS.Palette.primary.opacity(0.1))
            )
    }
}

extension BankItemCard where TrailingContent == EmptyView {
    init(item: BankItem, bookName: String? = nil, isExpanded: Binding<Bool>) {
        self.init(item: item, bookName: bookName, isExpanded: isExpanded) {
            EmptyView()
        }
    }
}
