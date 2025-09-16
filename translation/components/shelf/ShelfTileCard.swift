import SwiftUI

struct ShelfTileCard: View {
    var title: String
    var subtitle: String? = nil
    var countText: String? = nil
    var iconSystemName: String? = nil
    var accentColor: Color = DS.Palette.primary
    var showChevron: Bool = true

    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: 10) {
                    if let icon = iconSystemName {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(accentColor.opacity(0.85))
                            .frame(width: 28)
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
            }
            .frame(minHeight: 104)
        }
    }
}

