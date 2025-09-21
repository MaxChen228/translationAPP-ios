import SwiftUI

struct ScoreRingView: View {
    var score: Int // 0...100

    @Environment(\.locale) private var locale

    var body: some View {
        let progress = min(max(Double(score)/100.0, 0.0), 1.0)
        ZStack {
            Circle()
                .stroke(DS.Palette.track, lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(DS.Palette.scoreAngular, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.title).bold()
                Text("label.points")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: DS.IconSize.scoreRing, height: DS.IconSize.scoreRing)
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "a11y.scoreLabel", locale: locale), score))
    }
}
