import SwiftUI

struct FlashcardsTopBar: View {
    let width: CGFloat
    let index: Int
    let total: Int
    let onClose: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                DSQuickActionIconButton(systemName: "xmark", labelKey: "action.cancel", action: onClose, style: .outline)
                Spacer()
                Text("\(min(max(1, index + 1), max(1, total))) / \(max(1, total))")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                DSQuickActionIconButton(systemName: "gearshape", labelKey: "nav.settings", action: onOpenSettings, style: .outline)
            }

            let progress = total <= 0 ? 0.0 : Double(index + 1) / Double(max(1, total))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(DS.Palette.border.opacity(0.25))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(DS.Palette.primary)
                    .frame(width: max(0, (width - DS.Spacing.lg * 2) * progress), height: 4)
            }
        }
    }
}
