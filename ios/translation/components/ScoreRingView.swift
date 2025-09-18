import SwiftUI

struct ScoreRingView: View {
    var score: Int // 0...100

    var body: some View {
        let progress = min(max(Double(score)/100.0, 0.0), 1.0)
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AngularGradient(gradient: Gradient(colors: [.green, .yellow, .orange, .red]), center: .center), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.title).bold()
                Text("分")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 96, height: 96)
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("分數 \(score) 分")
    }
}

