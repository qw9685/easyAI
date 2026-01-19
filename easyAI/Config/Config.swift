//
//  Config.swift
//  EasyAI
//
//  Created on 2024
//

import Foundation

struct Config {
    // MARK: - OpenRouter API Key
    //
    // 建议：实际项目中应该使用环境变量或 Keychain 来安全存储 API Key，
    // 这里为了 Demo 简化成常量配置。
    
    /// OpenRouter Key
    /// 获取方式：访问 https://openrouter.ai 注册账号，在 Keys 页面创建 Key
    static let openRouterAPIKey: String = "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"
    
    /// 兼容旧代码：将 apiKey 映射为 OpenRouter 的 Key
    static let apiKey: String = openRouterAPIKey
    
    // 注意：useMockData、enableStream 和 maxTokens 现在由 ConfigManager 管理
    // 请使用 Config.useMockData、Config.enableStream 和 Config.maxTokens 访问
    // 这些属性在 ConfigManager.swift 的扩展中定义
}
