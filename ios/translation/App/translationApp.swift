//
//  translationApp.swift
//  translation
//
//  Created by 陳亮宇 on 2025/9/14.
//

import SwiftUI
import UIKit
import BackgroundTasks

@main
struct TranslationApp: App {
    @StateObject private var savedStore = SavedErrorsStore()
    @StateObject private var decksStore = FlashcardDecksStore()
    @StateObject private var progressStore = FlashcardProgressStore()
    @StateObject private var deckFolders = DeckFoldersStore()
    @StateObject private var bankFolders = BankFoldersStore()
    @StateObject private var bankOrder = BankBooksOrderStore()
    @StateObject private var deckRootOrder = DeckRootOrderStore()
    @StateObject private var localBank = LocalBankStore()
    @StateObject private var localProgress = LocalBankProgressStore()
    @StateObject private var practiceRecords = PracticeRecordsStore()
    @StateObject private var quickActions = QuickActionsStore()
    @StateObject private var bannerCenter = BannerCenter()
    @StateObject private var router = RouterStore()
    @StateObject private var settings = AppSettingsStore()
    @StateObject private var randomSettings = RandomPracticeStore()
    @StateObject private var globalAudio = GlobalAudioSessionManager.shared
    init() {
        FontLoader.registerBundledFonts()
        AppLog.aiInfo("App launched")
        // Apply global navigation title fonts using serif family
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
        // Back/regular bar button items use serif as well
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
        if let url = AppConfig.backendURL {
            AppLog.uiInfo("BACKEND_URL=\(url.absoluteString)")
        } else {
            AppLog.uiError("BACKEND_URL missing")
        }
    }
    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                WorkspaceListView()
                    .environmentObject(router)
                BannerHost()
                    .environmentObject(bannerCenter)

                // 全局迷你播放器 - 顯示在底部
                VStack {
                    Spacer()
                    GlobalAudioMiniPlayerView()
                }
                .environmentObject(globalAudio)
            }
                .environmentObject(savedStore)
                .environmentObject(decksStore)
                .environmentObject(progressStore)
                .environmentObject(deckFolders)
                .environmentObject(bankFolders)
                .environmentObject(bankOrder)
                .environmentObject(deckRootOrder)
                .environmentObject(localBank)
                .environmentObject(localProgress)
                .environmentObject(practiceRecords)
                .environmentObject(quickActions)
                .environmentObject(bannerCenter)
                .environmentObject(settings)
                .environmentObject(randomSettings)
                // Inject locale for runtime language switch (zh-Hant / en)
                .environment(\.locale, Locale(identifier: settings.language == "zh" ? "zh-Hant" : "en"))
                .onAppear {
                    if AppConfig.backendURL == nil {
                        let localeID = settings.language == "zh" ? "zh-Hant" : "en"
                        let locale = Locale(identifier: localeID)
                        bannerCenter.show(
                            title: String(localized: "banner.backend.missing.title", locale: locale),
                            subtitle: String(localized: "banner.backend.missing.subtitle", locale: locale)
                        )
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .correctionCompleted)) { note in
                    let score = note.userInfo?[AppEventKeys.score] as? Int ?? 0
                    let errors = note.userInfo?[AppEventKeys.errors] as? Int ?? 0
                    let localeID = settings.language == "zh" ? "zh-Hant" : "en"
                    let locale = Locale(identifier: localeID)
                    let subtitle = "\(score) " + String(localized: "label.points", locale: locale) + " • \(errors) " + String(localized: "label.suggestions", locale: locale)
                    let targetWorkspaceID = (note.userInfo?[AppEventKeys.workspaceID] as? String).flatMap(UUID.init(uuidString:))
                    let title = String(localized: "banner.correctionDone.title", locale: locale)
                    let action = String(localized: "banner.correctionDone.action", locale: locale)
                    bannerCenter.show(title: title, subtitle: subtitle, actionTitle: targetWorkspaceID != nil ? action : nil) {
                        if let id = targetWorkspaceID { router.open(workspaceID: id) }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .correctionFailed)) { note in
                    let err = note.userInfo?[AppEventKeys.error] as? String
                    let localeID = settings.language == "zh" ? "zh-Hant" : "en"
                    let locale = Locale(identifier: localeID)
                    let title = String(localized: "banner.correctionFailed.title", locale: locale)
                    bannerCenter.show(title: title, subtitle: err, actionTitle: nil, action: nil)
                }
                .onReceive(NotificationCenter.default.publisher(for: .ttsError)) { note in
                    let err = note.userInfo?[AppEventKeys.error] as? String
                    let localeID = settings.language == "zh" ? "zh-Hant" : "en"
                    let locale = Locale(identifier: localeID)
                    let title = String(localized: "banner.tts.error.title", locale: locale)
                    bannerCenter.show(title: title, subtitle: err)
                }
                .onReceive(NotificationCenter.default.publisher(for: .practiceRecordSaved)) { _ in
                    let localeID = settings.language == "zh" ? "zh-Hant" : "en"
                    let locale = Locale(identifier: localeID)
                    let title = String(localized: "banner.practice.saved.title", locale: locale)
                    let subtitle = String(localized: "banner.practice.saved.subtitle", locale: locale)
                    bannerCenter.show(title: title, subtitle: subtitle)
                }
        }
    }
}
