import SwiftUI

struct BankListView: View {
    @ObservedObject var vm: CorrectionViewModel
    var tag: String? = nil
    var onPractice: (() -> Void)? = nil
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
                if let error { Text(error).foregroundStyle(.secondary) }
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 12) {
                        // 題目：加大字體並以細邊框凸顯
                        Text(item.zh)
                            .dsType(DS.Font.serifTitle, lineSpacing: 6, tracking: 0.1)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                    .stroke(DS.Palette.border.opacity(0.6), lineWidth: DS.BorderWidth.regular)
                                    .background(DS.Palette.surface.opacity(0.0001)) // keep hit testing sane
                            )
                        HStack(spacing: 8) {
                            // difficulty dots
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { i in
                                    Circle().fill(i <= item.difficulty ? DS.Palette.primary.opacity(0.8) : DS.Palette.border.opacity(0.35))
                                        .frame(width: 6, height: 6)
                                }
                            }
                            if let tags = item.tags, !tags.isEmpty {
                                Text(tags.joined(separator: ", "))
                                    .dsType(DS.Font.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        HStack {
                            Spacer()
                            Button {
                                vm.startPractice(with: item, tag: tag)
                                dismiss()
                                if let onPractice { onPractice() }
                            } label: {
                                Label("練習", systemImage: "play.fill")
                            }
                            .buttonStyle(DSSecondaryButtonCompact())
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
                        // 狀態區：以髮絲線與提示區塊分隔，右下角顯示已完成徽章
                        VStack(spacing: 6) {
                            DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(0.35))
                            HStack {
                                Spacer()
                                if item.completed == true {
                                    Label("已完成", systemImage: "checkmark.seal.fill")
                                        .labelStyle(.titleAndIcon)
                                        .dsType(DS.Font.caption)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(
                                            Capsule().fill(DS.Brand.scheme.peachQuartz.opacity(0.16))
                                        )
                                        .overlay(
                                            Capsule().stroke(DS.Brand.scheme.peachQuartz.opacity(0.5), lineWidth: DS.BorderWidth.thin)
                                        )
                                }
                            }
                        }
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
                    .background(Capsule().fill(chip.color.opacity(0.12)))
                    .overlay(Capsule().stroke(chip.color.opacity(0.35), lineWidth: DS.BorderWidth.thin))
            }
        }
    }
}
