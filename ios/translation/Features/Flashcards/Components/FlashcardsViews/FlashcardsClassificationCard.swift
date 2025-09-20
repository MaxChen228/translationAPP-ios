import SwiftUI

struct FlashcardsClassificationCard: View {
    var label: LocalizedStringKey
    var color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(color, lineWidth: 4)
            Text(label)
                .font(.title).bold()
                .foregroundStyle(color)
        }
    }
}
