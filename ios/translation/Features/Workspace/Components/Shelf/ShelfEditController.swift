import SwiftUI

@MainActor
final class ShelfEditController<ID: Hashable>: ObservableObject {
    @Published var isEditing = false
    @Published var draggingID: ID? = nil

    func enterEditMode() {
        if !isEditing {
            isEditing = true
        }
    }

    func exitEditMode() {
        if isEditing {
            isEditing = false
        }
        draggingID = nil
    }

    func beginDragging(_ id: ID) {
        draggingID = id
    }

    func endDragging() {
        draggingID = nil
    }
}

struct ShelfWiggle<Content: View>: View {
    var isActive: Bool
    var content: Content
    private let amplitude: CGFloat = 1.4
    private let rotation: Double = 2.2
    private let speed: Double = 7.0

    init(isActive: Bool, @ViewBuilder content: () -> Content) {
        self.isActive = isActive
        self.content = content()
    }

    var body: some View {
        if isActive {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate * speed
                let angle = sin(time) * rotation
                let shift = cos(time) * amplitude
                content
                    .rotationEffect(.degrees(angle))
                    .offset(x: shift)
            }
        } else {
            content
        }
    }
}

extension View {
    func shelfWiggle(isActive: Bool) -> some View {
        ShelfWiggle(isActive: isActive) { self }
    }
}
