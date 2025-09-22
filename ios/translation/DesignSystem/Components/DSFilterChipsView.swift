import SwiftUI

private func difficultyToRoman(_ difficulty: Int) -> String {
    switch difficulty {
    case 1: return "Ⅰ"
    case 2: return "Ⅱ"
    case 3: return "Ⅲ"
    case 4: return "Ⅳ"
    case 5: return "Ⅴ"
    default: return "Ⅰ"
    }
}

struct DSFilterChipsView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Chips will be added here by the parent view
            }
            .padding(.horizontal, 2)
        }
    }
}

struct DSFilterChip: View {
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
                Capsule().stroke(
                    selected ? color.opacity(DS.Opacity.strong) : DS.Palette.border.opacity(DS.Opacity.border),
                    lineWidth: selected ? DS.BorderWidth.thin : DS.BorderWidth.hairline
                )
            )
        }
        .buttonStyle(.plain)
        .dsAnimation(DS.AnimationToken.subtle, value: selected)
    }
}

// Difficulty-specific filter chip with star rating visualization
struct DSDifficultyFilterChip: View {
    var difficulty: Int
    var count: Int
    var selected: Bool
    var action: () -> Void

    private var difficultyColor: Color {
        switch difficulty {
        case 1: return DS.Palette.success
        case 2: return DS.Brand.scheme.cornhusk
        case 3: return DS.Brand.scheme.peachQuartz
        case 4: return DS.Palette.warning
        case 5: return DS.Palette.danger
        default: return DS.Palette.neutral
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(difficultyToRoman(difficulty))
                    .dsType(DS.Font.labelSm)
                    .foregroundStyle(difficultyColor)
                Text("\(count)")
                    .dsType(DS.Font.caption)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(Capsule().fill(difficultyColor.opacity(0.15)))
            }
            .dsType(DS.Font.body)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                Capsule().fill(selected ? difficultyColor.opacity(0.15) : DS.Palette.surface)
            )
            .overlay(
                Capsule().stroke(
                    selected ? difficultyColor.opacity(DS.Opacity.strong) : DS.Palette.border.opacity(DS.Opacity.border),
                    lineWidth: selected ? DS.BorderWidth.thin : DS.BorderWidth.hairline
                )
            )
        }
        .buttonStyle(.plain)
        .dsAnimation(DS.AnimationToken.subtle, value: selected)
    }
}

// Tag-specific filter chip
struct DSTagFilterChip: View {
    var tag: String
    var count: Int
    var selected: Bool
    var action: () -> Void

    var body: some View {
        DSFilterChip(
            label: LocalizedStringKey(tag),
            count: count,
            color: DS.Brand.scheme.provence,
            selected: selected,
            action: action
        )
    }
}