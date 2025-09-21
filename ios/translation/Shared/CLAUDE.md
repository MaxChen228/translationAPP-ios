# Shared模組 - 跨Feature共享元件

## 模組架構
- `Models/`: 資料結構定義與解析邏輯
- `Services/`: API呼叫、持久化、網路服務
- `Utilities/`: 工具函數、擴展、helper
- `Views/`: 跨Feature共用UI元件

## 使用原則
- **優先使用existing patterns**和實作
- 保持向後相容性，避免破壞性變更
- 考慮多Feature使用場景
- 統一錯誤處理和API呼叫模式

## 設計考量
- Models需支援JSON序列化/反序列化
- Services處理async/await和錯誤處理
- Views保持通用性，避免Feature特定邏輯
- Utilities提供純函數，便於測試

## 命名規範
- 清晰描述用途的命名
- 避免過度抽象或縮寫
- 保持與Feature命名一致性

## 依賴管理
- 避免循環依賴
- 最小化外部依賴
- 與DesignSystem協調UI規範

## 檔案參考
@Models/
@Services/
@Utilities/
@Views/