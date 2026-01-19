//
//  AIModel.swift
//  EasyAI
//
//  Created on 2024
//

import Foundation

struct AIModel: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let provider: ModelProvider
    /// 对应服务商真实的模型 ID（有些平台会带前缀，如 openrouter 的 `deepseek/deepseek-chat`）
    let apiModel: String
    
    static let availableModels: [AIModel] = [
        AIModel(
            id: "openrouter-llama-3.1-8b",
            name: "Llama 3.1 8B",
            description: "OpenRouter 免费路由，部分有赞助额度",
            provider: .openrouter,
            apiModel: "meta-llama/llama-3.1-8b-instruct"
        ),
        AIModel(
            id: "openrouter-mistral-7b",
            name: "Mistral 7B",
            description: "OpenRouter 免费路由，Mistral 开源模型",
            provider: .openrouter,
            apiModel: "mistralai/mistral-7b-instruct"
        ),
        AIModel(
            id: "openrouter-qwen-2.5-7b",
            name: "Qwen 2.5 7B",
            description: "OpenRouter 免费路由，中文能力强的开源模型",
            provider: .openrouter,
            apiModel: "qwen/qwen-2.5-7b-instruct"
        )
    ]
    
    static let defaultModel: AIModel = {
        if let first = availableModels.first {
            return first
        }
        return AIModel(
            id: "openrouter-llama-3.1-8b",
            name: "Llama 3.1 8B",
            description: "OpenRouter 免费路由",
            provider: .openrouter,
            apiModel: "meta-llama/llama-3.1-8b-instruct"
        )
    }()
}

enum ModelProvider: String, Codable, Hashable {
    /// OpenRouter（聚合多个模型，其中不少有赞助/免费用量）
    case openrouter
}

