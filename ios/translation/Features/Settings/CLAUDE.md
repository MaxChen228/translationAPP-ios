# Settings Feature - 設定功能

## 設定項目
- TTS語音設定 (語速、語言、間隔)
- 模型選擇 (gemini-2.5-pro/flash)
- 後端連線設定 (BACKEND_URL)
- 應用偏好設定

## 架構模式
- 使用AppSettingsStore全域狀態管理
- 設定值持久化至UserDefaults
- 即時生效與預覽功能

## UI設計
- 使用標準Settings UI模式
- 分組設定項目
- 支援重置為預設值

## 整合重點
- 影響全域TTS播放行為
- 控制API呼叫模型選擇
- 連線狀態檢測與提示

## 依賴參考
@../CLAUDE.md
@../../App/AppSettingsStore.swift