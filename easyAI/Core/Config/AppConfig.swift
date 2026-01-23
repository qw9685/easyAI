//
//  Config.swift
//  EasyAI
//
//  Created by cc on 2026
//

import Foundation

struct AppConfig {
    private static let infoPlistAPIKey = "OPENROUTER_API_KEY"

    static var apiKey: String {
        let storedKey = SecretsStore.shared.apiKey
        if !storedKey.isEmpty {
            return storedKey
        }
        return Bundle.main.object(forInfoDictionaryKey: infoPlistAPIKey) as? String ?? ""
    }
}
