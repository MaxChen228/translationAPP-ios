import SwiftUI

struct CloudCourseBookPreviewView: View {
    let courseTitle: String
    let book: CloudCourseBook

    @State private var expanded: Set<String> = []

    var body: some View {
        DSScrollContainer {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if let summary = book.summary, !summary.isEmpty {
                    DSCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text(courseTitle)
                                .dsType(DS.Font.caption)
                                .foregroundStyle(.secondary)
                            Text(summary)
                                .dsType(DS.Font.body)
                                .foregroundStyle(.primary)
                        }
                    }
                }

                LazyVStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(book.items.indices, id: \.self) { index in
                        if index > 0 {
                            DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(DS.Opacity.border))
                                .padding(.vertical, DS.Spacing.sm)
                        }
                        let item = book.items[index]
                        BankItemCard(
                            item: item,
                            bookName: book.title,
                            isExpanded: Binding(
                                get: { expanded.contains(item.id) },
                                set: { newValue in
                                    if newValue {
                                        expanded.insert(item.id)
                                    } else {
                                        expanded.remove(item.id)
                                    }
                                }
                            )
                        )
                    }
                }
            }
            .padding(.top, DS.Spacing.lg)
            .padding(.horizontal, DS.Spacing.lg)
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
