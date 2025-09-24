# 樣式硬編碼盤點（2025-09-23）

> 目的：集中列出目前仍使用硬編碼樣式的區域，提供後續 Design System 對齊的依據。

## 最新狀態（2025-09-23 更新）
- ✅ Workspace Rename Sheet 及 Shelf Rename Sheet 改用 `DSButton(style: .*, size: .compact)`，移除手動指定寬度。
- ✅ 雲端課程 `AsyncImage` 空態使用 `DS.Palette.placeholder` 與 `DS.Opacity.placeholder{Strong,Soft}`，避免灰色硬編碼。
- ✅ Chat 附件邊框改為 `DS.Component.AttachmentBorder` 與 `DS.Opacity.overlayBright`，統一使用設計系統色票。
- ✅ Calendar 連續天數徽章與 Highlight 動畫層改用 `DS.Component.HighlightLayer`、`DS.Component.CalendarBadge` 與 `DS.Opacity.highlightActive/highlightInactive`。
- ✅ Shelf Selection Indicator 內縮、圓角與尺寸改為 `DS.Component.ShelfSelection` tokens。

### 目前待處理項目
- 無（持續觀察新模組或第三方整合時是否出現額外硬編碼）。

## 新增的 Design System Token / 元件
- `DS.Palette.placeholder`
- `DS.Opacity.highlightActive`、`DS.Opacity.highlightInactive`
- `DS.Opacity.placeholderStrong`、`DS.Opacity.placeholderSoft`、`DS.Opacity.overlayBright`、`DS.Opacity.badgeFill`
- `DS.Component.HighlightLayer`、`DS.Component.CalendarBadge`、`DS.Component.ShelfSelection`、`DS.Component.AttachmentBorder`

## 後續建議流程
1. 針對新功能或 Legacy 畫面持續檢查，若發現硬編碼樣式即新增至此文件並排程處理。
2. 當新增設計 token 時同步更新 `AGENTS.md`、`docs/architecture.md`，確保代理與開發者皆能引用正確規範。
3. 每次批次處理完成後立即回填這份清單，避免重複調整。
