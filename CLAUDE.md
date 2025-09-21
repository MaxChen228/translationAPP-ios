# Translation iOS App - 翻譯批改應用

## 專案概述
SwiftUI iOS應用，提供中英翻譯批改、錯誤高亮、多工作區、題庫、單字卡複習功能。

## 核心架構原則
- 使用SwiftUI和iOS 18+ API
- Feature模組化架構：Workspace、Chat、Flashcards、Saved、Settings
- 統一DesignSystem元件系統
- 與translation-backend API整合

## 編碼規範
- Swift 6語言特性和現代API
- async/await concurrency模式
- 遵循Apple Human Interface Guidelines
- 不添加註解除非明確要求
- 使用SF Symbols作為圖標
- 優先使用existing patterns和元件

## 專案結構
- `ios/translation/App/`: App生命週期、全域設定
- `ios/translation/Features/`: 依領域拆分的功能模組
- `ios/translation/DesignSystem/`: 設計系統與共用UI元件
- `ios/translation/Shared/`: 跨模組共享的模型、服務、工具
- `ios/translation/Resources/`: 資源與在地化字串

## 測試與建置
- 建置命令: `xcodebuild -project ios/translation.xcodeproj -scheme translation -configuration Debug build`
- 測試命令: `xcodebuild -project ios/translation.xcodeproj -scheme translation -destination 'platform=iOS Simulator,name=iPhone 16' test`

## 檔案參考
@README.md
@docs/architecture.md
@AGENTS.md