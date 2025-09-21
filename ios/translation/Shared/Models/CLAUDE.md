# Models - 資料模型

## 設計原則
- 使用Swift Codable進行JSON序列化
- 保持資料結構簡潔明確
- 與backend API契約一致

## 核心模型
- Translation相關：中英文對、批改結果、錯誤資訊
- Workspace相關：工作區狀態、本地持久化
- Flashcard相關：卡片資料、Deck結構
- Settings相關：使用者偏好設定

## 命名規範
- 使用清楚描述的struct名稱
- 避免縮寫，保持可讀性
- 與API欄位名稱對應

## 序列化考量
- 處理optional欄位
- 提供合理的預設值
- 支援向後相容的欄位變更

## 依賴參考
@../Services/CLAUDE.md