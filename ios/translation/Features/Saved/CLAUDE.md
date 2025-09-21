# Saved Feature - 儲存功能

## 核心功能
- Saved JSON清單管理 (`SavedJSONListSheet`)
- 檢視、複製、刪除操作
- 一鍵轉換為單字卡集

## 資料管理
- 本機JSON持久化
- 批改結果自動儲存
- 支援批量操作

## 轉換機制
- 呼叫backend `/make_deck` API
- 將translation記錄轉為flashcard格式
- 錯誤處理與進度提示

## UI模式
- Sheet模式展示清單
- 支援搜尋與篩選
- 整合刪除確認流程

## 依賴參考
@../CLAUDE.md
@../../Shared/Models/CLAUDE.md