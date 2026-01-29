//
//  Config.swift
//  EasyAI
//
//  创建于 2026
//


import Foundation

struct AppConfig {
    private static let infoPlistAPIKey = "OPENROUTER_API_KEY"
    static let requestTimeoutSeconds: TimeInterval = 20

    static var apiKey: String {
        let storedKey = SecretsStore.shared.apiKey
        if !storedKey.isEmpty {
            return storedKey
        }
        return Bundle.main.object(forInfoDictionaryKey: infoPlistAPIKey) as? String ?? ""
    }
}
