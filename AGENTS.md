# Translation iOS App - 翻譯批改應用

## 專案概述
SwiftUI iOS應用，提供中英翻譯批改、錯誤高亮、多工作區、題庫、單字卡複習功能。

## 核心架構原則
- 使用SwiftUI和iOS 18+ API
- Feature模組化架構：Workspace、Chat、Flashcards、Saved、Settings、Calendar、Bank
- 統一DesignSystem元件系統
- 與translation-backend API整合

## 設計系統準則（Design System Guidelines）

### 設計理念
- **簡約優雅**：去除過度裝飾，保持界面清爽
- **細邊框系統**：使用 hairline/thin/regular 三級邊框，避免厚重填色
- **輕盈色彩**：減少「重」顏色使用，偏好透明度調節
- **視覺層級**：透過間距和邊框建立層次，而非依賴背景色

### UI元件設計規範

#### 1. 按鈕系統（Buttons）
```swift
// 統一使用參數化 DSButton
.buttonStyle(DSButton(style: .primary, size: .full))     // 主要按鈕（漸層）
.buttonStyle(DSButton(style: .secondary, size: .full))   // 次要按鈕（邊框）
.buttonStyle(DSButton(style: .secondary, size: .compact)) // 緊湊按鈕

// 特殊用途保留獨立樣式
.buttonStyle(DSPrimaryCircleButton())  // 圓形按鈕
.buttonStyle(DSCardLinkStyle())        // 卡片連結
.buttonStyle(DSCalendarCellStyle(...)) // 日曆格子
```

#### 2. 卡片系統（Cards）
```swift
// 標準卡片：細邊框 + 微陰影
DSCard { content }

// 外框卡片：僅邊框無填色
DSOutlineCard { content }

// 卡片標題：統一使用
DSCardTitle(
    titleKey: "title",
    subtitleKey: "subtitle",
    systemImage: "icon"
)
```

#### 3. 邊框寬度（Border Width）
```swift
DS.BorderWidth.hairline  // >=0.5pt - 最細邊框，依裝置像素自動調整
DS.BorderWidth.thin      // 0.8pt - 輕量邊框（標籤、徽章）
DS.BorderWidth.regular   // 1.0pt - 標準邊框（輸入框、按鈕）
DS.BorderWidth.emphatic  // 1.6pt - 強調邊框
```

#### 4. 間距系統（Spacing）
```swift
DS.Spacing.xs   // 6pt  - 極小間距
DS.Spacing.xs2  // 8pt  - 微小間距
DS.Spacing.sm   // 10pt - 標準小間距
DS.Spacing.sm2  // 12pt - 小至中間距
DS.Spacing.md2  // 14pt - 中間距
DS.Spacing.md   // 16pt - 標準中間距
DS.Spacing.lg   // 24pt - 大間距
DS.Spacing.xl   // 32pt - 特大間距
```

#### 5. 尺寸與容器（Metrics）
```swift
DS.Metrics.progressBarHeight      // 標準進度條高度
DS.Metrics.scoreValueMinWidth     // 成績數字最小寬度
DS.Metrics.popoverMaxWidth        // 彈出視窗最大寬度
DS.Metrics.sectionDividerWidth    // 區段分隔線預設寬度
DS.Metrics.miniPlayerProgressHeight // 迷你播放器進度條高度
```

#### 6. 圓角系統（Radius）
```swift
DS.Radius.xs  // 6pt  - 迷你圓角（分隔、細部元件）
DS.Radius.sm  // 8pt  - 小圓角（標籤、小按鈕）
DS.Radius.md  // 12pt - 中圓角（輸入框、按鈕）
DS.Radius.md2 // 14pt - 中大圓角（模組化卡片）
DS.Radius.lg  // 16pt - 大圓角（主要卡片、模態）
```

#### 7. 色彩與透明度（Colors & Opacity）
```swift
// 主色系
DS.Palette.primary        // 品牌主色
DS.Palette.onPrimary      // 主色上文字
DS.Palette.surface        // 卡片背景
DS.Palette.background     // 頁面背景
DS.Palette.border         // 邊框顏色

// 語意色彩
DS.Palette.success
DS.Palette.warning
DS.Palette.error

// 透明度層級
DS.Opacity.hairline  // 0.15 - 髮絲線
DS.Opacity.border    // 0.2  - 邊框
DS.Opacity.fill      // 0.08 - 填充
DS.Opacity.strong    // 0.4  - 強調
```

#### 8. 動畫系統（Animations）
```swift
DS.AnimationToken.subtle   // 0.2s - 細微變化
DS.AnimationToken.snappy   // 0.3s - 快速回饋
DS.AnimationToken.smooth   // 0.4s - 平滑過渡
```

#### 9. 字型系統（Typography）
```swift
DS.Font.largeTitle  // 大標題
DS.Font.title       // 標題
DS.Font.section     // 章節標題
DS.Font.bodyEmph    // 強調正文
DS.Font.body        // 正文
DS.Font.caption     // 說明文字
DS.Font.labelSm     // 小標籤
DS.Font.serifBody   // 襯線正文（日曆用）
```

### 實作準則

#### 視覺層級建立
1. **避免填色背景**：優先使用邊框定義區域
2. **透明度層級**：用透明度而非實色建立層次
3. **留白設計**：善用間距創造呼吸感
4. **邊框分層**：不同寬度邊框表達重要性

#### 元件開發流程
1. **先查找現有元件**：檢查 DesignSystem/Components/
2. **參數化優於複製**：相似元件應合併為參數化版本
3. **遵循命名規範**：DS 前綴標示設計系統元件
4. **保持一致性**：使用設計系統 token，避免魔術數字

#### 狀態表達方式
```swift
// 選中狀態：邊框加粗 + 主色
.stroke(isSelected ? DS.Palette.primary : DS.Palette.border,
        lineWidth: isSelected ? DS.BorderWidth.regular : DS.BorderWidth.thin)

// 按壓回饋：縮放 + 透明度
.scaleEffect(isPressed ? 0.96 : 1)
.opacity(isPressed ? 0.9 : 1)

// 停用狀態：降低透明度
.opacity(isDisabled ? 0.5 : 1)
```

#### 響應式設計
```swift
// 條件修飾符
.conditionalModifier(condition) { view in
    view.modifier(...)
}

// 動態尺寸
.frame(maxWidth: .infinity)  // 填滿可用寬度
.frame(minHeight: 100)        // 最小高度限制
```

### 性能優化

1. **避免過度動畫**：限制同時動畫數量
2. **懶加載**：使用 LazyVStack/LazyHStack
3. **條件渲染**：用 @ViewBuilder 和 if-else
4. **記憶體管理**：避免循環引用，適時使用 weak/unowned

## 編碼規範
- Swift 6語言特性和現代API
- async/await concurrency模式
- 遵循Apple Human Interface Guidelines
- 不添加註解除非明確要求
- 使用SF Symbols作為圖標
- 優先使用existing patterns和元件
- 保持View簡潔，超過時拆分子視圖
- 使用 @State/@Binding 管理狀態
- 優先 struct over class

## 專案結構
- `ios/translation/App/`: App生命週期、全域設定
- `ios/translation/Features/`: 依領域拆分的功能模組
- `ios/translation/DesignSystem/`: 設計系統與共用UI元件
- `ios/translation/Shared/`: 跨模組共享的模型、服務、工具
- `ios/translation/Resources/`: 資源與在地化字串

## 測試與建置
- 建置命令: `xcodebuild -project ios/translation.xcodeproj -scheme translation -configuration Debug build`
- 測試命令: `xcodebuild -project ios/translation.xcodeproj -scheme translation -destination 'platform=iOS Simulator,name=iPhone 16' test`
- 簡化輸出: `2>&1 | tail -3` 僅顯示最後狀態

## Git 提交規範
- 使用 Conventional Commits 格式
- feat: 新功能
- fix: 修復錯誤
- refactor: 重構代碼
- style: 格式調整
- docs: 文檔更新
- test: 測試相關
- chore: 其他維護

## 檔案參考
@README.md
@docs/architecture.md
@AGENTS.md
