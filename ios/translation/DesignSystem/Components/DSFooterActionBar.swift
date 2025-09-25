import SwiftUI

struct DSFooterActionBar<Content: View>: View {
    var separatorColor: Color
    var topPadding: CGFloat
    private let content: () -> Content

    init(
        separatorColor: Color = DS.Brand.scheme.babyBlue.opacity(0.35),
        topPadding: CGFloat = DS.Spacing.sm,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.separatorColor = separatorColor
        self.topPadding = topPadding
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            DSSeparator(color: separatorColor)
            VStack(spacing: DS.Spacing.sm2) {
                content()
            }
            .padding(.top, topPadding)
        }
    }
}
