import SwiftUI

struct ScoreBarView: View {
    var score: Int // 0...100

    private var progress: CGFloat { CGFloat(max(0, min(100, score))) / 100 }
    private var grade: String {
        switch score { case 90...: return "A"; case 80..<90: return "B"; case 70..<80: return "C"; case 60..<70: return "D"; default: return "E" }
    }

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.18))
                    Capsule()
                        .fill(DS.Palette.scoreGradient)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 10)

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(score)")
                    .font(DS.Font.serifTitle)
            }
            .frame(minWidth: 40)
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("分數 \(score) 分")
    }
}
