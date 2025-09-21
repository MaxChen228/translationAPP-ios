# Design System - 設計系統

## 核心原則
- 統一視覺語言和使用者體驗
- 模組化、可重用的UI元件
- 遵循Apple Human Interface Guidelines

## 主要元件
- `DesignSystem.swift`: 核心token (Palette、Spacing、Radius、Animations)
- `Components/DS*.swift`: DS開頭的標準化元件
- `BannerCenter.swift`: 全域通知與錯誤顯示

## 使用規範
- **優先使用existing DS元件**，避免重複造輪子
- 保持視覺一致性：顏色、間距、圓角
- 支援特殊需求：髮絲線、細邊框、次要按鈕尺寸
- 字型透過`FontLoader.registerBundledFonts()`註冊

## 元件命名
- DS前綴標示設計系統元件
- 功能明確的命名：`DSButton`、`DSTextField`
- 避免過度客製化，維持通用性

## 擴展指引
- 新元件需考慮多場景使用
- 保持向後相容性
- 文件化新增的token或元件

## 檔案參考
@DesignSystem.swift
@Components/