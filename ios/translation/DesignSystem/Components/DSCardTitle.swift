import SwiftUI

struct DSCardTitle: View {
    let icon: String?
    let title: LocalizedStringKey?
    let titleText: String?
    let accentColor: Color
    let showChevron: Bool

    init(
        icon: String? = nil,
        title: LocalizedStringKey,
        accentColor: Color = DS.Palette.primary,
        showChevron: Bool = true
    ) {
        self.icon = icon
        self.title = title
        self.titleText = nil
        self.accentColor = accentColor
        self.showChevron = showChevron
    }

    init(
        icon: String? = nil,
        titleText: String,
        accentColor: Color = DS.Palette.primary,
        showChevron: Bool = true
    ) {
        self.icon = icon
        self.title = nil
        self.titleText = titleText
        self.accentColor = accentColor
        self.showChevron = showChevron
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm2) {
            if let icon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(accentColor.opacity(0.85))
                    .frame(width: DS.IconSize.cardIcon)
            }
            Group {
                if let title {
                    Text(title)
                } else if let titleText {
                    Text(titleText)
                } else {
                    EmptyView()
                }
            }
            .dsType(DS.Font.serifBody)
            .fontWeight(.semibold)
            .lineLimit(1)

            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
        }
    }
}