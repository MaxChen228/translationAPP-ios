import SwiftUI

struct ShelfGrid<Content: View>: View {
    var title: String? = nil
    var subtitle: String? = nil
    var columns: [GridItem]
    @ViewBuilder var content: () -> Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        columns: [GridItem] = [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.sm2)],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.columns = columns
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
            if title != nil || subtitle != nil {
                DSSectionHeader(title: title ?? "", subtitle: subtitle, accentUnderline: true)
            }
            LazyVGrid(columns: columns, spacing: DS.Spacing.sm2) {
                content()
            }
        }
    }
}

