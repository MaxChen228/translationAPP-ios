import Foundation
import SwiftUI

struct Workspace: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
}

@MainActor
final class WorkspaceStore: ObservableObject {
    private let listKey = "workspaces.list"
    private let correctionRunner: CorrectionRunning

    @Published private(set) var workspaces: [Workspace] = [] {
        didSet { persistList() }
    }

    // Keep strong references so tasks continue even離開詳情頁
    private var viewModels: [UUID: CorrectionViewModel] = [:]

    // Store references for dependency injection
    weak var localBankStore: LocalBankStore?
    weak var localProgressStore: LocalBankProgressStore?
    weak var practiceRecordsStore: PracticeRecordsStore?

    init(correctionRunner: CorrectionRunning = CorrectionServiceFactory.makeDefault()) {
        self.correctionRunner = correctionRunner
        load()
        if workspaces.isEmpty {
            // 初次啟動預設 1 個
            _ = addWorkspace(name: "Workspace 1")
        }
    }

    func vm(for id: UUID) -> CorrectionViewModel {
        if let vm = viewModels[id] { return vm }
        let vm = CorrectionViewModel(correctionRunner: correctionRunner, workspaceID: id.uuidString)

        bindStores(to: vm)
        viewModels[id] = vm
        return vm
    }

    @discardableResult
    func addWorkspace(name: String? = nil) -> Workspace {
        let index = (workspaces.count + 1)
        let ws = Workspace(id: UUID(), name: name ?? "Workspace \(index)")
        workspaces.append(ws)
        // 準備 VM（將自動載入其持久化狀態）
        let vm = CorrectionViewModel(correctionRunner: correctionRunner, workspaceID: ws.id.uuidString)

        bindStores(to: vm)
        viewModels[ws.id] = vm
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

    func remove(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        workspaces.removeAll { workspace in
            if ids.contains(workspace.id) {
                purgeWorkspaceData(id: workspace.id)
                viewModels[workspace.id] = nil
                return true
            }
            return false
        }
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

    func moveWorkspaces(ids: [UUID], before targetID: UUID?) {
        let idSet = Set(ids)
        guard !idSet.isEmpty else { return }

        let moving = workspaces.filter { idSet.contains($0.id) }
        guard !moving.isEmpty else { return }

        workspaces.removeAll { idSet.contains($0.id) }

        let insertIndex: Int
        if let targetID, let idx = workspaces.firstIndex(where: { $0.id == targetID }) {
            insertIndex = idx
        } else {
            insertIndex = workspaces.count
        }

        let clamped = max(0, min(insertIndex, workspaces.count))
        workspaces.insert(contentsOf: moving, at: clamped)
    }

    func statusText(for id: UUID) -> String {
        let vm = vm(for: id)
        if vm.isLoading { return String(localized: "workspace.status.loading") }
        if vm.session.response != nil { return String(localized: "workspace.status.corrected") }
        if !(vm.session.inputZh.isEmpty && vm.session.inputEn.isEmpty) { return String(localized: "workspace.status.inProgress") }
        return String(localized: "workspace.status.empty")
    }

    // MARK: - Store binding
    private func bindStores(to vm: CorrectionViewModel) {
        if let localBank = localBankStore, let localProgress = localProgressStore {
            vm.bindLocalBankStores(localBank: localBank, progress: localProgress)
        }
        if let practiceRecords = practiceRecordsStore {
            vm.bindPracticeRecordsStore(practiceRecords)
        }
    }

    func rebindAllStores() {
        for vm in viewModels.values {
            bindStores(to: vm)
        }
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
        let persistence = DefaultsWorkspaceStatePersistence(workspaceID: id.uuidString)
        persistence.removeAll([
            .inputZh,
            .inputEn,
            .response,
            .practicedHints,
            .showPracticedHints
        ])
    }
}
