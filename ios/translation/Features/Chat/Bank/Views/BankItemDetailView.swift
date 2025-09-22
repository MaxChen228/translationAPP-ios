import SwiftUI

struct BankItemDetailView: View {
    let item: BankItem
    let bookName: String
    @ObservedObject var vm: CorrectionViewModel
    var onPractice: ((String, BankItem, String?) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var localProgress: LocalBankProgressStore
    @Environment(\.locale) private var locale
    @State private var expanded: Set<String> = []

    private var isCompleted: Bool {
        localProgress.isCompleted(book: bookName, itemId: item.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // Book and difficulty info
                DSOutlineCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            Text("書本")
                                .dsType(DS.Font.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(bookName)
                                .dsType(DS.Font.body)
                        }

                        HStack {
                            Text("難度")
                                .dsType(DS.Font.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(BankItemDifficulty.romanNumeral(for: item.difficulty))
                                .dsType(DS.Font.labelSm)
                                .foregroundStyle(BankItemDifficulty.tint(for: item.difficulty))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(BankItemDifficulty.tint(for: item.difficulty).opacity(0.1))
                                )
                        }

                        if isCompleted {
                            HStack {
                                Text("狀態")
                                    .dsType(DS.Font.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                CompletionBadge(style: .filled(accent: DS.Palette.success))
                            }
                        }
                    }
                }

                // Chinese text
                DSCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("中文題目")
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                        Text(item.zh)
                            .dsType(DS.Font.serifBody)
                            .foregroundStyle(.primary)
                    }
                }

                // Tags if available
                if let tags = item.tags, !tags.isEmpty {
                    DSCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text("標籤")
                                .dsType(DS.Font.caption)
                                .foregroundStyle(.secondary)
                            Text(tags.joined(separator: ", "))
                                .dsType(DS.Font.body)
                                .foregroundStyle(.primary)
                        }
                    }
                }

                // Hints if available
                if !item.hints.isEmpty {
                    DSCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text("提示 (\(item.hints.count))")
                                .dsType(DS.Font.caption)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                ForEach(item.hints, id: \.id) { hint in
                                    HStack(alignment: .top, spacing: 8) {
                                        Circle()
                                            .fill(hint.category.color)
                                            .frame(width: 8, height: 8)
                                            .padding(.top, 4)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(hint.category.rawValue)
                                                .dsType(DS.Font.caption)
                                                .foregroundStyle(.secondary)
                                            Text(hint.text)
                                                .dsType(DS.Font.body)
                                                .foregroundStyle(.primary)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }

                // Practice button
                if !isCompleted {
                    Button {
                        handlePractice()
                    } label: {
                        Label {
                            Text(String(localized: "action.practice", locale: locale))
                        } icon: {
                            Image(systemName: "play.fill")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DSButton(style: .primary, size: .full))
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        .navigationTitle(item.zh)
        .navigationBarTitleDisplayMode(.large)
    }

    private func handlePractice() {
        if let external = onPractice {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                external(bookName, item, item.tags?.first)
            }
        } else {
            vm.bindLocalBankStores(localBank: localBank, progress: localProgress)
            vm.startLocalPractice(bookName: bookName, item: item, tag: item.tags?.first)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { dismiss() }
        }
    }
}
