import SwiftUI

struct LocalBankListView: View {
    @ObservedObject var vm: CorrectionViewModel
    let bookName: String
    @EnvironmentObject private var localBank: LocalBankStore
    @State private var expanded: Set<String> = []

    var body: some View {
        let items = localBank.items(in: bookName)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if items.isEmpty {
                    EmptyStateCard(title: "本機書本為空", subtitle: "請從雲端瀏覽並複製題庫到本機。", iconSystemName: "text.book.closed")
                }
                ForEach(items.indices, id: \.self) { i in
                    if i > 0 {
                        DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(DS.Opacity.border)).padding(.vertical, DS.Spacing.sm)
                    }
                    let item = items[i]
                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.zh)
                            .dsType(DS.Font.serifTitle, lineSpacing: 6, tracking: 0.1)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                    .stroke(DS.Palette.border.opacity(DS.Opacity.muted), lineWidth: DS.BorderWidth.regular)
                                    .background(DS.Palette.surface.opacity(0.0001))
                            )
                        HStack(alignment: .center, spacing: 8) {
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    ForEach(1...5, id: \.self) { j in
                                        Circle().fill(j <= item.difficulty ? DS.Palette.primary.opacity(0.8) : DS.Palette.border.opacity(DS.Opacity.border))
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                if let tags = item.tags, !tags.isEmpty {
                                    Text(tags.joined(separator: ", "))
                                        .dsType(DS.Font.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            Button {
                                vm.startPractice(with: item, tag: item.tags?.first)
                            } label: { Label("練習", systemImage: "play.fill") }
                                .buttonStyle(DSSecondaryButtonCompact())
                        }
                        HintListSection(
                            hints: item.hints,
                            isExpanded: Binding(
                                get: { expanded.contains(item.id) },
                                set: { v in if v { expanded.insert(item.id) } else { expanded.remove(item.id) } }
                            )
                        )
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        .navigationTitle(bookName)
    }
}

