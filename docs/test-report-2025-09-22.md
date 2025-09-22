# 測試紀錄（2025-09-22）

- 指令：`cd ios && xcodebuild -project translation.xcodeproj -scheme translation -destination 'platform=iOS Simulator,name=iPhone 16' -enableCodeCoverage YES test`
- 結果：所有單元測試與 UI 測試通過。
- 產生的結果檔：`translationTestResult.xcresult`
- 覆蓋率摘要（`xcrun xccov view --report translationTestResult.xcresult`）：
  - 目標 `translation.app`：**10.94%**（2967/27110）
  - 目標 `translationTests.xctest`：**100%**（12/12）
  - 目標 `translationUITests.xctest`：**100%**（45/45）

新增測試：
- `ios/translationTests/PracticeRecordsStoreTests.swift`
- `ios/translationTests/CalendarViewModelTests.swift`

調整測試：
- `ios/translationTests/FlashcardsViewModelTests.swift`
- `ios/translationTests/ChatViewModelTests.swift`
- `ios/translationTests/WorkspaceStoreTests.swift`

後續建議：可依覆蓋率報告優先補強 SwiftUI View 與 Service 邏輯測試。
