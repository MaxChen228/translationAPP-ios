import SwiftUI

// Unified, reusable state cards for empty and error states.

struct MessageStateCard: View {
    let iconSystemName: String
    let iconColor: Color
    let title: String
    let subtitle: String?

    var body: some View {
        DSCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: iconSystemName)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .dsType(DS.Font.body)
                        .foregroundStyle(.primary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct ErrorStateCard: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        MessageStateCard(
            iconSystemName: "exclamationmark.triangle.fill",
            iconColor: .yellow,
            title: title,
            subtitle: subtitle
        )
    }
}

struct EmptyStateCard: View {
    let title: String
    var subtitle: String? = nil
    var iconSystemName: String = "tray"
    var body: some View {
        MessageStateCard(
            iconSystemName: iconSystemName,
            iconColor: DS.Palette.border,
            title: title,
            subtitle: subtitle
        )
    }
}

