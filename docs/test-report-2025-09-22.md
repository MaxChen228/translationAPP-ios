# 測試覆蓋狀態表（更新：2025-09-23）

| 模組 / 領域 | 主要測試檔案 | 最近驗證指令 | 當前狀態 | 覆蓋重點 | 仍待補強 |
| --- | --- | --- | --- | --- | --- |
| Workspace / Correction | `ios/translationTests/CorrectionViewModelTests.swift` | `xcodebuild -project ios/translation.xcodeproj -scheme translation -destination 'platform=iOS Simulator,name=iPhone 16' test` | 穩定 | 覆蓋初始化還原、reset、題庫切換、提示篩選、`savePracticeRecord()` 等邏輯 | `runCorrection` 非同步流程仍待重構後補測；需搭配假後端驗證通知與錯誤處理 |
| Saved / Practice Records | `ios/translationTests/PracticeRecordsStoreTests.swift`<br>`ios/translationTests/CalendarViewModelTests.swift` | `xcodebuild -project ios/translation.xcodeproj -scheme translation -destination 'platform=iOS Simulator,name=iPhone 16' test` | 穩定 | 練習紀錄 CRUD、統計、分組與月曆串接均有檢驗；主執行緒依賴已加註 `@MainActor` | 需補 `PracticeRecordsStore` 持久化錯誤容錯、Calendar 轉月時的快取邏輯 |
| Saved / Error Stash | `ios/translationTests/SavedErrorsStoreTests.swift` | `xcodebuild -project ios/translation.xcodeproj -scheme translation -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:translationTests/SavedErrorsStoreTests` | 新增 | 覆蓋 correction / research 儲存、stash 移動、清除、損壞資料復原等核心行為 | 與 `SavedJSONListSheet` 的互動流程尚未自動化；缺乏 Deck 匯出整合測試 |
| Chat / Flashcards | `ios/translationTests/ChatViewModelTests.swift`<br>`ios/translationTests/FlashcardsViewModelTests.swift` | （延用既有測試，未重新執行） | 穩定 | 驗證聊天狀態轉換、卡片增刪與排序 | 待補語音/即時播放服務、Flashcards 進階情境 |

## 覆蓋率摘要

- 最近一次量測（2025-09-22，含 `-enableCodeCoverage YES`)：
  - `translation.app` 行數覆蓋率 **10.94%**（2967/27110）
  - `translationTests.xctest`、`translationUITests.xctest` 自身 100%
- 2025-09-23 新增 `CorrectionViewModelTests`、`SavedErrorsStoreTests` 後尚未重新計算整體覆蓋率；需視需求使用相同指令重跑。

## 後續建議

1. 重構完成後補齊 `CorrectionViewModel.runCorrection` 路徑，並收集對應覆蓋率。
2. 針對 Saved Flow 建立 UI 級測試（或 Snapshot）以驗證 `SavedJSONListSheet` 與 Deck 匯出整合。
3. 定期以 `-enableCodeCoverage YES` 更新覆蓋率紀錄，維護本表。 
