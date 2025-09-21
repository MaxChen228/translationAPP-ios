# Features模組通用規則

## 架構模式
每個Feature遵循以下結構：
- Views: SwiftUI視圖實作
- ViewModels: 業務邏輯和狀態管理
- Models: Feature專屬資料結構
- Store模式進行狀態管理

## 命名慣例
- View: `{Feature}View.swift`、`{Feature}WorkspaceView.swift`
- ViewModel: `{Feature}ViewModel.swift`
- Store: `{Feature}Store.swift`
- Components: `{Feature}Components.swift`

## 通用模式
- 與Shared/Services整合API呼叫
- 使用DesignSystem元件保持視覺一致性
- 支援多工作區場景
- 錯誤處理使用統一Banner機制

## 依賴參考
@../../DesignSystem/CLAUDE.md
@../../Shared/CLAUDE.md
@../../../docs/workflows.md