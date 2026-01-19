# EasyAI - iOS AI聊天应用

一个使用 SwiftUI 开发的现代化 iOS AI 聊天应用，通过 OpenRouter API 支持多个主流 AI 模型，提供流畅的聊天体验。

## ✨ 功能特性

- 🎨 **现代化 SwiftUI 界面** - 渐变背景、圆角气泡、流畅动画
- 🤖 **多模型支持** - 通过 OpenRouter 支持多个 AI 模型（Claude、GPT、Gemini 等）
- 💬 **流式响应** - 实时流式输出，打字机效果展示
- 🖼️ **多模态输入** - 支持图片输入，AI 可以理解图片内容
- 🔍 **智能模型选择** - 可搜索和筛选不同 AI 模型
- 📱 **原生 iOS 体验** - 完全使用 SwiftUI 构建，适配 iOS 15+
- ⚙️ **灵活配置** - 支持自定义 API Key 和模型参数

## 📁 项目结构

```
easyAI/
├── easyAIApp.swift              # 应用入口
├── Models/
│   ├── AIModel.swift            # AI模型数据模型
│   ├── Message.swift            # 消息数据模型
│   └── MediaContent.swift       # 媒体内容模型
├── Services/
│   ├── OpenRouterStreamService.swift  # OpenRouter流式API服务
│   └── MessageConverter.swift   # 消息格式转换
├── ViewModels/
│   ├── ChatViewModel.swift      # 聊天视图模型
│   └── ConfigManager.swift      # 配置管理器
├── Views/
│   ├── ChatView.swift           # 主聊天界面
│   ├── ModelSelectorView.swift  # 模型选择器
│   ├── SettingsView.swift       # 设置界面
│   ├── TypewriterTextKitView.swift  # 打字机效果视图
│   └── ScrollViewBounceModifier.swift  # 滚动视图修饰符
└── Config/
    └── Config.swift             # 配置文件
```

## 设置步骤

### 1. 配置 API Key

打开 `easyAI/Config/Config.swift` 文件，将 `YOUR_OPENAI_API_KEY_HERE` 替换为您的 OpenRouter API Key：

```swift
static let apiKey: String = "sk-or-v1-your-actual-api-key-here"
```

> **获取 API Key**: 访问 [OpenRouter.ai](https://openrouter.ai/) 注册并获取 API Key

**安全提示**：在生产环境中，建议使用环境变量或 iOS Keychain 来存储 API Key，不要将 API Key 提交到版本控制系统。

### 2. 打开项目

1. 使用 Xcode 打开 `easyAI.xcodeproj`
2. 或者参考 `QUICK_START.md` 了解如何从零开始设置项目

### 3. 运行项目

在 Xcode 中选择目标设备或模拟器，然后点击运行按钮 ▶️ 或按 `⌘ + R`

## 🎯 核心功能说明

### 流式响应与打字机效果
- 支持 Server-Sent Events (SSE) 流式响应
- 实时显示 AI 回复，带有流畅的打字机动画效果
- 自动滚动跟随最新消息

### 多模态支持
- 支持图片输入（JPEG、PNG、GIF、WebP）
- AI 可以理解和分析图片内容
- 图片预览和删除功能

### 模型管理
- 从 OpenRouter API 动态获取可用模型列表
- 支持搜索和筛选模型
- 显示模型详细信息（多模态支持、输入/输出类型等）

## 📋 系统要求

- iOS 15.0+
- Swift 5.5+
- SwiftUI
- Xcode 14.0+

## ⚠️ 注意事项

1. **API 费用**：使用 OpenRouter API 会产生费用，部分模型有免费额度，请注意 API 使用量
2. **网络连接**：应用需要网络连接才能调用 API
3. **API 限制**：请注意 OpenRouter API 的速率限制和配额限制
4. **API Key 安全**：请勿将 API Key 提交到公开仓库

## 🚀 未来计划

- [ ] 添加消息持久化存储（Core Data 或 SQLite）
- [ ] 实现对话历史管理
- [ ] 添加语音输入/输出
- [ ] 优化 UI 设计和动画效果
- [ ] 添加暗黑模式支持
- [ ] 实现 API Key 的安全存储（Keychain）
- [ ] 支持更多媒体类型（视频、音频、PDF等）
- [ ] 添加消息导出功能

## 📄 许可证

MIT License

## 🙏 致谢

- [OpenRouter](https://openrouter.ai/) - 提供统一的 AI 模型 API 接口
- SwiftUI - Apple 的声明式 UI 框架

---

**⭐ 如果这个项目对你有帮助，请给个 Star！**

