import SwiftUI

struct CompletionBadge: View {
    enum Style {
        case outline(showsChevron: Bool, accent: Color)
        case filled(accent: Color)
    }

    var style: Style = .outline(showsChevron: false, accent: DS.Palette.primary)
    @Environment(\.locale) private var locale

    var body: some View {
        let configuration = configuredStyle

        HStack(spacing: DS.Spacing.xs2) {
            Image(systemName: "checkmark.seal.fill")
            Text(String(localized: "label.completed", locale: locale))
            if configuration.showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: DS.IconSize.chevronSm, weight: .semibold))
            }
        }
        .font(.subheadline)
        .foregroundStyle(configuration.accent)
        .padding(.vertical, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.sm)
        .background(Capsule().fill(configuration.background))
        .overlay {
            if configuration.isOutlined {
                Capsule()
                    .stroke(configuration.accent.opacity(DS.Opacity.strong), lineWidth: DS.BorderWidth.regular)
            }
        }
        .accessibilityLabel(Text("label.completed"))
    }

    private var configuredStyle: (accent: Color, background: Color, showsChevron: Bool, isOutlined: Bool) {
        switch style {
        case let .outline(showsChevron, accent):
            return (accent, Color.clear, showsChevron, true)
        case let .filled(accent):
            return (accent, accent.opacity(0.1), false, false)
        }
    }
}
