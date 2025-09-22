import SwiftUI

struct DSStatItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(DS.Palette.primary)

            Text(value)
                .dsType(DS.Font.labelMd)
                .fontWeight(.semibold)

            Text(label)
                .dsType(DS.Font.caption)
                .foregroundStyle(DS.Palette.subdued)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}