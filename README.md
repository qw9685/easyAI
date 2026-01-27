# EasyAI - iOS AI聊天应用

一个使用 SwiftUI 开发的现代化 iOS AI 聊天应用，通过 OpenRouter API 支持多个主流 AI 模型，提供流畅的聊天体验。

## ✨ 功能特性

- 🎨 **现代化 SwiftUI 界面** - 渐变背景、圆角气泡、流畅动画
- 🤖 **多模型支持** - 通过 OpenRouter 支持多个 AI 模型（Claude、GPT、Gemini 等）
- 💬 **流式响应** - 实时流式输出，打字机效果展示
- 🖼️ **多模态输入** - 支持图片输入，AI 可以理解图片内容
- 🔍 **智能模型选择** - 可搜索和筛选不同 AI 模型
- ⭐ **模型管理增强** - 收藏模型、记住上次选择、价格/上下文长度展示、仅免费筛选
- 🗂️ **对话历史管理** - 多会话列表、重命名、置顶、删除
- 💾 **本地持久化** - 会话与消息本地保存，冷启动可恢复
- 📱 **原生 iOS 体验** - 完全使用 SwiftUI 构建，适配 iOS 15+
- ⚙️ **灵活配置** - 支持自定义 API Key 和模型参数

## 📁 项目结构

```
easyAI/
├── easyAIApp.swift              # 应用入口
├── Core/
│   ├── Config/                  # 配置与偏好
│   ├── Networking/              # OpenRouter 网络层与 SSE 解析
│   ├── Repositories/            # 数据仓库
│   ├── Security/                # Keychain 存储
│   └── UI/                      # 共享 UI 组件
├── Features/
│   ├── Chat/                    # 聊天主功能
│   ├── Models/                  # 模型选择功能
│   └── Settings/                # 设置界面
└── Models/
    ├── AIModel.swift            # AI模型数据模型
    ├── Message.swift            # 消息数据模型
    └── MediaContent.swift       # 媒体内容模型
```

## 设置步骤

### 1. 配置 API Key

推荐方式：在 App 的“设置”页面录入 API Key，应用会存入 Keychain。

备用方式：在 `Info.plist` 中添加键 `OPENROUTER_API_KEY` 并填入 Key。

> **获取 API Key**: 访问 [OpenRouter.ai](https://openrouter.ai/) 注册并获取 API Key

**安全提示**：不要将 API Key 提交到版本控制系统。

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
- 支持搜索与多维筛选（输入/输出类型、仅免费、仅收藏）
- 显示模型详细信息（多模态支持、输入/输出类型、价格、上下文长度）
- 收藏模型并置顶显示，记住上次选择的模型

### 对话历史与持久化
- 支持多会话列表（重命名、置顶、删除）
- 自动以首条用户消息生成会话标题
- 消息与会话使用本地数据库持久化

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

- [ ] 搜索与导出（消息搜索、导出为文本/Markdown/JSON）
- [ ] 多模态扩展（PDF/音频输入、文件预览与大小限制）
- [ ] 语音输入/输出（语音转文字、TTS 播放）
- [ ] 使用统计（调用次数、token 估算、模型花费）
- [ ] 工具调用（函数调用/工具选择）
- [ ] 多账号/多 Key（切换 Key、按模型配置）
- [ ] 消息编辑与重试（编辑上一条、重新生成、停止生成）

## 📄 许可证

MIT License

## 🙏 致谢

- [OpenRouter](https://openrouter.ai/) - 提供统一的 AI 模型 API 接口
- SwiftUI - Apple 的声明式 UI 框架

---

**⭐ 如果这个项目对你有帮助，请给个 Star！**
