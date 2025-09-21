import SwiftUI

struct DSScoreBadge: View {
    let score: Int
    var style: BadgeStyle = .default

    enum BadgeStyle {
        case `default`
        case compact
        case large

        var fontSize: SwiftUI.Font {
            switch self {
            case .default: return DS.Font.labelSm
            case .compact: return DS.Font.caption
            case .large: return DS.Font.labelMd
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .default: return EdgeInsets(top: DS.Spacing.xs, leading: DS.Spacing.xs2, bottom: DS.Spacing.xs, trailing: DS.Spacing.xs2)
            case .compact: return EdgeInsets(top: 2, leading: DS.Spacing.xs, bottom: 2, trailing: DS.Spacing.xs)
            case .large: return EdgeInsets(top: DS.Spacing.xs, leading: DS.Spacing.sm, bottom: DS.Spacing.xs, trailing: DS.Spacing.sm)
            }
        }
    }

    private var scoreColor: Color {
        DS.Palette.scoreColor(for: Double(score))
    }

    var body: some View {
        Text("\(score)")
            .dsType(style.fontSize)
            .fontWeight(.semibold)
            .foregroundStyle(DS.Palette.onPrimary)
            .padding(style.padding)
            .background(
                Capsule()
                    .fill(scoreColor)
            )
            .overlay(
                Capsule()
                    .stroke(scoreColor.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.hairline)
            )
    }
}