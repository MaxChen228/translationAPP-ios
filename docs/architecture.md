# 架構導覽

本文件提供 SwiftUI 前端專案的高層架構，協助快速定位程式碼並理解資料流。

## 目錄結構

- `ios/translation/App/translationApp.swift`：App 進入點，註冊字型、建置 UINavigationBar 樣式，初始化所有 EnvironmentObject，並監聽批改/語音錯誤通知。
- `ios/translation/Features/`：依領域拆分的模組（Workspace、Bank、Flashcards、Saved、Chat、Settings、Calendar）；每個模組底下再細分 Views / Stores / Components / Utilities。
- `ios/translation/DesignSystem/`：視覺樣式與共用 UI 元件，如 `DesignSystem.swift` 與 `Components/DS*.swift`。
- `ios/translation/Shared/`：跨模組共享的模型、服務、工具與通用 View。
- `ios/translation/Resources/`：Assets、字型、Locale 字串等資源。
- `ios/translationTests/`、`ios/translationUITests/`：單元與 UI 測試入口。

## App 啟動與環境

1. `App/translationApp.swift` 建立主要 Store 與服務（SavedErrorsStore、FlashcardDecksStore、AppSettingsStore 等），並透過 `environmentObject` 注入整個 View tree。
2. `AppConfig`（位於 `Shared/Services/AIService.swift`）統一解析 `BACKEND_URL` 與各 API 端點。執行時會先讀取 `ProcessInfo.environment`，再回退至 `Info.plist` 中的 `BACKEND_URL`。
3. UI 使用自定義 Design System（`DesignSystem/DesignSystem.swift` 與 `DesignSystem/Components/DS*.swift`）套用 spacing、色票、動畫 token。

## 狀態管理與持久化

- **WorkspaceStore** (`Features/Workspace/Stores/WorkspaceStore.swift`)：管理 Workspace 清單，內含記憶化的 `CorrectionViewModel` 實例。Workspace 名稱與排序持久化在 UserDefaults。
- **CorrectionViewModel** (`Features/Workspace/ViewModels/CorrectionViewModel.swift`)：每個 Workspace 的核心狀態（中文/英文輸入、批改結果、錯誤高亮、題庫練習資訊）。會以 `workspace.<id>.` 前綴將輸入與結果儲存在 UserDefaults。現已整合練習記錄功能，自動追蹤練習開始時間與儲存完成記錄。
- **PracticeRecordsStore** (`Features/Saved/Stores/PracticeRecordsStore.swift`)：**新增**練習記錄管理系統，儲存練習時間、分數、題目等詳細資訊，為日曆功能提供資料支援。
- **CalendarViewModel** (`Features/Calendar/ViewModels/CalendarViewModel.swift`)：**新增**日曆狀態管理，處理月份導覽、練習統計計算、與 PracticeRecordsStore 的資料綁定。
- **SavedErrorsStore**、**FlashcardDecksStore**、**LocalBankStore**、**LocalBankProgressStore** 等 store 均以 UserDefaults 持久化 JSON，提供本機資料（分佈在 `Features/Saved/Stores`、`Features/Flashcards/Stores`、`Features/Bank/Stores`）。
- **AppSettingsStore** (`App/AppSettingsStore.swift`) 透過 `@Published` 與 UserDefaults 維持使用者設定（Banner 時間、LLM 模型、語系）。
- **RandomPracticeStore** (`Features/Settings/Stores/RandomPracticeStore.swift`) 以 `@AppStorage` 簡化布林設定。

## 後端服務抽象

- **批改**：`Shared/Services/AIService.swift` 定義 `AIService` protocol 與 `AIServiceHTTP` 實作，負責呼叫 `/correct`，處理 `ErrorDTO` 回應並建立高亮範圍。若 `BACKEND_URL` 未設定，改用 `UnavailableAIService` 丟出提示。
- **題庫與卡片**：`Shared/Services/CloudLibraryService.swift` 取得 `/cloud/books`、`/cloud/decks`；`Shared/Services/DeckService.swift` 封裝 `/make_deck`。兩者均會在缺少 `BACKEND_URL` 時直接 `fatalError` 或回傳錯誤，提醒需先設定環境。
- **聊天**：`Features/Chat/Services/ChatService.swift` 實作 `/chat/respond` 與 `/chat/research`，並將 LLM 回傳轉換為 `ChatTurnResponse`（含 `state`/`checklist`）及 `ChatResearchItem`（term/explanation/context/type），並在傳送時自動將圖片附件編碼為 base64 以配合後端的 inline data。

所有 HTTP service 都採用 `URLSession` + Codable DTO，並在傳送請求前自動加入使用者選擇的 LLM 模型（`settings.geminiModel`）。

## UI 組成與導覽

- **WorkspaceListView** (`Features/Workspace/Views/WorkspaceListView.swift`)
  - 使用 `NavigationStack` 管理 Workspace 頁面導覽，提供拖曳排序、重新命名與新增 Workspace 操作。
  - 透過 `RouterStore` 接收通知開啟指定 Workspace。

- **ContentView** (`Features/Workspace/Views/ContentView.swift`)
  - 主批改畫面。顯示中文提示、英文輸入、批改結果卡片。
  - 呼叫 `CorrectionViewModel.runCorrection()` 觸發網路請求。
  - 切換卡片模式、儲存錯誤至 Saved JSON、載入下一個本機題庫項目。

- **BankBooksView / FlashcardsView 等**：分別提供題庫瀏覽、儲存錯誤 / 單字卡列表、TTS 撥放介面。

- **CalendarView** (`Features/Calendar/Views/CalendarView.swift`)：**新增**練習日曆主要介面，包含月曆網格、日期選擇、詳細統計卡片與導覽控制。

- **NestedTagFilterView** (`Features/Chat/Bank/Views/NestedTagFilterView.swift`)：**新增**階層式標籤篩選器，將 63 個標籤組織為 5 大類別，支援展開/收合與統計顯示。

- **Design System 元件**：`DesignSystem/Components/DS*` 定義 Button、Card、色彩與動畫 Token，確保視覺一致。`DSButton` 取代舊有主要/次要按鈕家族、`DSCardTitle` 統一卡片抬頭排版，並搭配新增的 spacing/border token 與 `DSCalendarCell`、`DSCalendarGrid` 支援日曆介面。
- **PracticeRecordsListView** (`Features/Saved/Views/PracticeRecordsListView.swift`)
  - 以 `DSOutlineCard` 呈現練習清單、統計資訊與批改摘要，支援錯誤數徽章、題庫來源標籤與批次清除對話框。

## 語音與播放架構

- `Shared/Services/SpeechEngine.swift`：集中 AVSpeechSynthesizer 控制，處理播放佇列、暫停、跳過與音量偵測。
- `Shared/Services/InstantSpeaker.swift`：提供「單句播放」能力，會暫停 `SpeechEngine` 再於緩衝期間恢復。
- `Shared/Services/PlaybackBuilder.swift`：依 TTS 設定（讀順序、語速、變體填入）產生完整播放佇列。
- `Shared/Services/TTSSettings.swift`：定義 `TTSSettings` 與 `TTSSettingsStore`，以 `@AppStorage` 持久化語音設定。

## 測試與工具

- `translationTests/translationTests.swift`：示範使用 Swift Testing 驗證解碼邏輯。
- `translationUITests/translationUITests.swift`：XCTest UI 測試樣板，可擴充自動化場景。

## 變更依賴與注意事項

- 背景批改／聊天流程高度倚賴後端 DTO 結構。任何 API 變更請同步調整 `AIServiceHTTP.ErrorDTO` 與聊天相關 DTO（`ChatTurnResponse`、`ChatResearchItem` 等），並更新此文件。
- 如需新增長期持久化資料，優先考慮建立獨立 Store class 以保持 `CorrectionViewModel` 簡潔。
- 新增視圖時建議放入對應的 `Features/<Module>/Views` / `Components` 子資料夾，並於 `docs/workflows.md` 補充對應關聯。
- **練習記錄系統**：新增的 `PracticeRecordsStore` 與 `CalendarViewModel` 緊密整合，修改練習記錄結構時需同步更新日曆統計邏輯。
- **標籤系統**：`TagRegistry` 維護 63 個統一標籤的分類，後端若新增標籤需同步更新此註冊表以確保篩選功能正常運作。
