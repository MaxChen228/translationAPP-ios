import SwiftUI

struct DSPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.white)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Palette.primaryGradient)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(DS.AnimationToken.snappy, value: configuration.isPressed)
    }
}

struct DSSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(DS.Palette.primary)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Palette.primary.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.regular)
        )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(DS.AnimationToken.snappy, value: configuration.isPressed)
    }
}

// 更精簡的次要按鈕：字體與內距更小，且不佔滿寬度
struct DSSecondaryButtonCompact: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundStyle(DS.Palette.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Palette.primary.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.regular)
        )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(DS.AnimationToken.snappy, value: configuration.isPressed)
    }
}

// 小型主按鈕：用於迷你播放器等場景，不佔滿寬度
struct DSPrimaryButtonCompact: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundStyle(Color.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Palette.primaryGradient)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct DSPrimaryCircleButton: ButtonStyle {
    var diameter: CGFloat = 32
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundStyle(Color.white)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(DS.Palette.primaryGradient))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

// Outline-only circular button (no fill), brand-colored border and icon.
struct DSOutlineCircleButton: ButtonStyle {
    var diameter: CGFloat = 28
    func makeBody(configuration: Configuration) -> some View {
        DSOutlineCircleButtonView(configuration: configuration, diameter: diameter)
    }

    private struct DSOutlineCircleButtonView: View {
        let configuration: Configuration
        var diameter: CGFloat
        @Environment(\.isEnabled) private var isEnabled
        var body: some View {
            let baseColor = DS.Palette.primary
            let fg = isEnabled ? baseColor : baseColor.opacity(0.35)
            configuration.label
                .font(.subheadline)
                .foregroundStyle(fg)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(Color.clear))
                .overlay(
                    Circle().stroke(fg.opacity(0.55), lineWidth: DS.BorderWidth.regular)
                )
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .opacity(configuration.isPressed ? 0.9 : 1)
                .contentShape(Circle())
        }
    }
}

// 卡片/連結的按壓反饋：輕微縮放並以細邊框高亮
struct DSCardLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(DS.Palette.primary.opacity(configuration.isPressed ? DS.Opacity.strong : 0), lineWidth: DS.BorderWidth.regular)
            )
            .animation(DS.AnimationToken.snappy, value: configuration.isPressed)
    }
}
