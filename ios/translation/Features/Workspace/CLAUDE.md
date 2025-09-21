# Workspace Feature - 工作區功能

## 核心功能
- 多個Workspace平行編輯
- 支援拖曳操作、重新命名、刪除
- 工作區清單管理 (`WorkspaceListView`)
- 翻譯批改主要流程 (`ContentView`)

## 批改流程
- 顯示中文原文/英文嘗試
- 提交批改後顯示修正版、分數與錯誤清單
- 兩側文字高亮可對位到同一筆錯誤
- 支援hint系統提升批改準確度

## 設計模式
- 使用Store模式管理工作區狀態
- 支援本地資料持久化
- 與backend API `/correct` 端點整合
- 錯誤高亮與定位邏輯

## 依賴參考
@../CLAUDE.md
@../../Shared/Models/CLAUDE.md