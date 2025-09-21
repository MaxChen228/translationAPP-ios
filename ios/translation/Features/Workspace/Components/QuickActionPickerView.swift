import SwiftUI

struct QuickActionPickerView: View {
    @Binding var isPresented: Bool
    var onSelect: (QuickActionType) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(QuickActionType.allCases, id: \.self) { type in
                    Button {
                        onSelect(type)
                        isPresented = false
                    } label: {
                        QuickActionPickerRow(type: type)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "quick.addEntry", comment: ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { isPresented = false }
                }
            }
        }
    }
}

private struct QuickActionPickerRow: View {
    let type: QuickActionType

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            DSQuickActionIconGlyph(systemName: type.iconName, shape: .roundedRect, style: .tinted, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(type.titleKey)
                    .dsType(DS.Font.bodyEmph)
                if let subtitle = type.subtitleKey {
                    Text(subtitle)
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, DS.Spacing.sm)
    }
}
