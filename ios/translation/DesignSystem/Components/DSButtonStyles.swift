import SwiftUI

// 統一的按鈕組件：合併主要/次要按鈕與其緊湊版本
struct DSButton: ButtonStyle {
    enum Style {
        case primary   // 主按鈕 (漸層背景)
        case secondary // 次要按鈕 (邊框樣式)
    }

    enum Size {
        case full    // 佔滿寬度
        case compact // 緊湊尺寸
    }

    let style: Style
    let size: Size

    init(style: Style, size: Size = .full) {
        self.style = style
        self.size = size
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dsType(typography.font, lineSpacing: typography.lineSpacing)
            .foregroundStyle(foregroundColor)
            .padding(.vertical, verticalPadding)
            .conditionalModifier(size == .full) { view in
                view.frame(maxWidth: .infinity)
            }
            .conditionalModifier(size == .compact) { view in
                view.padding(.horizontal, DS.Spacing.sm)
            }
            .background(backgroundView)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .dsAnimation(DS.AnimationToken.snappy, value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return DS.Palette.onPrimary
        case .secondary: return DS.Palette.primary
        }
    }

    private var verticalPadding: CGFloat {
        switch (style, size) {
        case (.primary, .full): return DS.Spacing.sm2
        case (.secondary, .full): return DS.Spacing.sm
        case (_, .compact): return DS.Spacing.xs
        }
    }

    private var typography: (font: SwiftUI.Font, lineSpacing: CGFloat) {
        switch size {
        case .full:
            return (DS.Font.bodyEmph, 4)
        case .compact:
            return (DS.Font.labelMd, 2)
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        let cornerRadius = DS.Radius.md
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        switch style {
        case .primary:
            shape.fill(DS.Palette.primaryGradient)
        case .secondary:
            shape.stroke(DS.Palette.primary.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.regular)
        }
    }
}


struct DSPrimaryCircleButton: ButtonStyle {
    var diameter: CGFloat = 32
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dsType(DS.Font.labelMd, lineSpacing: 2)
            .foregroundStyle(DS.Palette.onPrimary)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(DS.Palette.primaryGradient))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
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
            .dsAnimation(DS.AnimationToken.snappy, value: configuration.isPressed)
    }
}

// 日曆格子按鈕樣式：圓形按鈕，支援選中與按壓狀態
struct DSCalendarCellStyle: ButtonStyle {
    let isSelected: Bool
    let backgroundColor: Color
    let borderColor: Color?
    let borderWidth: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: DS.IconSize.calendarCell, height: DS.IconSize.calendarCell)
            .background(
                Circle()
                    .fill(backgroundColor)
                    .overlay(
                        Group {
                            if let borderColor, borderWidth > 0 {
                                Circle()
                                    .stroke(borderColor, lineWidth: borderWidth)
                            }
                        }
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .dsAnimation(DS.AnimationToken.subtle, value: configuration.isPressed)
            .dsAnimation(DS.AnimationToken.subtle, value: isSelected)
    }
}
