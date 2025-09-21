# Chat Feature - 聊天功能

## 核心元件
- `ChatWorkspaceView`: 主要聊天容器視圖
- `ChatBubbleComponents`: 聊天氣泡UI元件
- 支援多工作區聊天場景

## 設計模式
- 使用氣泡式對話介面
- 支援訊息歷史紀錄
- 整合TTS功能於聊天互動
- 遵循現有聊天UI模式

## 整合重點
- 與Workspace模組協作
- 使用Shared/Services的API服務
- 支援離線場景處理

## 依賴參考
@../CLAUDE.md
@../../Shared/Services/CLAUDE.md