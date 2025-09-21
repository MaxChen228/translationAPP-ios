import SwiftUI

struct FlashcardsTopBar: View {
    let width: CGFloat
    let index: Int
    let total: Int
    let sessionRightCount: Int
    let sessionWrongCount: Int
    let onClose: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack {
                DSQuickActionIconButton(
                    systemName: "xmark",
                    labelKey: "action.cancel",
                    action: onClose,
                    style: .outline,
                    size: 36
                )

                Spacer()

                Text("\(min(max(1, index + 1), max(1, total))) / \(max(1, total))")
                    .dsType(DS.Font.section)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                DSQuickActionIconButton(
                    systemName: "gearshape",
                    labelKey: "nav.settings",
                    action: onOpenSettings,
                    style: .outline,
                    size: 36
                )
            }

            // 簡潔的進度條
            let progress = total <= 0 ? 0.0 : Double(index + 1) / Double(max(1, total))
            let progressWidth = max(0, (width - DS.Spacing.lg * 2) * progress)

            HStack {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(DS.Palette.border.opacity(0.3))
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(DS.Palette.primary)
                        .frame(width: progressWidth, height: 3)
                        .dsAnimation(DS.AnimationToken.subtle, value: progress)
                }

                Spacer()

                // 計數徽章移到右側
                HStack(spacing: DS.Spacing.xs) {
                    SideCountBadge(count: sessionRightCount, color: DS.Palette.success, filled: false)
                    SideCountBadge(count: sessionWrongCount, color: DS.Palette.warning, filled: false)
                }
                .dsAnimation(DS.AnimationToken.subtle, value: sessionRightCount)
                .dsAnimation(DS.AnimationToken.subtle, value: sessionWrongCount)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
