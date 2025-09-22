import SwiftUI

enum DSBadgeStyle {
    case fill(color: Color, opacity: Double = DS.Component.Badge.fillOpacity)
    case outline(color: Color, lineWidth: CGFloat = DS.BorderWidth.thin)
    case tinted(color: Color, opacity: Double = DS.Component.Badge.fillOpacity, strokeOpacity: Double = DS.Opacity.border)
}

struct DSBadge<Content: View, Leading: View, Trailing: View>: View {
    var style: DSBadgeStyle
    var paddingVertical: CGFloat
    var paddingHorizontal: CGFloat
    private let leading: () -> Leading
    private let content: () -> Content
    private let trailing: () -> Trailing

    init(
        style: DSBadgeStyle,
        paddingVertical: CGFloat = DS.Component.Badge.paddingVertical,
        paddingHorizontal: CGFloat = DS.Component.Badge.paddingHorizontal,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.style = style
        self.paddingVertical = paddingVertical
        self.paddingHorizontal = paddingHorizontal
        self.leading = leading
        self.content = content
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            if Leading.self != EmptyView.self {
                leading()
            }
            content()
            if Trailing.self != EmptyView.self {
                trailing()
            }
        }
        .padding(.vertical, paddingVertical)
        .padding(.horizontal, paddingHorizontal)
        .background(backgroundView)
        .overlay(borderView)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .fill(let color, let opacity):
            Capsule().fill(color.opacity(opacity))
        case .outline:
            Capsule().fill(Color.clear)
        case .tinted(let color, let opacity, _):
            Capsule().fill(color.opacity(opacity))
        }
    }

    @ViewBuilder
    private var borderView: some View {
        switch style {
        case .fill:
            EmptyView()
        case .outline(let color, let lineWidth):
            Capsule().stroke(color, lineWidth: lineWidth)
        case .tinted(let color, _, let strokeOpacity):
            Capsule().stroke(color.opacity(strokeOpacity), lineWidth: DS.BorderWidth.thin)
        }
    }
}

extension DSBadge where Leading == EmptyView, Trailing == EmptyView {
    init(
        style: DSBadgeStyle,
        paddingVertical: CGFloat = DS.Component.Badge.paddingVertical,
        paddingHorizontal: CGFloat = DS.Component.Badge.paddingHorizontal,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            style: style,
            paddingVertical: paddingVertical,
            paddingHorizontal: paddingHorizontal,
            leading: { EmptyView() },
            content: content,
            trailing: { EmptyView() }
        )
    }
}
