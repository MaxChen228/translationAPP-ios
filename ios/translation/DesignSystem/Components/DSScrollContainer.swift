import SwiftUI

struct DSScrollContainer<Content: View>: View {
    let content: Content
    let showsIndicators: Bool
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    init(
        showsIndicators: Bool = true,
        horizontalPadding: CGFloat = DS.Spacing.lg,
        verticalPadding: CGFloat = DS.Spacing.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.showsIndicators = showsIndicators
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }

    var body: some View {
        ScrollView(showsIndicators: showsIndicators) {
            content
                .padding(.horizontal, horizontalPadding)
                .padding(.top, verticalPadding)
                .padding(.bottom, verticalPadding)
        }
        .background(DS.Palette.background)
    }
}