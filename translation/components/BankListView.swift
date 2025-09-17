import SwiftUI

struct BankListView: View {
    @ObservedObject var vm: CorrectionViewModel
    var tag: String? = nil
    // Optional override: when provided, caller controls where the practice item goes
    // (e.g., create a new workspace and route to it). Defaults to writing into `vm`.
    var onPractice: ((BankItem, String?) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var items: [BankItem] = []
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var expanded: Set<String> = []

    private let service = BankService()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if isLoading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }
                if let error { ErrorStateCard(title: error) }

                // 頂部進度摘要：顯示「已完成 / 題數」
                if !items.isEmpty {
                    let done = items.filter { $0.completed == true }.count
                    let total = items.count
                    DSOutlineCard {
                        HStack(alignment: .center) {
                            Text("進度")
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

                if !isLoading && error == nil && items.isEmpty {
                    EmptyStateCard(
                        title: "目前沒有題目",
                        subtitle: "換個題庫本或稍後再試。",
                        iconSystemName: "text.book.closed"
                    )
                }
                ForEach(items.indices, id: \.self) { i in
                    if i > 0 {
                        DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(DS.Opacity.border))
                            .padding(.vertical, DS.Spacing.sm)
                    }
                    let item = items[i]
                    VStack(alignment: .leading, spacing: 10) {
                        // 題目：加大字體並以細邊框凸顯
                        Text(item.zh)
                            .dsType(DS.Font.serifTitle, lineSpacing: 6, tracking: 0.1)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                    .stroke(DS.Palette.border.opacity(DS.Opacity.muted), lineWidth: DS.BorderWidth.regular)
                                    .background(DS.Palette.surface.opacity(0.0001)) // keep hit testing sane
                            )
                        HStack(alignment: .center, spacing: 8) {
                            // difficulty dots + tags（左側群組）
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    ForEach(1...5, id: \.self) { i in
                                        Circle().fill(i <= item.difficulty ? DS.Palette.primary.opacity(0.8) : DS.Palette.border.opacity(DS.Opacity.border))
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
                            // 右側狀態/操作
                            if item.completed == true {
                                CompletionBadge()
                            } else {
                                Button {
                                    if let onPractice { onPractice(item, tag) } else { vm.startPractice(with: item, tag: tag) }
                                    dismiss()
                                } label: {
                                    Label("練習", systemImage: "play.fill")
                                }
                                .buttonStyle(DSSecondaryButtonCompact())
                            }
                        }
                        HintListSection(
                            hints: item.hints,
                            isExpanded: Binding(
                                get: { expanded.contains(item.id) },
                                set: { v in
                                    if v { expanded.insert(item.id) } else { expanded.remove(item.id) }
                                }
                            )
                        )
                        // 取消底部狀態區，避免視覺雜訊；完成狀態已整合到右上的按鈕
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        .navigationTitle("題庫")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            items = try await service.fetchItems(limit: 100, difficulty: nil, tag: tag)
        } catch {
            self.error = (error as NSError).localizedDescription
        }
        isLoading = false
    }
}

private struct ChipModel: Identifiable { let id = UUID(); let text: String; let color: Color }

// 醒目的「已完成」徽章（綠底白字）
private struct CompletionBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
            Text("已完成")
        }
        .font(.subheadline)
        .foregroundStyle(DS.Palette.primary)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            Capsule().fill(Color.clear)
        )
        .overlay(
            Capsule().stroke(DS.Palette.primary.opacity(DS.Opacity.strong), lineWidth: DS.BorderWidth.regular)
        )
        .accessibilityLabel("已完成")
    }
}

private struct WrapChips: View {
    var chips: [ChipModel]
    var body: some View {
        let cols = [GridItem(.adaptive(minimum: 120), spacing: 8)]
        LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
            ForEach(chips) { chip in
                Text(chip.text)
                    .dsType(DS.Font.caption)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(chip.color.opacity(DS.Opacity.fill)))
                    .overlay(Capsule().stroke(chip.color.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.thin))
            }
        }
    }
}
