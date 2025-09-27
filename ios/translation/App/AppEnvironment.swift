import SwiftUI
import Combine
import UIKit

@MainActor
final class AppEnvironment: ObservableObject {
    let savedStore = SavedErrorsStore()
    let decksStore = FlashcardDecksStore()
    let progressStore = FlashcardProgressStore()
    let deckFolders = DeckFoldersStore()
    let bankFolders = BankFoldersStore()
    let bankOrder = BankBooksOrderStore()
    let deckRootOrder = DeckRootOrderStore()
    let localBank = LocalBankStore()
    let localProgress = LocalBankProgressStore()
    let practiceRecordsRepository: PracticeRecordsRepositoryProtocol
    let practiceRecords: PracticeRecordsStore
    let quickActions = QuickActionsStore()
    let bannerCenter = BannerCenter()
    let router = RouterStore()
    let settings = AppSettingsStore()
    let randomSettings = RandomPracticeStore()
    let globalAudio = GlobalAudioSessionManager.shared
    let correctionService: CorrectionRunning
    let workspaceStore: WorkspaceStore
    let calendarMetrics = CalendarMetricsPreferencesStore()

    private var cancellables = Set<AnyCancellable>()

    init(
        correctionService: CorrectionRunning = CorrectionServiceFactory.makeDefault()
    ) {
        let practiceContext = AppEnvironment.makePracticeRecordsContext()
        let migrator = PracticeRecordsMigrator(backupDirectory: practiceContext.backupDirectory)
        migrator.migrateIfNeeded(repository: practiceContext.repository)

        self.practiceRecordsRepository = practiceContext.repository
        self.practiceRecords = PracticeRecordsStore(repository: practiceContext.repository)

        self.correctionService = correctionService
        self.workspaceStore = WorkspaceStore(correctionRunner: correctionService)
        FontLoader.registerBundledFonts()
        AppLog.aiInfo("App launched")
        configureNavigationAppearance()
        logBackendStatus()
        workspaceStore.localBankStore = localBank
        workspaceStore.localProgressStore = localProgress
        workspaceStore.practiceRecordsStore = practiceRecords
        workspaceStore.randomPracticeStore = randomSettings
        workspaceStore.settingsStore = settings
        workspaceStore.rebindAllStores()
        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var localeIdentifier: String {
        settings.language == "zh" ? "zh-Hant" : "en"
    }

    var currentLocale: Locale {
        Locale(identifier: localeIdentifier)
    }

    func presentBackendMissingBannerIfNeeded() {
        guard AppConfig.backendURL == nil else { return }
        let locale = currentLocale
        bannerCenter.show(
            title: String(localized: "banner.backend.missing.title", locale: locale),
            subtitle: String(localized: "banner.backend.missing.subtitle", locale: locale)
        )
    }

    func handleCorrectionCompleted(note: Notification) {
        let score = note.userInfo?[AppEventKeys.score] as? Int ?? 0
        let errors = note.userInfo?[AppEventKeys.errors] as? Int ?? 0
        let locale = currentLocale
        let subtitle = "\(score) " + String(localized: "label.points", locale: locale) +
            " • \(errors) " + String(localized: "label.suggestions", locale: locale)
        let targetWorkspaceID = (note.userInfo?[AppEventKeys.workspaceID] as? String).flatMap(UUID.init(uuidString:))
        let title = String(localized: "banner.correctionDone.title", locale: locale)
        let action = String(localized: "banner.correctionDone.action", locale: locale)
        bannerCenter.show(title: title, subtitle: subtitle, actionTitle: targetWorkspaceID != nil ? action : nil) { [weak self] in
            if let id = targetWorkspaceID { self?.router.open(workspaceID: id) }
        }
    }

    func handleCorrectionFailed(note: Notification) {
        let err = note.userInfo?[AppEventKeys.error] as? String
        let locale = currentLocale
        let title = String(localized: "banner.correctionFailed.title", locale: locale)
        bannerCenter.show(title: title, subtitle: err, actionTitle: nil, action: nil)
    }

    func handleTTSError(note: Notification) {
        let err = note.userInfo?[AppEventKeys.error] as? String
        let locale = currentLocale
        let title = String(localized: "banner.tts.error.title", locale: locale)
        bannerCenter.show(title: title, subtitle: err)
    }

    func handlePracticeSaved() {
        let locale = currentLocale
        let title = String(localized: "banner.practice.saved.title", locale: locale)
        let subtitle = String(localized: "banner.practice.saved.subtitle", locale: locale)
        bannerCenter.show(title: title, subtitle: subtitle)
    }

    private func configureNavigationAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.largeTitleTextAttributes = [
            .font: DS.DSUIFont.serifLargeTitle(),
            .foregroundColor: UIColor.label
        ]
        nav.titleTextAttributes = [
            .font: DS.DSUIFont.serifBodyLarge(),
            .foregroundColor: UIColor.label
        ]

        let btn = UIBarButtonItemAppearance(style: .plain)
        let btnAttrs: [NSAttributedString.Key: Any] = [
            .font: DS.DSUIFont.serifBody()
        ]
        btn.normal.titleTextAttributes = btnAttrs
        btn.highlighted.titleTextAttributes = btnAttrs
        btn.disabled.titleTextAttributes = btnAttrs
        btn.focused.titleTextAttributes = btnAttrs
        nav.backButtonAppearance = btn
        nav.buttonAppearance = btn
        nav.doneButtonAppearance = btn
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }

    private func logBackendStatus() {
        if let url = AppConfig.backendURL {
            AppLog.uiInfo("BACKEND_URL=\(url.absoluteString)")
        } else {
            AppLog.uiError("BACKEND_URL missing")
        }
    }

    private static func makePracticeRecordsContext() -> (repository: PracticeRecordsRepositoryProtocol, backupDirectory: URL) {
        let fileManager = FileManager.default
        let repository = PracticeRecordsFileSystem.makeRepository(fileManager: fileManager)
        let backupURL = PracticeRecordsFileSystem.backupDirectory(fileManager: fileManager)
        return (repository, backupURL)
    }

}

struct AppRootView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        ZStack(alignment: .top) {
            WorkspaceListView()
            BannerHost()

            VStack {
                Spacer()
                GlobalAudioMiniPlayerView()
            }
        }
        .applyAppEnvironment(env)
        .environment(\.locale, env.currentLocale)
        .onAppear {
            env.presentBackendMissingBannerIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .correctionCompleted)) { note in
            env.handleCorrectionCompleted(note: note)
        }
        .onReceive(NotificationCenter.default.publisher(for: .correctionFailed)) { note in
            env.handleCorrectionFailed(note: note)
        }
        .onReceive(NotificationCenter.default.publisher(for: .ttsError)) { note in
            env.handleTTSError(note: note)
        }
        .onReceive(NotificationCenter.default.publisher(for: .practiceRecordSaved)) { _ in
            env.handlePracticeSaved()
        }
    }
}

private extension View {
    func applyAppEnvironment(_ env: AppEnvironment) -> some View {
        self
            .environmentObject(env.savedStore)
            .environmentObject(env.decksStore)
            .environmentObject(env.progressStore)
            .environmentObject(env.deckFolders)
            .environmentObject(env.bankFolders)
            .environmentObject(env.bankOrder)
            .environmentObject(env.deckRootOrder)
            .environmentObject(env.localBank)
            .environmentObject(env.localProgress)
            .environmentObject(env.practiceRecords)
            .environmentObject(env.quickActions)
            .environmentObject(env.bannerCenter)
            .environmentObject(env.router)
            .environmentObject(env.settings)
            .environmentObject(env.randomSettings)
            .environmentObject(env.globalAudio)
            .environmentObject(env.workspaceStore)
            .environmentObject(env.calendarMetrics)
    }
}
