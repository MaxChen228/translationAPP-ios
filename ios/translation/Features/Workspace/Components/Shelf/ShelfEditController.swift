import SwiftUI

@MainActor
final class ShelfEditController<ID: Hashable>: ObservableObject {
    @Published var isEditing = false
    @Published var draggingID: ID? = nil
    @Published var selectedIDs: Set<ID> = []

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
        selectedIDs.removeAll()
    }

    func beginDragging(_ id: ID) {
        draggingID = id
    }

    func endDragging() {
        draggingID = nil
    }

    func toggleSelection(_ id: ID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func isSelected(_ id: ID) -> Bool {
        selectedIDs.contains(id)
    }

    func setSelection(_ ids: Set<ID>) {
        selectedIDs = ids
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }
}

struct ShelfWiggle<Content: View>: View {
    var isActive: Bool
    var content: Content
    private let amplitude: CGFloat = 0.8
    private let rotation: Double = 1.5
    private let speed: Double = 12.0

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
