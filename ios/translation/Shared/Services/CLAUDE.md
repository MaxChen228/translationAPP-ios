# Services - 服務層

## 核心服務
- API服務：與translation-backend通訊
- 持久化服務：本地資料儲存
- TTS服務：文字轉語音功能
- 網路狀態監控

## API整合
- 統一使用async/await模式
- 標準化錯誤處理機制
- 支援不同模型選擇 (gemini-2.5-pro/flash)
- BACKEND_URL配置管理

## 主要端點
- `POST /correct`: 翻譯批改
- `GET /cloud/books`: 雲端題庫
- `GET /cloud/decks`: 雲端卡片集
- `POST /make_deck`: 產生單字卡

## 錯誤處理
- 網路連線錯誤
- API回應錯誤
- 本地資料損壞
- 使用Banner顯示錯誤訊息

## 快取策略
- 適當的本地快取
- 離線場景支援
- 資料同步機制

## 依賴參考
@../Models/CLAUDE.md
@../../DesignSystem/BannerCenter.swift