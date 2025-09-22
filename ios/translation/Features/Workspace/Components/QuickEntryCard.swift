import SwiftUI

struct QuickEntryCard<Subtitle: View>: View {
    var icon: String
    var title: LocalizedStringKey
    var accentColor: Color
    var minHeight: CGFloat
    private let subtitle: Subtitle

    init(
        icon: String,
        title: LocalizedStringKey,
        accentColor: Color,
        minHeight: CGFloat = DS.CardSize.minHeightStandard,
        @ViewBuilder subtitle: () -> Subtitle
    ) {
        self.icon = icon
        self.title = title
        self.accentColor = accentColor
        self.minHeight = minHeight
        self.subtitle = subtitle()
    }

    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSCardTitle(
                    icon: icon,
                    title: title,
                    accentColor: accentColor
                )
                DSSeparator(color: DS.Palette.border.opacity(DS.Opacity.fill))
                subtitle
            }
            .frame(minHeight: minHeight)
        }
    }
}
