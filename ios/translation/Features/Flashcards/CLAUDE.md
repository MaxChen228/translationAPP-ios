# Flashcards Feature - 單字卡功能

## 核心元件
- `FlashcardDecksView`: Deck管理介面
- `DeckDetailView`: 單一Deck詳細資訊
- `FlashcardsView`: 卡片複習介面

## 複習機制
- 支援左右滑動操作
- 卡片翻面功能
- 標注模式 (correct/incorrect)
- 迷你播放器整合

## TTS整合
- 語速調整功能
- 多語言支援 (中英文)
- 播放間隔設定
- 順序播放控制
- 變體括號語法解析

## 資料來源
- 從Saved JSON一鍵轉換 (`/make_deck`)
- 雲端精選卡片集瀏覽
- 本機Deck管理與持久化

## 依賴參考
@../CLAUDE.md
@../../Shared/Services/CLAUDE.md