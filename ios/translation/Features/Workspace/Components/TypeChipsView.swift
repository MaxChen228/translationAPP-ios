import SwiftUI

struct TypeChipsView: View {
    var errors: [ErrorItem]
    @Binding var selection: ErrorType?
    @Environment(\.locale) private var locale

    private var counts: [(ErrorType, Int)] {
        let dict = Dictionary(grouping: errors, by: { $0.type }).mapValues { $0.count }
        return ErrorType.allCases.compactMap { t in
            guard let c = dict[t], c > 0 else { return nil }
            return (t, c)
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(label: LocalizedStringKey("chips.all"), count: errors.count, color: DS.Palette.neutral, selected: selection == nil) {
                    selection = nil
                }
                ForEach(counts, id: \.0) { t, c in
                    Chip(label: t.displayName, count: c, color: t.color, selected: selection == t) {
                        selection = (selection == t ? nil : t)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    struct Chip: View {
        var label: LocalizedStringKey
        var count: Int
        var color: Color
        var selected: Bool
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 6) {
                    Text(label)
                    Text("\(count)")
                        .dsType(DS.Font.caption)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(Capsule().fill(color.opacity(0.15)))
                }
                .dsType(DS.Font.body)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    Capsule().fill(selected ? color.opacity(0.15) : DS.Palette.surface)
                )
                .overlay(
                    Capsule().stroke(selected ? color.opacity(DS.Opacity.muted) : DS.Palette.border.opacity(DS.Opacity.border), lineWidth: selected ? 1.1 : 0.8)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
