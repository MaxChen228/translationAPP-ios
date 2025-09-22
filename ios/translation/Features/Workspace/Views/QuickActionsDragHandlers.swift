import SwiftUI

struct QuickActionsReorderDropDelegate: DropDelegate {
    let item: QuickActionItem
    let coordinator: QuickActionsCoordinator

    func validateDrop(info: DropInfo) -> Bool { coordinator.editController.isEditing }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func dropEntered(info: DropInfo) {
        guard coordinator.editController.isEditing,
              let draggingID = coordinator.editController.draggingID,
              draggingID != item.id else { return }
        coordinator.move(draggingID: draggingID, above: item.id)
        Haptics.lightTick()
    }

    func performDrop(info: DropInfo) -> Bool {
        guard coordinator.editController.isEditing else { return false }
        coordinator.endDragging()
        Haptics.success()
        return true
    }
}

struct QuickActionsAppendDropDelegate: DropDelegate {
    let coordinator: QuickActionsCoordinator

    func validateDrop(info: DropInfo) -> Bool { coordinator.editController.isEditing }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        guard coordinator.editController.isEditing,
              let draggingID = coordinator.editController.draggingID else { return false }
        coordinator.moveToEnd(draggingID: draggingID)
        coordinator.endDragging()
        Haptics.success()
        return true
    }
}

struct QuickActionsClearDragDropDelegate: DropDelegate {
    let coordinator: QuickActionsCoordinator
    func validateDrop(info: DropInfo) -> Bool { coordinator.editController.isEditing }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        coordinator.endDragging()
        return true
    }
}
