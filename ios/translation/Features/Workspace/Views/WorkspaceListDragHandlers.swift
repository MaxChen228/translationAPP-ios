import SwiftUI

struct WorkspaceReorderDropDelegate: DropDelegate {
    let workspaceID: UUID
    unowned let coordinator: WorkspaceHomeCoordinator

    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func dropEntered(info: DropInfo) {
        coordinator.handleWorkspaceDropEntered(targetID: workspaceID)
    }

    func performDrop(info: DropInfo) -> Bool {
        coordinator.handleWorkspaceDrop()
    }
}

struct WorkspaceAddToEndDropDelegate: DropDelegate {
    unowned let coordinator: WorkspaceHomeCoordinator
    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }
    func dropEntered(info: DropInfo) { }
    func performDrop(info: DropInfo) -> Bool {
        coordinator.handleWorkspaceDropToEnd()
    }
}

struct WorkspaceClearDragDropDelegate: DropDelegate {
    unowned let coordinator: WorkspaceHomeCoordinator
    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        coordinator.clearWorkspaceDrag()
    }
}
