import SwiftUI

// Flat card: background + hairline outline, no shadow.
struct DSOutlineCard<Content: View>: View {
    private let content: Content
    var padding: CGFloat = DS.Spacing.md
    var fill: Color? = nil

    init(padding: CGFloat = DS.Spacing.md, fill: Color? = nil, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.fill = fill
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            content
        }
        .padding(padding)
        .background((fill ?? DS.Palette.background), in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(DS.Palette.border.opacity(0.28), lineWidth: DS.Metrics.hairline)
        )
    }
}

