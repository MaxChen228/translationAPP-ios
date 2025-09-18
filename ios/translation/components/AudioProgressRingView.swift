import SwiftUI

struct AudioProgressRingView: View {
    var progress: Double // 0...1
    var size: CGFloat = 36
    var lineWidth: CGFloat = 3.5
    var trackWidth: CGFloat = 1

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(DS.Palette.border.opacity(0.25), lineWidth: trackWidth)
            // Progress arc with angular gradient
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(AngularGradient(
                    gradient: Gradient(colors: [
                        DS.Brand.scheme.provence,
                        DS.Brand.scheme.classicBlue
                    ]),
                    center: .center
                ), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: progress)

            // Waveform inside, clipped to circle
            // no inner waveform per latest requirement – keep minimal
        }
        .frame(width: size, height: size)
    }
}
