import SwiftUI

struct SwipeableRow<Content: View>: View {
    var allowLeft: Bool
    var allowRight: Bool
    var onTriggerLeft: () -> Void
    var onTriggerRight: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var offsetX: CGFloat = 0
    private let threshold: CGFloat = 72
    private let maxOffset: CGFloat = 180

    var body: some View {
        content()
            .offset(x: offsetX)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .onChanged { value in
                        let t = value.translation.width
                        if t > 0 { // rightwards
                            if allowRight { offsetX = min(t, maxOffset) } else { offsetX = 0 }
                        } else { // leftwards
                            if allowLeft { offsetX = max(t, -maxOffset) } else { offsetX = 0 }
                        }
                    }
                    .onEnded { _ in
                        if offsetX > threshold, allowRight {
                            DSMotion.run(DS.AnimationToken.tossOut) { offsetX = maxOffset }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                onTriggerRight()
                                DSMotion.run(DS.AnimationToken.bouncy) { offsetX = 0 }
                            }
                        } else if offsetX < -threshold, allowLeft {
                            DSMotion.run(DS.AnimationToken.tossOut) { offsetX = -maxOffset }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                onTriggerLeft()
                                DSMotion.run(DS.AnimationToken.bouncy) { offsetX = 0 }
                            }
                        } else {
                            DSMotion.run(DS.AnimationToken.bouncy) { offsetX = 0 }
                        }
                    }
            )
            .zIndex(offsetX == 0 ? 0 : 2)
    }
}
