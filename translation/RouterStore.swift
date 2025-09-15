import Foundation

@MainActor
final class RouterStore: ObservableObject {
    @Published var openWorkspaceID: UUID? = nil
    func open(workspaceID: UUID) { openWorkspaceID = workspaceID }
}

