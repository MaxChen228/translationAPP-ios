import SwiftUI

struct CloudBankPreviewView: View {
    let detail: CloudBookDetail

    @State private var expanded: Set<String> = []

    var body: some View {
        DSScrollContainer {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.md) {
                ForEach(detail.items.indices, id: \.self) { index in
                    if index > 0 {
                        DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(DS.Opacity.border))
                            .padding(.vertical, DS.Spacing.sm)
                    }
                    let item = detail.items[index]
                    BankItemCard(
                        item: item,
                        bookName: detail.name,
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
            .padding(.top, DS.Spacing.lg)
            .padding(.horizontal, DS.Spacing.lg)
        }
        .navigationTitle(detail.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
