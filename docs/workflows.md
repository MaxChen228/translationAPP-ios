# 功能流程索引

此文件將常見功能與對應檔案整理成查詢指南，避免為修改單一功能而翻遍整個專案。

## 1. 翻譯批改（/correct）

| 任務 | 主要檔案 | 說明 |
| ---- | -------- | ---- |
| 顯示輸入欄位、觸發批改 | `Features/Workspace/Views/ContentView.swift` | `Button` 內呼叫 `Task { await vm.runCorrection() }`，可在此插入額外驗證或事件追蹤。 |
| 工作區狀態管理 | `Features/Workspace/ViewModels/CorrectionViewModel.swift` | `runCorrection()` 建立 `AICorrectionResult`，同時更新高亮、通知 Banner；修改回傳結構時需同步調整這裡。 |
| 錯誤高亮及篩選 | `Features/Workspace/Utilities/Highlighter.swift`、`CorrectionViewModel.filtered*` | 若新增錯誤類型或匹配規則，需同時更新 `ErrorType` 與此檔。 |
| 與後端互動 | `Shared/Services/AIService.swift` | `AIServiceHTTP.correct(...)` 對應 `/correct`，處理 DTO→前端模型轉換。 |
| 儲存錯誤資料 | `Features/Saved/Stores/SavedErrorsStore.swift` | `ContentView` 的 `onSave` 呼叫 `SavedErrorsStore.add`。 | 

調整批改輸入/回應流程時，建議由 ViewModel 開始自底向上檢查 DTO → Store → UI，並在 `docs/patterns.md` 參考新增欄位的寫法。

## 2. 題庫與 Saved JSON

| 任務 | 主要檔案 | 說明 |
| ---- | -------- | ---- |
| 題庫列表/複習入口 | `Features/Bank/Views/BankBooksView.swift`、`Features/Bank/Stores/LocalBankStore.swift` | 管理本機題庫結構與 UI。新增欄位需更新 `BankItem`、`LocalBankStore`。 |
| 題庫練習流程 | `CorrectionViewModel.startLocalPractice` | 將題庫項目填入 Workspace 並重置狀態。 |
| Saved JSON 清單 | `Features/Saved/Views/SavedJSONListSheet.swift`、`Features/Saved/Stores/SavedErrorsStore.swift` | 提供儲存錯誤列表與匯出功能。 |
| 匯出為單字卡 | `DeckService.swift` | 透過 `/make_deck` 建立新 Deck，新增欄位時同步更新 DTO。 |

## 3. 單字卡與 TTS

| 任務 | 主要檔案 | 說明 |
| ---- | -------- | ---- |
| Deck 管理 | `Features/Flashcards/Stores/FlashcardDecksStore.swift`、`Features/Flashcards/Stores/DeckFoldersStore.swift`、`Features/Flashcards/Stores/DeckRootOrderStore.swift` | 控制 Deck 儲存、資料夾層次、排序。 |
| 單字卡 UI | `Features/Flashcards/Views/FlashcardDecksView.swift`、`Features/Flashcards/Views/DeckDetailView.swift` | 展示 Deck 與卡片細節。 |
| TTS 撥放邏輯 | `Shared/Services/SpeechEngine.swift`、`Shared/Services/InstantSpeaker.swift`、`Shared/Services/PlaybackBuilder.swift`、`Shared/Services/TTSSettings.swift` | 組合語音佇列、控制播放行為與設定；新增語音參數時須調整這些檔案。 |

## 4. 聊天與研究助理

| 任務 | 主要檔案 | 說明 |
| ---- | -------- | ---- |
| 聊天 UI 與狀態 | `Features/Chat/ViewModels/ChatViewModel.swift`、`Features/Chat/Views/ChatWorkspaceView.swift` | 管理訊息列表、`state`/`checklist`、研究結果展示，並依 `AppSettingsStore` 的模型設定觸發研究。 |
| HTTP 交握 | `Features/Chat/Services/ChatService.swift` | `ChatServiceHTTP` 會將圖片附件轉換為 base64、附上每個流程的模型設定，並對 500/422 錯誤做本地化轉換。 |
| 研究輸出模型 | `Features/Chat/Models/ChatModels.swift` | `ChatResearchResponse.items` 轉成 `ChatResearchItem(term/explanation/context/type)`；若後端回傳空陣列會拋錯提醒使用者補充資訊。 |

## 5. 通知與 Banner

- `DesignSystem/BannerCenter.swift` 處理全域 Banner 顯示與自動關閉，`App/translationApp.swift` 透過 Notification 觸發成功/失敗 Banner。
- 要新增新的 Banner 類型，可在對應事件發送 `NotificationCenter` 通知，並於 `translationApp` 加入新的 `onReceive`。

## 6. 設定與偏好

- `App/AppSettingsStore.swift`：儲存使用者的 LLM 模型、Banner 時間、語言。
- `Shared/Services/TTSSettings.swift`：管理 TTS 相關設定（語速、語言、間隔、變體填充）。
- `Features/Settings/Stores/RandomPracticeStore.swift`：單純的 `@AppStorage` 包裝，用於快速開關選項。

## 使用方式

1. 先在此文件查找欲調整的功能項目。
2. 按表格中的主要檔案順序閱讀，通常是 View → ViewModel → Service → Store。
3. 若需新增欄位或 API 互動，請同步更新 `docs/patterns.md` 列出的慣例。
