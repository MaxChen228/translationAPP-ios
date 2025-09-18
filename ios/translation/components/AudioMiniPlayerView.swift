import SwiftUI

struct AudioMiniPlayerView: View {
    var title: String
    var index: Int
    var total: Int
    var isPlaying: Bool
    var isPaused: Bool
    var progress: Double = 0
    var level: Double = 0
    var onPrev: () -> Void
    var onToggle: () -> Void
    var onNext: () -> Void
    var onStop: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Combined ring + play/pause circle button
            ZStack {
                AudioProgressRingView(progress: progress, size: 40)
                Button(action: onToggle) {
                    Image(systemName: (isPlaying && !isPaused) ? "pause.fill" : "play.fill")
                }
                .buttonStyle(DSPrimaryCircleButton(diameter: 30))
            }

            Button(action: onPrev) {
                Image(systemName: "backward.fill")
            }
            .buttonStyle(DSSecondaryButtonCompact())

            Button(action: onNext) {
                Image(systemName: "forward.fill")
            }
            .buttonStyle(DSSecondaryButtonCompact())

            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(title)
                    .dsType(DS.Font.section)
                Text("\(index)/\(total)")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: onStop) {
                Image(systemName: "xmark")
            }
            .buttonStyle(DSSecondaryButtonCompact())
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(.ultraThinMaterial)
        .dsTopHairline(color: DS.Palette.border.opacity(0.35))
    }
}
