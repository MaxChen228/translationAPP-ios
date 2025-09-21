import SwiftUI

struct ShelfTileCard: View {
    var title: String
    var subtitle: String? = nil
    var countText: String? = nil
    var iconSystemName: String? = nil
    var accentColor: Color = DS.Palette.primary
    var showChevron: Bool = true
    // Optional linear progress (0...1). When provided, renders a small progress bar at bottom.
    var progress: Double? = nil

    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: 10) {
                    if let icon = iconSystemName {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(accentColor.opacity(0.85))
                            .frame(width: DS.IconSize.cardIcon)
                    }
                    Text(title)
                        .dsType(DS.Font.serifBody)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                    if showChevron {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
                if subtitle != nil || countText != nil {
                    DSSeparator(color: DS.Palette.border.opacity(0.12))
                }
                HStack(spacing: 8) {
                    if let subtitle { Text(subtitle).dsType(DS.Font.caption).foregroundStyle(.secondary) }
                    if let countText { Text(countText).dsType(DS.Font.caption).foregroundStyle(.secondary) }
                    Spacer(minLength: 0)
                }

                if let p = progress {
                    // Thin linear progress bar
                    ProgressView(value: min(max(p, 0), 1))
                        .progressViewStyle(.linear)
                        .tint(accentColor)
                        .padding(.top, 2)
                }
            }
            .frame(minHeight: DS.CardSize.minHeightStandard)
        }
    }
}
