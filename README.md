# translation (iOS)

SwiftUI iOS App：提供中英翻譯批改、錯誤高亮、Workspace 多工、題庫本、本機 Saved JSON、單字卡複習（含 TTS 播音與變體括號語法）。

本 repo 僅包含 iOS 前端。後端服務已獨立為另一個 Git 倉：
- translation-backend（GitHub）：https://github.com/MaxChen228/translation

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

若未設定 `BACKEND_URL`，App 會自動切為本地 Mock，仍可體驗主要流程。

## 主要畫面與流程
- Workspace 清單（components/WorkspaceListView.swift）
  - 多個 Workspace 平行編輯，支援拖曳、重新命名、刪除；可開啟 Saved JSON 清單。
- 翻譯批改（ContentView.swift）
  - 顯示中文原文/英文嘗試；提交批改後顯示修正版、分數與錯誤清單；兩側文字高亮可對位到同一筆錯誤。
- 題庫本（本機；components/BankBooksView.swift → LocalBankListView）
  - 以本機為主、離線可用；可從雲端精選書本複製到本機。
- 已儲存 JSON（components/SavedJSONListSheet.swift）
  - 檢視/複製/刪除；可一鍵呼叫 `/make_deck` 轉成單字卡集。
- 單字卡（FlashcardDecksView → DeckDetailView → FlashcardsView）
  - 管理多 Deck；複習支援左右滑、翻面、標注模式；迷你播放器與 TTS 設定（語速/語言/間隔/順序）。

## 專案結構
- 原始碼：`ios/translation/`
  - 進入點：`translationApp.swift`
  - Stores/Services/Views/DesignSystem：同名 .swift 檔案與 `components/` 目錄
  - Assets：`Assets.xcassets`；字型：`Resources/Fonts/`
- 測試：`ios/translationTests/`、`ios/translationUITests/`
- 專案檔：`ios/translation.xcodeproj`

## API 介面（簡述）
- `POST /correct`
  - 請求：`{ zh: string, en: string, bankItemId?: string, deviceId?: string }`
  - 回應：`{ corrected: string, score: number, errors: Error[] }`
- `GET /cloud/books`、`GET /cloud/books/{name}`：唯讀精選題庫
- `GET /cloud/decks`、`GET /cloud/decks/{id}`：唯讀精選卡片集
- `POST /make_deck`
  - 請求：`{ name?: string, items: [{ zh?, en?, corrected?, span?, suggestion?, explainZh?, type? }] }`
  - 回應：`{ name: string, cards: [{ front, frontNote?, back, backNote? }] }`

更完整欄位與行為請參考後端 README 與程式碼（translation-backend/main.py）。

## 設計系統（Design System）
- 字型載入：`FontLoader.registerBundledFonts()`
- Palette/Spacing/Radius/Animations：`DesignSystem.swift` 與 `components/DS*.swift`
- 常見自訂：細邊框、髮絲線、次要按鈕尺寸等 token 已封裝為組件屬性

## 測試
- 單元：`ios/translationTests/`（Swift Testing）
- UI：`ios/translationUITests/`（XCTest）
- 覆蓋重點：批改流程、高亮定位、Deck JSON 解析、TTS 邏輯基本面

## 疑難排解
- 沒有批改結果：先確認 `BACKEND_URL` 是否設定正確，或改以 Mock 測試。
- 題庫清單為空：先到「題庫本」頁的「瀏覽雲端題庫」複製到本機。
- 字型未生效：確認字型檔在 bundle 並被 `FontLoader` 註冊。
- 高亮錯位：回傳錯誤時盡量提供 `hints.before/after/occurrence` 提升片段對位準確度。

## 貢獻
請遵照 `AGENTS.md` 的風格/命名/測試規範。Git 提交建議採 Conventional Commits。

