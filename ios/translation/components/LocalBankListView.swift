import SwiftUI

struct LocalBankListView: View {
    @ObservedObject var vm: CorrectionViewModel
    let bookName: String
    // Optional override: when provided, caller controls where the practice item goes
    var onPractice: ((BankItem, String?) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var localProgress: LocalBankProgressStore
    @State private var expanded: Set<String> = []
    @Environment(\.locale) private var locale

    var body: some View {
        let items = localBank.items(in: bookName)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // 頂部進度摘要：顯示「已完成 / 題數」
                if !items.isEmpty {
                    let done = items.filter { localProgress.isCompleted(book: bookName, itemId: $0.id) }.count
                    let total = items.count
                    DSOutlineCard {
                        HStack(alignment: .center) {
                            Text(String(localized: "label.progress", locale: locale))
                                .dsType(DS.Font.caption)
                                .foregroundStyle(.secondary)
                            ProgressView(value: Double(done), total: Double(max(total, 1)))
                                .tint(DS.Palette.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 8)
                            Text("\(done) / \(total)")
                                .dsType(DS.Font.caption)
                        }
                        .padding(.vertical, 2)
                    }
                }
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
                            if localProgress.isCompleted(book: bookName, itemId: item.id) {
                                CompletionBadge()
                            } else {
                                Button {
                                    if let onPractice {
                                        onPractice(item, item.tags?.first)
                                        // 關閉本清單頁，與遠端列表行為一致（外層 handler 還會再關閉上一層頁面）
                                        dismiss()
                                    } else {
                                        vm.bindLocalBankStores(localBank: localBank, progress: localProgress)
                                        vm.startLocalPractice(bookName: bookName, item: item, tag: item.tags?.first)
                                        dismiss()
                                    }
                                } label: { Label("練習", systemImage: "play.fill") }
                                    .buttonStyle(DSSecondaryButtonCompact())
                            }
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

// 重用遠端清單的完成徽章樣式
private struct CompletionBadge: View {
    @Environment(\.locale) private var locale
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
            Text(String(localized: "label.completed", locale: locale))
        }
        .font(.subheadline)
        .foregroundStyle(DS.Palette.primary)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Capsule().fill(Color.clear))
        .overlay(Capsule().stroke(DS.Palette.primary.opacity(DS.Opacity.strong), lineWidth: DS.BorderWidth.regular))
        .accessibilityLabel(Text("label.completed"))
    }
}
