import Foundation

@MainActor
final class ErrorMergeController: ObservableObject {
    @Published private(set) var isMergeMode: Bool = false
    @Published private(set) var selection: [UUID] = []
    @Published private(set) var isMerging: Bool = false
    @Published private(set) var mergedHighlightID: UUID? = nil

    private let session: CorrectionSessionStore
    private let mergeService: ErrorMerging
    private let workspaceID: String
    private var clearMergedTask: Task<Void, Never>? = nil

    init(
        session: CorrectionSessionStore,
        mergeService: ErrorMerging,
        workspaceID: String
    ) {
        self.session = session
        self.mergeService = mergeService
        self.workspaceID = workspaceID
    }

    func begin(initial: UUID?) {
        if !isMergeMode {
            isMergeMode = true
            selection = []
        }
        if let id = initial {
            selection = [id]
            session.selectedErrorID = id
        }
    }

    func toggle(_ id: UUID) {
        guard isMergeMode, !isMerging else { return }
        if let index = selection.firstIndex(of: id) {
            selection.remove(at: index)
        } else {
            guard selection.count < 2 else { return }
            selection.append(id)
            session.selectedErrorID = id
        }
    }

    func cancel() {
        isMergeMode = false
        selection = []
        isMerging = false
    }

    func mergeIfNeeded() async throws {
        guard isMergeMode, selection.count == 2 else { return }
        guard let response = session.response else { return }
        let ids = selection
        let errors = response.errors.filter { ids.contains($0.id) }
        guard errors.count == 2 else { return }

        isMerging = true
        defer { isMerging = false }

        let merged = try await mergeService.merge(
            zh: session.inputZh,
            en: session.inputEn,
            corrected: response.corrected,
            errors: errors,
            rationale: mergeRationale(for: errors)
        )

        var updated = response.errors.filter { !ids.contains($0.id) }
        let insertionIndex = response.errors.firstIndex { $0.id == ids.first } ?? updated.count
        updated.insert(merged, at: min(insertionIndex, updated.count))

        session.updateErrors(updated, selectedID: merged.id)
        mergedHighlightID = merged.id
        scheduleMergedReset()
        cancel()
        NotificationCenter.default.post(name: .errorsMerged, object: nil, userInfo: [
            "workspaceID": workspaceID,
            "mergedErrorID": merged.id
        ])
    }

    private func mergeRationale(for errors: [ErrorItem]) -> String {
        let spans = errors.map { $0.span }.joined(separator: " + ")
        return "User pinched errors to merge into a memorable phrase: \(spans)."
    }

    private func scheduleMergedReset() {
        clearMergedTask?.cancel()
        clearMergedTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run {
                self?.mergedHighlightID = nil
            }
        }
    }
}
