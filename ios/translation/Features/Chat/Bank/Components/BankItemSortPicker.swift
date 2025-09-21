import SwiftUI

enum BankItemSortOption: String, CaseIterable {
    case defaultOrder = "sort.default"
    case difficultyLowToHigh = "sort.difficulty.lowToHigh"
    case difficultyHighToLow = "sort.difficulty.highToLow"
    case completionIncomplete = "sort.completion.incomplete"
    case completionComplete = "sort.completion.complete"
    case tagsAlphabetical = "sort.tags.alphabetical"

    var displayName: LocalizedStringKey {
        LocalizedStringKey(rawValue)
    }

    var systemImageName: String {
        switch self {
        case .defaultOrder:
            return "list.number"
        case .difficultyLowToHigh:
            return "arrow.up"
        case .difficultyHighToLow:
            return "arrow.down"
        case .completionIncomplete:
            return "circle"
        case .completionComplete:
            return "checkmark.circle"
        case .tagsAlphabetical:
            return "textformat.abc"
        }
    }
}

struct BankItemSortPicker: View {
    @Binding var selectedSort: BankItemSortOption
    @Environment(\.locale) private var locale

    var body: some View {
        Menu {
            ForEach(BankItemSortOption.allCases, id: \.self) { option in
                Button {
                    selectedSort = option
                } label: {
                    HStack {
                        Image(systemName: option.systemImageName)
                        Text(option.displayName)
                        Spacer()
                        if selectedSort == option {
                            Image(systemName: "checkmark")
                                .foregroundStyle(DS.Palette.primary)
                        }
                    }
                }
            }
        } label: {
            DSQuickActionIconGlyph(
                systemName: "arrow.up.arrow.down",
                shape: .circle,
                style: .outline,
                size: 36
            )
        }
    }
}

extension BankItemSortPicker {
    static func sortItems(_ items: [BankItem], by option: BankItemSortOption, progressStore: LocalBankProgressStore, bookName: String) -> [BankItem] {
        switch option {
        case .defaultOrder:
            return items

        case .difficultyLowToHigh:
            return items.sorted { $0.difficulty < $1.difficulty }

        case .difficultyHighToLow:
            return items.sorted { $0.difficulty > $1.difficulty }

        case .completionIncomplete:
            return items.sorted { item1, item2 in
                let completed1 = progressStore.isCompleted(book: bookName, itemId: item1.id)
                let completed2 = progressStore.isCompleted(book: bookName, itemId: item2.id)
                if completed1 != completed2 {
                    return !completed1 // incomplete first
                }
                return false // maintain original order for same completion status
            }

        case .completionComplete:
            return items.sorted { item1, item2 in
                let completed1 = progressStore.isCompleted(book: bookName, itemId: item1.id)
                let completed2 = progressStore.isCompleted(book: bookName, itemId: item2.id)
                if completed1 != completed2 {
                    return completed1 // completed first
                }
                return false
            }

        case .tagsAlphabetical:
            return items.sorted { item1, item2 in
                let tag1 = item1.tags?.first ?? ""
                let tag2 = item2.tags?.first ?? ""
                return tag1.localizedCompare(tag2) == .orderedAscending
            }
        }
    }
}