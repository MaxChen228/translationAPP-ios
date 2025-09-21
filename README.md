# translation (iOS)

SwiftUI iOS App：提供中英翻譯批改、錯誤高亮、Workspace 多工、題庫本、本機 Saved JSON、單字卡複習（含 TTS 播音與變體括號語法）。

本 repo 僅包含 iOS 前端。後端服務已獨立為另一個 Git 倉：
- translation-backend（GitHub）：https://github.com/MaxChen228/translation

## 文件導覽
- [docs/README.md](docs/README.md)：iOS 文件索引，快速連結到架構導覽與常見功能說明。
- 若需掌握整體模組與資料流，請先閱讀 `docs/architecture.md`。
- 針對批改、題庫、聊天、TTS 等具體需求，可查閱 `docs/workflows.md` 的功能流程索引。

## 目錄概覽
- `ios/translation/App/`：App 生命週期、全域設定與路由（`translationApp.swift`, `AppSettingsStore.swift` 等）。
- `ios/translation/DesignSystem/`：Design System 與共用 UI 元件（`DesignSystem.swift`, `Components/DS*`），包含月曆元件 `DSCalendarCell`、`DSCalendarGrid` 與最新的 `DSButton`、`DSCardTitle`。
- `ios/translation/Features/`：依領域拆分的模組（Workspace、Bank、Flashcards、Saved、Chat、Settings、**Calendar**）。
- `ios/translation/Shared/`：跨模組共享的模型、服務、工具與通用 View。新增 `PracticeRecordsStore` 練習記錄管理。
- `ios/translation/Resources/`：資源與在地化字串。

## 環境需求
- Xcode 16.4+（iOS 18 SDK）
- iOS 16+（建議 iOS 17/18 模擬器）

## 快速開始
- 開啟專案：`open ios/translation.xcodeproj`（Scheme：`translation`）
- 執行：Xcode Cmd+R
- 測試：Xcode Cmd+U 或命令列
  - 建置（Debug）：
    ```bash
    xcodebuild -project ios/translation.xcodeproj -scheme translation -configuration Debug build
    ```
  - 單元+UI 測試（選擇一台有效模擬器，例如 iPhone 16）：
    ```bash
    xcodebuild -project ios/translation.xcodeproj -scheme translation \
      -destination 'platform=iOS Simulator,name=iPhone 16' test
    ```

## 連線後端（BACKEND_URL）
App 透過 Info.plist 的 `BACKEND_URL` 讀取後端位址（由 `AppConfig` 使用）。
- 預設值在 Build Settings 以 `INFOPLIST_KEY_BACKEND_URL` 注入。
- 開發建議：將後端在本機啟動於 `http://127.0.0.1:8080`，或部署至雲端後填入對應 URL。

統一端點說明：
- 批改：`POST {BACKEND_URL}/correct`
- 雲端題庫：`GET {BACKEND_URL}/cloud/books`、`GET {BACKEND_URL}/cloud/books/{name}`
- 雲端卡片集：`GET {BACKEND_URL}/cloud/decks`、`GET {BACKEND_URL}/cloud/decks/{id}`
- 產生單字卡：`POST {BACKEND_URL}/make_deck`

注意：必須先設定 `BACKEND_URL`，否則批改、雲端瀏覽與單字卡產生會顯示錯誤提示（Banner），不再提供本地 Mock。

## 主要畫面與流程
- Workspace 清單（components/WorkspaceListView.swift）
  - 多個 Workspace 平行編輯，支援拖曳、重新命名、刪除；可開啟 Saved JSON 清單。新增 `CalendarEntryCard` 快速進入日曆檢視。
- 翻譯批改（ContentView.swift）
  - 顯示中文原文/英文嘗試；提交批改後顯示修正版、分數與錯誤清單；兩側文字高亮可對位到同一筆錯誤。現已整合練習記錄系統。
- 題庫本（本機；components/BankBooksView.swift → LocalBankListView）
  - 以本機為主、離線可用；可從雲端精選書本複製到本機。新增階層式標籤篩選器 `NestedTagFilterView`，重設計 `AllBankItemsView` 統一介面風格。
- 已儲存 JSON（components/SavedJSONListSheet.swift）
  - 檢視/複製/刪除；可一鍵呼叫 `/make_deck` 轉成單字卡集。
- 單字卡（FlashcardDecksView → DeckDetailView → FlashcardsView）
  - 管理多 Deck；複習支援左右滑、翻面、標注模式；迷你播放器與 TTS 設定（語速/語言/間隔/順序）。
- **練習日曆（CalendarView）**
  - 月曆介面使用外框式卡片呈現每日練習活動；點選日期顯示詳細統計與練習摘要；支援快速跳回今天並整合練習記錄視覺化。
- 練習記錄（PracticeRecordsListView.swift）
  - 以 DSOutlineCard 呈現清單、統計與批改摘要，提供批次清除、錯誤數量徽章與題庫來源標示。

## 專案結構
- 原始碼：`ios/translation/`
  - 進入點：`translationApp.swift`
  - Stores/Services/Views/DesignSystem：同名 .swift 檔案與 `components/` 目錄
  - Assets：`Assets.xcassets`；字型：`Resources/Fonts/`
- 測試：`ios/translationTests/`、`ios/translationUITests/`
- 專案檔：`ios/translation.xcodeproj`

## API 介面（簡述｜需設定 BACKEND_URL）
- `POST /correct`
  - 請求：
    ```json
    {
      "zh": "string",
      "en": "string",
      "bankItemId": "string?",
      "deviceId": "string?",
      "hints": [{ "category": "morphological|syntactic|lexical|phonological|pragmatic", "text": "提示文字" }]?,
      "suggestion": "教師建議（非結構化段落，可省略）",
      "model": "gemini-2.5-pro | gemini-2.5-flash"?
    }
    ```
  - 回應：`{ corrected: string, score: number, errors: Error[] }`

- `POST /make_deck`
  - 請求新增（可選）：`model?: string`（同上，若後端支援將使用該模型產製卡片）
- `GET /cloud/books`、`GET /cloud/books/{name}`：唯讀精選題庫
- `GET /cloud/decks`、`GET /cloud/decks/{id}`：唯讀精選卡片集
- `POST /make_deck`
  - 請求：`{ name?: string, items: [{ zh?, en?, corrected?, span?, suggestion?, explainZh?, type? }] }`
  - 回應：`{ name: string, cards: [{ front, frontNote?, back, backNote? }] }`

更完整欄位與行為請參考後端 README 與程式碼（translation-backend/main.py）。

## 設計系統（Design System）
- 字型載入：`FontLoader.registerBundledFonts()`
- Palette/Spacing/Radius/Animations：`DesignSystem.swift` 與 `components/DS*.swift`
- `DSButton` 統一原本零散的主要/次要按鈕樣式，透過 `style`（primary/secondary）與 `size`（full/compact）參數套用。
- `DSCardTitle`、`DSOutlineCard` 與新增的尺寸 token / hairline 設定，協助避免魔術數字並維持卡片排版一致。

## 測試
- 單元：`ios/translationTests/`（Swift Testing）
- UI：`ios/translationUITests/`（XCTest）
- 覆蓋重點：批改流程、高亮定位、Deck JSON 解析、TTS 邏輯基本面

## 疑難排解
- 沒有批改結果：先確認 `BACKEND_URL` 是否設定正確（必填）。
- 題庫清單為空：先到「題庫本」頁的「瀏覽雲端題庫」複製到本機。
- 字型未生效：確認字型檔在 bundle 並被 `FontLoader` 註冊。
- 高亮錯位：回傳錯誤時盡量提供 `hints.before/after/occurrence` 提升片段對位準確度。

## 貢獻
請遵照 `AGENTS.md` 的風格/命名/測試規範。Git 提交建議採 Conventional Commits。
