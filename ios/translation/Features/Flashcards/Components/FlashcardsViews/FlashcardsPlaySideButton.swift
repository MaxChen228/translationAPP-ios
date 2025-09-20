import SwiftUI

struct FlashcardsPlaySideButton: View {
    enum Style { case filled, outline }

    var style: Style = .filled
    var diameter: CGFloat = 28
    var action: () -> Void

    var body: some View {
        DSQuickActionIconButton(
            systemName: "speaker.wave.2.fill",
            labelKey: "tts.play",
            action: action,
            shape: .circle,
            style: style == .filled ? .filled : .outline,
            size: diameter
        )
        .padding(6)
    }
}
