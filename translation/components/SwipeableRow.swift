import SwiftUI

struct SwipeableRow<Content: View>: View {
    var allowLeft: Bool
    var allowRight: Bool
    var onTriggerLeft: () -> Void
    var onTriggerRight: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var offsetX: CGFloat = 0
    private let threshold: CGFloat = 80
    private let maxOffset: CGFloat = 140

    var body: some View {
        content()
            .offset(x: offsetX)
            .gesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .onChanged { value in
                        var t = value.translation.width
                        if t > 0 { // rightwards
                            if allowRight { offsetX = min(t, maxOffset) } else { offsetX = 0 }
                        } else { // leftwards
                            if allowLeft { offsetX = max(t, -maxOffset) } else { offsetX = 0 }
                        }
                    }
                    .onEnded { _ in
                        if offsetX > threshold, allowRight {
                            withAnimation(DS.AnimationToken.snappy) { offsetX = maxOffset }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                onTriggerRight()
                                withAnimation(DS.AnimationToken.subtle) { offsetX = 0 }
                            }
                        } else if offsetX < -threshold, allowLeft {
                            withAnimation(DS.AnimationToken.snappy) { offsetX = -maxOffset }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                onTriggerLeft()
                                withAnimation(DS.AnimationToken.subtle) { offsetX = 0 }
                            }
                        } else {
                            withAnimation(DS.AnimationToken.subtle) { offsetX = 0 }
                        }
                    }
            )
            .zIndex(offsetX == 0 ? 0 : 2)
    }
}

