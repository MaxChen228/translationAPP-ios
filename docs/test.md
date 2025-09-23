# 測試覆蓋狀態表（更新：2025-09-23）

| 模組 / 領域 | 主要測試檔案 | 最近驗證指令 | 當前狀態 | 覆蓋重點 | 仍待補強 |
| --- | --- | --- | --- | --- | --- |
| Workspace / Correction | `ios/translationTests/CorrectionViewModelTests.swift` | `xcodebuild -project ios/translation.xcodeproj -scheme translation -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:translationTests/CorrectionViewModelTests` | 穩定 | 覆蓋 `CorrectionSessionStore` 持久化、`PracticeSessionCoordinator` 題庫輪替與 `ErrorMergeController` 協調路徑，以及 ViewModel reset/錯誤處理 | 仍待補齊 UI Gesture（Pinch Merge）自動化與多 Workspace 交錯情境 |
| Saved / Practice Records | `ios/translationTests/PracticeRecordsStoreTests.swift`<br>`ios/translationTests/CalendarViewModelTests.swift` | `xcodebuild -project ios/translation.xcodeproj -scheme translation -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:translationTests/PracticeRecordsStoreTests` | 穩定 | 練習紀錄 CRUD、統計、分組、reload、錯誤容忍與月曆串接均有檢驗；主執行緒依賴已加註 `@MainActor` | Calendar 轉月時的快取邏輯與 UI 整合仍待補 |
| Saved / Error Stash | `ios/translationTests/SavedErrorsStoreTests.swift` | `xcodebuild -project ios/translation.xcodeproj -scheme translation -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:translationTests/SavedErrorsStoreTests` | 新增 | 覆蓋 correction / research 儲存、stash 移動、清除、損壞資料復原等核心行為 | 與 `SavedJSONListSheet` 的互動流程尚未自動化；缺乏 Deck 匯出整合測試 |
| Chat / Flashcards | `ios/translationTests/ChatManagerTests.swift`<br>`ios/translationTests/ChatSessionTests.swift`<br>`ios/translationTests/ChatViewModelTests.swift`<br>`ios/translationTests/FlashcardsViewModelTests.swift` | `xcodebuild -project ios/translation.xcodeproj -scheme translation -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:translationTests/ChatSessionTests -only-testing:translationTests/ChatManagerTests -only-testing:translationTests/ChatViewModelTests -only-testing:translationTests/FlashcardsViewModelTests` | 穩定（全以本地 mock 執行） | 驗證聊天狀態轉換、背景任務協調、卡片增刪與排序 | 待補語音/即時播放服務、Flashcards 進階情境 |

## 覆蓋率摘要

- 最近一次量測（2025-09-22，含 `-enableCodeCoverage YES`)：
  - `translation.app` 行數覆蓋率 **10.94%**（2967/27110）
  - `translationTests.xctest`、`translationUITests.xctest` 自身 100%
- 2025-09-23 新增 `CorrectionViewModelTests`、`SavedErrorsStoreTests` 後尚未重新計算整體覆蓋率；需視需求使用相同指令重跑。

## 後續建議

1. 重構完成後補齊 `CorrectionViewModel.runCorrection` 路徑，並收集對應覆蓋率。
2. 聊天模組現採注入式 mock，若需跑整包測試請先執行 `scripts/run_ui_tests.sh` 確保模擬器乾淨，或於 CI 中以 `-skip-testing:translationUITests` 排除 UI 測試。
3. 針對 Saved Flow 建立 UI 級測試（或 Snapshot）以驗證 `SavedJSONListSheet` 與 Deck 匯出整合。
4. 定期以 `-enableCodeCoverage YES` 更新覆蓋率紀錄，維護本表。 
