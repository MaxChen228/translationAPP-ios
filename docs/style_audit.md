# 樣式硬編碼盤點（2025-09-23）

> 目的：集中列出目前仍使用硬編碼樣式的區域，提供後續 Design System 對齊的依據。

## 分類與清單

### 1. 間距 / 尺寸
- `Features/Workspace/Components/ScoreBarView.swift:13`
- `Features/Workspace/Components/ResultSummaryCard.swift:31`
- `Features/Workspace/Components/ResultSwitcherCard.swift:44`
- `Features/Workspace/Components/Shelf/RenameSheet.swift:17`
- `Features/Saved/Components/SaveDeckNameSheet.swift:20`
- `Features/Saved/Components/SavedRowCard.swift:80`
- `Features/Workspace/Views/WorkspaceListView.swift:347`
- `Features/Workspace/Components/ErrorDetailPopover.swift:36`
- `Features/Flashcards/Views/FlashcardsSettingsSheet.swift:98`
- `Features/Flashcards/Components/FlashcardsAudioSettingsSheet.swift:78`
- `Features/Flashcards/Components/AudioMiniPlayerView.swift:21-63`
- `Features/Chat/Views/ChatWorkspaceView.swift:144`
- `Features/Chat/Bank/Views/AllBankItemsView.swift:209`
- `Features/Chat/Bank/Views/LocalBankListView.swift:161`

說明：上述檔案仍直接使用 `spacing: 12`、`.padding(16)`、`frame(width: 160)` 等魔術數字。建議：統一改用 `DS.Spacing`、`DS.ButtonSize`，或新增 `DSSheetContainer`、`DSCardWidth` token。

### 2. 顏色 / 透明度
- `Features/Chat/Bank/Views/CloudCourseLibraryView.swift:94-98`
- `Features/Chat/Bank/Views/CloudCourseDetailView.swift:132-136`
- `Features/Chat/Views/ChatBubbleComponents.swift:307`
- `Features/Calendar/Views/DayDetailView.swift:192-229`
- `Shared/Utilities/HighlightAnimationController.swift:142`、`:169`、`:188`

說明：多處使用 `Color.gray.opacity(...)`、`Color.white.opacity(...)` 或 `UIColor(DS.Palette.primary).withAlphaComponent(...)`。建議：導入 `DS.Palette.surfaceAlt`、新增 `DS.Palette.placeholder`、`DS.Opacity.highlightActive/Inactive` 等 token。

### 3. UIKit / CALayer 常數
- `Shared/Utilities/HighlightAnimationController.swift:139`、`:167`
- `Features/Workspace/Components/Shelf/ShelfSelectionIndicator.swift:19`
- `Features/Workspace/Components/ScoreBarView.swift:13`（UIKit 動畫觸發相關）

說明：層級效果仍以 `cornerRadius = 4`、`padding(4)` 控制；需要轉為 `DS.Radius` 或集中至 Utility。

## 需新增的 Design System Token / 元件
- **AsyncImage placeholder**：雲端課程圖像空態顏色。
- **Highlight**：動畫使用的圓角、選取與未選取透明度。
- **Sheet/Popover 容器**：標準 padding、間距、最大寬度。
- **Mini Player 尺寸**：播放/跳轉按鈕與字級、進度條高度。

## 後續建議流程
1. 就此清單排定批次：先處理 Workspace/Saved 彈窗，再處理 Cloud 畫面、Highlight、Mini Player。
2. 每批調整時同步更新 token（如需新增），並補充 `AGENTS.md` / `docs/architecture.md`。
3. 完成後重新檢查該區域並更新此文件，逐步歸零硬編碼項目。
