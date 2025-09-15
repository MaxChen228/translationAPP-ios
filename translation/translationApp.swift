//
//  translationApp.swift
//  translation
//
//  Created by 陳亮宇 on 2025/9/14.
//

import SwiftUI
import UIKit

@main
struct TranslationApp: App {
    @StateObject private var savedStore = SavedErrorsStore()
    @StateObject private var decksStore = FlashcardDecksStore()
    @StateObject private var progressStore = FlashcardProgressStore()
    @StateObject private var bannerCenter = BannerCenter()
    @StateObject private var router = RouterStore()
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
        if let url = AppConfig.bankBaseURL {
            AppLog.uiInfo("BANK_BASE_URL=\(url.absoluteString)")
        } else {
            AppLog.uiError("BANK_BASE_URL missing")
        }
    }
    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                WorkspaceListView()
                    .environmentObject(router)
                BannerHost()
                    .environmentObject(bannerCenter)
                    .ignoresSafeArea(edges: .top)
            }
                .environmentObject(savedStore)
                .environmentObject(decksStore)
                .environmentObject(progressStore)
                .environmentObject(bannerCenter)
                .onReceive(NotificationCenter.default.publisher(for: .correctionCompleted)) { note in
                    let wsIDStr = note.userInfo?[AppEventKeys.workspaceID] as? String ?? ""
                    let score = note.userInfo?[AppEventKeys.score] as? Int ?? 0
                    let errors = note.userInfo?[AppEventKeys.errors] as? Int ?? 0
                    let subtitle = "\(score) 分 • \(errors) 個建議"
                    var targetUUID: UUID? = UUID(uuidString: wsIDStr)
                    bannerCenter.show(title: "批改完成", subtitle: subtitle, actionTitle: targetUUID != nil ? "查看" : nil) {
                        if let id = targetUUID { router.open(workspaceID: id) }
                    }
                }
        }
    }
}
