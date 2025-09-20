import SwiftUI

// Generic reorder DropDelegate: call `move(dragged,toIndex)` when dragging enters overItem.
struct ShelfReorderDropDelegate<ID: Equatable>: DropDelegate {
    let overItemID: ID
    @Binding var draggingID: ID?
    let indexOf: (ID) -> Int?
    let move: (ID, Int) -> Void

    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != overItemID else { return }
        guard let from = indexOf(draggingID), let to = indexOf(overItemID) else { return }
        if from != to {
            move(draggingID, to > from ? to + 1 : to)
            Haptics.lightTick()
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        Haptics.success()
        return true
    }
}

// Clear drag state when dropping on background
struct ShelfClearDragStateDrop<ID>: DropDelegate {
    @Binding var draggingID: ID?
    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { draggingID = nil; return true }
}
