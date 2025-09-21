# 開發模式與實作慣例

本文件彙整常用的開發技巧與注意事項，協助快速調整現有功能或新增模組。

## 檔案與命名

- 依功能分檔：資料層（Store/Service）與 UI（View）分離，避免巨型檔案。
- 新增 View 置於 `Features/<Module>/Views` 或子目錄（例如 `Features/Flashcards/Views/`），同時為共享元件放入 `Shared/` 或 `DesignSystem/`。
- 類別/結構採 UpperCamelCase，檔名與類別一致；支援型別（DTO/設定）放在同一檔案。
- 繼續沿用 `DS*` 前綴表示 Design System 元件，便於搜尋與維護。

## 與後端整合

1. 先在 `Shared/Services/AIService.swift`、`Features/Chat/Services/ChatService.swift` 或 `Shared/Services/DeckService.swift` 建立新的 DTO。
2. 維持 Codable 結構，並在 request body 中填入可選欄位時先過濾 `nil`/空字串，降低流量。
3. 若後端回傳欄位需分享給多個流程，優先放在共享 DTO（例如 `AIServiceHTTP.ErrorDTO`）並提供對應轉換方法。
4. 設定 `BACKEND_URL` 後，使用 `URLSession.shared` 即可；除非需要特殊 header，否則不另外建立 session。
5. 測試：可使用 `translation-backend/scripts/smoke_test.py` 或 `correct-tests/scripts/run.py` 驗證 API 兼容性。

## 狀態與持久化

- 短期 UI 狀態留在 ViewModel (`@Published`)，跨畫面或需持久化的資料建立獨立 Store。
- 持久化採用 UserDefaults 時，請統一前綴（例如 `workspace.<id>.`、`settings.*`），並在 Store 內封裝 `load/persist`。
- 大型資料（例如題庫）使用 Codable 序列化為 JSON 字串後存入 UserDefaults，如未來需擴充可替換成 Core Data 或 SQLite。

## UI/UX 與 Design System

- 儘量使用 Design System 元件（`DSCard`, `DSButton`, `DSTextArea` 等），可在 `DesignSystem.swift` 中新增 token。
- 需要動畫時使用 `DSMotion.run` 與 `DS.AnimationToken`，保持一致的動態表現。
- 全域 Banner 透過 `BannerCenter.show()`；避免在單一 View 內直接修改 Banner state。
- 新增按鈕/卡片時優先使用 `DSButton(style:size:)` 與 `DSCardTitle`，避免重新建立主要/次要樣式或手刻 HStack 排版。
- 間距、圓角、邊框請採用 `DS.Spacing`、`DS.Radius`、`DS.BorderWidth` 等 token，不再直接寫 `CGFloat` 魔術數字；需髮絲線效果時改用 `DS.Metrics.hairline`。

## 加入新功能時的建議流程

1. 於 `docs/workflows.md` 新增條目並列出預計修改/新增的檔案。
2. 建立 ViewModel 或 Store：決定哪些狀態需要跨畫面共享。
3. 寫好 HTTP Service 或 Mock：確保缺少 `BACKEND_URL` 時能明確提示。
4. 建置 UI 元件與路由（NavigationStack/Sheet/Popover）。
5. 更新文件與測試：
   - 調整 README 或 `docs/*.md` 對應段落。
   - 加入 Swift Testing / XCTest 測試（若適用）。
   - 需要與後端同步的變更請加註注解並通知後端。

## 常見 Debug 重點

- **無法連線後端**：確認 `Info.plist` 的 `BACKEND_URL` 或執行時環境變數，並檢查 `AIServiceFactory` log。
- **批改結果錯位**：檢查後端回傳 `originalRange`/`correctedRange` 是否存在；Highlighter 會自動 fallback 但可能不準確。
- **題庫列表空白**：確認 `LocalBankStore` 是否有載入，或使用者是否未從雲端複製題庫。
- **TTS 無聲**：檢查 `AVAudioSession` log、確保未被 `InstantSpeaker` 永久暫停。

## 文件維護

- 調整任何主要流程時，請同步更新 `docs/architecture.md` 與 `docs/workflows.md`，保持文件與實作一致。
- 可在 `docs/` 下加入 `decision-log/`、`how-to/` 子資料夾，記錄設計決策或操作指南。
