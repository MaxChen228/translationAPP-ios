import Foundation
import SwiftUI

struct Workspace: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
}

@MainActor
final class WorkspaceStore: ObservableObject {
    private let listKey = "workspaces.list"

    @Published private(set) var workspaces: [Workspace] = [] {
        didSet { persistList() }
    }

    // Keep strong references so tasks continue even離開詳情頁
    private var viewModels: [UUID: CorrectionViewModel] = [:]

    init() {
        load()
        if workspaces.isEmpty {
            // 初次啟動預設 1 個
            _ = addWorkspace(name: "Workspace 1")
        }
    }

    func vm(for id: UUID, service: AIService = AIServiceFactory.makeDefault()) -> CorrectionViewModel {
        if let vm = viewModels[id] { return vm }
        let vm = CorrectionViewModel(service: service, workspaceID: id.uuidString)
        viewModels[id] = vm
        return vm
    }

    @discardableResult
    func addWorkspace(name: String? = nil) -> Workspace {
        let index = (workspaces.count + 1)
        let ws = Workspace(id: UUID(), name: name ?? "Workspace \(index)")
        workspaces.append(ws)
        // 準備 VM（將自動載入其持久化狀態）
        viewModels[ws.id] = CorrectionViewModel(service: AIServiceFactory.makeDefault(), workspaceID: ws.id.uuidString)
        return ws
    }

    func rename(_ id: UUID, to newName: String) {
        guard let i = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[i].name = newName
    }

    func remove(_ id: UUID) {
        workspaces.removeAll { $0.id == id }
        // 清空該 workspace 的持久化資料
        purgeWorkspaceData(id: id)
        // 釋放 VM
        viewModels[id] = nil
    }

    // MARK: - Reorder
    func index(of id: UUID) -> Int? {
        workspaces.firstIndex(where: { $0.id == id })
    }

    func moveWorkspace(id: UUID, to newIndex: Int) {
        guard let from = index(of: id) else { return }
        var to = newIndex
        let item = workspaces.remove(at: from)
        // 調整目標索引（若從前面移到後面，移除後陣列縮短）
        if from < to { to -= 1 }
        to = max(0, min(to, workspaces.count))
        workspaces.insert(item, at: to)
    }

    func moveWorkspace(_ dragged: UUID, before target: UUID) {
        guard let to = index(of: target) else { return }
        moveWorkspace(id: dragged, to: to)
    }

    func statusText(for id: UUID) -> String {
        let vm = vm(for: id)
        if vm.isLoading { return String(localized: "workspace.status.loading") }
        if vm.response != nil { return String(localized: "workspace.status.corrected") }
        if !(vm.inputZh.isEmpty && vm.inputEn.isEmpty) { return String(localized: "workspace.status.inProgress") }
        return String(localized: "workspace.status.empty")
    }

    // MARK: - Persistence (list only; VM 狀態由 VM 自行持久化)
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: listKey) else { return }
        if let list = try? JSONDecoder().decode([Workspace].self, from: data) {
            self.workspaces = list
            // 準備各 VM（lazy）。不主動建立，等用到再建。
        }
    }

    private func persistList() {
        if let data = try? JSONEncoder().encode(workspaces) {
            UserDefaults.standard.set(data, forKey: listKey)
        }
    }

    private func purgeWorkspaceData(id: UUID) {
        let prefix = "workspace.\(id.uuidString)."
        let keys = ["inputZh", "inputEn", "response", "practicedHints", "showPracticedHints"]
        let ud = UserDefaults.standard
        for key in keys { ud.removeObject(forKey: prefix + key) }
    }
}
