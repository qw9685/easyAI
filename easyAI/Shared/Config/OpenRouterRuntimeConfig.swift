//
//  OpenRouterRuntimeConfig.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 统一 OpenRouter 运行时配置读取
//

import Foundation

struct OpenRouterRuntimeConfig {
    let apiKey: String
    let timeoutSeconds: TimeInterval
    let maxTokens: Int

    static func current() -> OpenRouterRuntimeConfig {
        OpenRouterRuntimeConfig(
            apiKey: AppConfig.apiKey,
            timeoutSeconds: AppConfig.requestTimeoutSeconds,
            maxTokens: AppConfig.maxTokens > 0 ? AppConfig.maxTokens : 1000
        )
    }
}
