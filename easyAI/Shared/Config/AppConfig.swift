//
//  Config.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 应用配置读取（API Key 等）
//
//


import Foundation

struct AppConfig {
    private static let infoPlistAPIKey = "OPENROUTER_API_KEY"
    static let placeholderAPIKey = "YOUR_OPENAI_API_KEY_HERE"
    static let requestTimeoutSeconds: TimeInterval = 20

    static var apiKey: String {
        let storedKey = SecretsStore.shared.apiKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !storedKey.isEmpty {
            return storedKey
        }
        return (Bundle.main.object(forInfoDictionaryKey: infoPlistAPIKey) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var hasUsableAPIKey: Bool {
        isUsableAPIKey(apiKey)
    }

    static func isUsableAPIKey(_ apiKey: String) -> Bool {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedKey.isEmpty && trimmedKey != placeholderAPIKey
    }
}
