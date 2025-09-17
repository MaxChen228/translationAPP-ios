# translation

中英翻譯批改（SwiftUI iOS App）。使用者輸入中文與自己的英文嘗試，按下「批改」後由服務層呼叫後端 AI 回傳修正版、分數與錯誤清單；若未設定後端則自動切為 Mock。介面採自訂設計系統（DS），包含字型、間距、色彩、卡片與按鈕樣式，並提供原文/修正版切換時的高亮對位動畫。

本 README 已更新至包含「Workspace 多工流程」、「已儲存 JSON 整理成單字卡」、「TTS 播音複習」與「題庫（Bank）整合」等最新功能。

## 快速開始
- 開啟專案：`open translation.xcodeproj`（或 Xcode 直接打開，Scheme：`translation`）。
- 執行：Cmd+R。
- 測試：Cmd+U，或命令列：
  - 建置（Debug）：`xcodebuild -scheme translation -configuration Debug build`
  - 單元+UI 測試：`xcodebuild test -scheme translation -destination 'platform=iOS Simulator,name=iPhone 15'`

## 主要畫面與流程（新版）
- Workspace 清單（`WorkspaceListView`）
  - 以卡片呈現多個工作分頁（Workspace），每個 Workspace 都各自保存中文/英文輸入與批改結果。
  - 支援拖曳重排、重新命名與刪除；右上角可開啟「已儲存 JSON」清單。
  - 上方「快速功能」可進入「單字卡」與「題庫本」。
- 翻譯批改（`ContentView`）
  - 區塊「中文原文」與「我的英文」，輔以練習提示（來自題庫）。
  - 下方「結果切換卡」支援原文/修正版切換與滑動；兩側高亮可對位到同一筆錯誤。
  - 「錯誤列表」支援依五大類型篩選、點擊聚焦對應高亮、對單筆錯誤進行「儲存 JSON」。
  - 底部懸浮工具列提供「批改」、「下一題（題庫）」、「重設」。
- 題庫本/題庫（`BankBooksView` → `BankListView`）
  - `GET /bank/books` 取得主題書本；內頁以 `GET /bank/items` 顯示題目與提示，並可直接「練習」回填到當前 Workspace。
  - 題目採宋體大字 + 細邊框凸顯；提示區塊上方使用髮絲線分隔；已完成題目會顯示徽章。
- 已儲存 JSON 清單（`SavedJSONListSheet`）
  - 檢視、複製或刪除先前儲存的錯誤樣本 JSON。
  - 一鍵整理為「單字卡集」（呼叫後端 `/make_deck`；未設定後端時使用 Mock 產生）。
- 單字卡（`FlashcardDecksView` → `DeckDetailView` → `FlashcardsView`）
  - 管理多個卡片集（建立自 JSON 或示例卡集）；可重新命名與刪除。
  - 卡片詳情提供進度統計（未學習/仍在學習/已精通）。
  - 複習畫面支援：翻面、左右滑動切換、兩種複習模式（瀏覽/標注），以及 TTS 播音與迷你播放器。
  - 卡片背面支援變體括號語法（如「(turn out | prove) to be」），可用「括號組合器」選擇變體並複製目前組合。

## 功能總覽
- 批改與高亮：回傳分數、修正版與錯誤清單（Mock 或 HTTP）；原文/修正版兩側高亮對位。
- 錯誤列表：顯示錯誤類型、片段、中文說明與建議；支援類型篩選與點擊聚焦。
- Workspace：多工編輯、拖曳重排、重新命名；批改完成時顯示頂端 Banner 並可一鍵返回該 Workspace。
- 題庫：主題書本、題目清單、難度點與標籤展示；支援從剪貼簿批次匯入；可依裝置進度標示完成與抽「下一題」。
- 已儲存 JSON：將單筆錯誤及三段文字序列化為 JSON 存入 `UserDefaults`，可檢視/複製/刪除，並整理成單字卡集。
- 單字卡與 TTS：支援卡片編輯、進度標注（右滑 +1、左滑 −1）、TTS 播音（順序/語速/間隔/語言設定）與迷你播放器。

## 設定與環境變數
App 以 `AppConfig` 讀取 Info.plist 或環境變數：
- `BACKEND_URL`：後端 Base URL，例如 `http://127.0.0.1:8080`。

統一設定說明：
- App 會自動用 `BACKEND_URL + "/correct"` 作為批改端點；題庫/單字卡也同一 Base。
- 只需設定一個變數：`BACKEND_URL=http://127.0.0.1:8080`。

設定方式（二選一）：
- 在 `Info.plist` 加入對應鍵值。
- 以 Scheme 的「Arguments → Environment Variables」設定，或在命令列匯出環境變數。

## 本機後端（開發用）
本庫提供兩套可選後端：
- 簡易 HTTP 伺服器：`python3 backend/server.py`（`127.0.0.1:8080`）。
- FastAPI 伺服器（Gemini）：
  1. `python3 -m venv .venv && source .venv/bin/activate && pip install -r backend/requirements.txt`
  2. 複製 `backend/.env.example` → `backend/.env`，設定：
     - 金鑰：`GEMINI_API_KEY` 或 `GOOGLE_API_KEY`
     - 模型：`LLM_MODEL`（或 `GEMINI_MODEL`）預設 `gemini-2.5-flash`
     - 伺服器位址：`HOST`、`PORT`
  3. 啟動：`python3 backend/main.py`（支援 `PORT=8080` 覆寫）。
  4. 若 API 失敗想退回規則式結果，設 `ALLOW_FALLBACK_ON_FAILURE=1`。
  5. 健康檢查：`GET /healthz` 回 `{status, provider, model}`。

### 雲端瀏覽 API（Cloud Library）
提供唯讀精選內容，供 App「瀏覽」並「複製到本機」。由 `CloudLibraryService` 呼叫。

- `GET /cloud/decks` → `[{ name, count, id }]`
- `GET /cloud/decks/{id}` → `{ id, name, cards: [{ id(UUID), front, back, frontNote?, backNote? }] }`
- `GET /cloud/books` → `[{ name, count }]`
- `GET /cloud/books/{name}` → `{ name, items: [BankItem] }`

註：此簡易後端已內建少量假資料，方便開發；若 `BACKEND_URL` 未設定，App 也會自動改用 Mock 來源顯示示例。

### 批改 API（/correct）
```
POST /correct
{ "zh": "中文原文", "en": "我的英文", "bankItemId": "可選-題目ID", "deviceId": "可選-裝置ID" }

回應：
{ "corrected": "...", "score": 85, "errors": [
  { "id": "UUID?", "span": "...", "type": "morphological|syntactic|lexical|phonological|pragmatic", "explainZh": "...", "suggestion": "...?", "hints": {"before":"?","after":"?","occurrence":1}, "originalRange": {"start":0,"length":2}, "suggestionRange": {"start":0,"length":2}, "correctedRange": {"start":0,"length":2} }
]}
```
- 提供 `*Range`（UTF‑16 偏移）可提升高亮精準度；若無則前端回退字串搜尋。
- 離線測試：`FORCE_SIMPLE_CORRECT=1` 直接走規則式 `_simple_analyze`。

### 題庫 API（/bank/*）
- `GET /bank/books`
- `GET /bank/items?limit&offset&difficulty&tag&deviceId`
  - 回傳物件含 `completed: Bool`（若帶入 `deviceId`，會依該裝置進度標示完成）。
- `GET /bank/random?difficulty&tag&deviceId&skipCompleted`
  - 支援 `skipCompleted=1` 略過已完成題目。
- `POST /bank/import`（從剪貼簿批次匯入）
- 進度：
  - `GET /bank/progress?deviceId` → `{ deviceId, completedIds, records[] }`
  - `POST /bank/progress/complete` → `{"itemId":"...","deviceId":"...?","score":85,"completed":true}`

匯入請求範例：
```json
{ "text": "...clipboard text...", "defaultTag": "Daily", "replace": false }
```
固定格式（區塊以空行分隔；鍵名中英皆可）：
```
ZH: 我昨天去商店買水果。
難度: 2
標籤: Daily, Shopping
提示:
- grammar: 使用過去式
- usage: shop 在此情境常改為 store

中文: 我每天都跑步。
DIFF: 1
TAGS: Daily, Exercise
HINTS:
- collocation: go for a run 是常見搭配
```

### 單字卡 API（/make_deck）
```
POST /make_deck
{ "name": "未命名", "items": [
  { "zh": "…", "en": "…", "corrected": "…", "span": "…", "suggestion": "…", "explainZh": "…", "type": "lexical" }
]}

回應：
{ "name": "測試卡集", "cards": [
  { "front": "中文短語", "frontNote": "可選", "back": "(A | B) …", "backNote": "可選" }
]}
```
- App 會從「已儲存 JSON」整理 payload 呼叫 `/make_deck`，將回應加入「單字卡集」。
- 若未設定 `BACKEND_URL`，會改用本地 Mock 卡片產生。

## 專案結構
- App 原始碼：`translation/`
  - 進入點：`translationApp.swift`（導航列字型套用、Banner 驗證、Router）。
  - Workspace：`WorkspaceStore.swift`、`components/WorkspaceListView.swift`。
  - 翻譯批改：`ContentView.swift`、`CorrectionViewModel.swift`、`Highlighter.swift`。
  - 題庫：`BankService.swift`、`components/BankBooksView.swift`、`components/BankListView.swift`。
  - 已儲存 JSON 與單字卡：`SavedErrorsStore.swift`、`components/SavedJSONListSheet.swift`、
    `FlashcardDecksStore.swift`、`components/FlashcardDecksView.swift`、`components/DeckDetailView.swift`、`components/FlashcardsView.swift`。
  - TTS 與音訊：`SpeechEngine.swift`、`TTSSettings.swift`、`components/FlashcardsAudioSettingsSheet.swift`、`components/AudioMiniPlayerView.swift`、`PlaybackBuilder.swift`。
  - 變體語法與組合器：`VariantSyntax.swift`、`components/VariantBracketComposerView.swift`。
  - 設計系統：`DesignSystem.swift`、`components/DS*.swift`（卡片、按鈕、分隔線等）。
  - 其他：`Models.swift`、`Logging.swift`、`FontLoader.swift`、`DeviceID.swift`、`Keychain.swift`、`RouterStore.swift`、`BannerCenter.swift`。
- 測試：`translationTests/`（Swift Testing）、`translationUITests/`（XCTest）。
- Xcode 專案：`translation.xcodeproj`（單一 target 與 scheme：`translation`）。

## 設計系統（DS）
- 字型：
  - 無襯線（Avenir）用於一般 UI：`DS.Font.body`、`title`、`section`…
  - 襯線（宋體候選）用於題目/強調：`DS.Font.serifTitle`、`serifBody`；導覽列標題也改為襯線字型。
  - 啟動時 `FontLoader.registerBundledFonts()` 會載入 bundle 內 `.ttf/.ttc/.otf`。
- 色彩與間距：`DS.Palette`、`DS.Spacing`、`DS.Radius`、`DS.Metrics.hairline`（確保在 3x 螢幕 >= 0.5pt）。
- 元件與樣式：
  - 卡片：`DSCard`、`DSOutlineCard`。
  - 按鈕：`DSPrimaryButton`、`DSSecondaryButton`、小尺寸 `DSSecondaryButtonCompact`、圓形 `DSPrimaryCircleButton/DSOutlineCircleButton`。
  - 分隔線/髮絲線：`DSSeparator`、`View.dsTopHairline`。
  - 動畫 Token：`DS.AnimationToken`（flip/reorder/tossOut…），會在開啟「降低動作」時自動降級。

常見自訂：
- 題庫卡片外框粗細：`BankListView` 的 `stroke(..., lineWidth: DS.BorderWidth.regular)`。
- 次要按鈕大小：`DSSecondaryButtonCompact` 的字級與 padding。
- Sticky Bar 上緣髮絲線：`View.dsTopHairline(...)`。

## 單字卡與 TTS（重點）
- 複習模式（`FlashcardsSettingsSheet`）：
  - 瀏覽：左右滑動切換卡片，不改精熟度。
  - 標注：右滑 +1／左滑 −1 並切到下一張；每張卡顯示當前精熟度。
- TTS 播音：
  - 設定（`FlashcardsAudioSettingsSheet`）：順序（Front/Back/Front→Back/Back→Front）、語速、段間隔/卡間隔、前/背語言（預設 zh‑TW/en‑US）、變體補位（隨機/循環）。
  - 迷你播放器：播放/暫停、上一張/下一張、停止、進度環與即時音量指示。
- 變體括號語法：`(A | B)` 群組會按索引逐行組合並播報（循環或隨機），同時提供視覺化「括號組合器」與一鍵複製。

## 測試
- 單元測試：`translationTests/`（Swift Testing）。
- UI 測試：`translationUITests/`（XCTest）。
- 目標：涵蓋基本流程、錯誤篩選與高亮計算，以及單字卡 Deck JSON 解析。

## 日誌與裝置 ID
- `Logging.swift` 使用 `OSLog`（AI/UI 類別）；DEBUG 會鏡像至 Console。
- `DeviceID` 儲存在 Keychain，供題庫進度與後端統計使用。

## 開發規範
請參照根目錄 `AGENTS.md`：目錄結構、建置/測試指令、Swift 風格與 Conventional Commits。避免提交機密；第三方套件需事先討論。

## 疑難排解
- 沒有批改結果：確認已設定 `BACKEND_URL` 或使用 Mock（未設定時預設走 Mock）。
- 題庫無資料：先啟動 FastAPI 後端，或用「匯入」從剪貼簿加入題目。
- 字型未生效：確認字型檔已加入 app bundle；`FontLoader` 啟動時會自動註冊。
- 高亮與預期不符：盡量提供 `originalRange` / `correctedRange`；或在錯誤 `hints` 帶入 `before/after/occurrence` 提升匹配準確度。

---

需要我補上操作影片與截圖、或撰寫更進一步的 API 契約與測試策略嗎？可以開 Issue 告知！
