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
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(environment)
        }
    }
}
