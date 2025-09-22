import Foundation
import SwiftUI
import OSLog

@MainActor
final class CorrectionViewModel: ObservableObject {
    let session: CorrectionSessionStore
    let practice: PracticeSessionCoordinator
    let merge: ErrorMergeController

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var focusEnSignal: Int = 0

    private let workspaceID: String

    init(
        correctionRunner: CorrectionRunning = CorrectionServiceFactory.makeDefault(),
        mergeService: ErrorMerging = ErrorMergeServiceFactory.makeDefault(),
        persistence: WorkspaceStatePersisting? = nil,
        workspaceID: String = "default"
    ) {
        self.workspaceID = workspaceID
        let persistence = persistence ?? DefaultsWorkspaceStatePersistence(workspaceID: workspaceID)
        let sessionStore = CorrectionSessionStore(
            persistence: persistence,
            correctionRunner: correctionRunner,
            workspaceID: workspaceID
        )
        self.session = sessionStore
        self.practice = PracticeSessionCoordinator(session: sessionStore)
        self.merge = ErrorMergeController(session: sessionStore, mergeService: mergeService, workspaceID: workspaceID)
        AppLog.aiInfo("CorrectionViewModel initialized (ws=\(workspaceID))")
    }

    // MARK: - Binding helpers

    func binding<Value>(_ keyPath: ReferenceWritableKeyPath<CorrectionSessionStore, Value>) -> Binding<Value> {
        Binding(
            get: { self.session[keyPath: keyPath] },
            set: { self.session[keyPath: keyPath] = $0 }
        )
    }

    // MARK: - Store binding

    func bindLocalBankStores(localBank: LocalBankStore, progress: LocalBankProgressStore) {
        practice.setLocalStores(localBank: localBank, progress: progress)
    }

    func bindPracticeRecordsStore(_ store: PracticeRecordsStore) {
        practice.setPracticeRecordsStore(store)
    }

    // MARK: - Focus helpers

    func requestFocusEn() {
        focusEnSignal &+= 1
    }

    // MARK: - Session lifecycle

    func reset() {
        session.resetSession()
        practice.resetPractice()
        merge.cancel()
    }

    func fillExample() {
        session.inputZh = String(localized: "content.sample.zh")
        session.inputEn = String(localized: "content.sample.en")
    }

    // MARK: - Correction workflow

    func runCorrection() async {
        let user = session.inputEn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty else {
            session.produceEmptyInputResponse()
            return
        }

        if session.inputZh.isEmpty {
            session.inputZh = String(localized: "content.sample.zh")
        }

        isLoading = true
        errorMessage = nil
        merge.cancel()
        do {
            let result = try await session.performCorrection(deviceId: DeviceID.current)
            NotificationCenter.default.post(name: .correctionCompleted, object: nil, userInfo: [
                AppEventKeys.workspaceID: workspaceID,
                AppEventKeys.score: result.response.score,
                AppEventKeys.errors: result.response.errors.count,
            ])
        } catch {
            let nsError = error as NSError
            errorMessage = nsError.localizedDescription
            AppLog.aiError("Correction failed: \(nsError.localizedDescription)")
            NotificationCenter.default.post(name: .correctionFailed, object: nil, userInfo: [
                AppEventKeys.workspaceID: workspaceID,
                AppEventKeys.error: nsError.localizedDescription
            ])
        }
        isLoading = false
    }

    // MARK: - Practice workflow

    func startLocalPractice(bookName: String, item: BankItem, tag: String? = nil) {
        practice.startLocalPractice(bookName: bookName, item: item, tag: tag)
        requestFocusEn()
    }

    func loadNextPractice() {
        do {
            try practice.loadNextPractice()
            requestFocusEn()
            errorMessage = nil
        } catch let err as PracticeSessionCoordinator.PracticeError {
            if let message = err.errorDescription {
                errorMessage = message
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func savePracticeRecord() {
        do {
            let record = try practice.savePracticeRecord(currentInput: session.inputEn, response: session.response)
            NotificationCenter.default.post(name: .practiceRecordSaved, object: nil, userInfo: [
                "score": record.score,
                "errors": record.errors.count,
            ])
        } catch PracticeSessionCoordinator.PracticeError.missingResponse {
            AppLog.aiError("Cannot save practice record: no response available")
        } catch PracticeSessionCoordinator.PracticeError.storeMissing {
            AppLog.aiError("Cannot save practice record: store not bound")
        } catch PracticeSessionCoordinator.PracticeError.notLocal {
            AppLog.aiError("Cannot save practice record: practice source not local")
        } catch PracticeSessionCoordinator.PracticeError.noneRemaining {
            AppLog.aiError("Cannot save practice record: no remaining practice item")
        } catch {
            AppLog.aiError("Cannot save practice record: \(error.localizedDescription)")
        }
    }

    // MARK: - Merge workflow passthrough

    func enterMergeMode(initialErrorID: UUID?) {
        merge.begin(initial: initialErrorID)
    }

    func toggleMergeSelection(for id: UUID) {
        merge.toggle(id)
    }

    func cancelMergeMode() {
        merge.cancel()
    }

    func performMergeIfNeeded() async {
        do {
            try await merge.mergeIfNeeded()
            errorMessage = nil
        } catch {
            let nsError = error as NSError
            errorMessage = nsError.localizedDescription
            AppLog.aiError("Merge errors failed: \(nsError.localizedDescription)")
        }
    }
}
