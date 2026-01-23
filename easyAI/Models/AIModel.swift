//
//  AIModel.swift
//  EasyAI
//
//  Created by cc on 2026
//

import Foundation

struct AIModel: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let provider: ModelProvider
    /// 对应服务商真实的模型 ID（有些平台会带前缀，如 openrouter 的 `deepseek/deepseek-chat`）
    let apiModel: String
    /// 是否支持多模态输入（图片、视频等）
    let supportsMultimodal: Bool
    /// 支持的输入类型（text, image, file, audio, video）
    let inputModalities: [String]
    /// 支持的输出类型（text, image, embeddings）
    let outputModalities: [String]
    
    init(id: String, name: String, description: String, provider: ModelProvider, apiModel: String, supportsMultimodal: Bool = false, inputModalities: [String] = [], outputModalities: [String] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.provider = provider
        self.apiModel = apiModel
        self.supportsMultimodal = supportsMultimodal
        self.inputModalities = inputModalities
        self.outputModalities = outputModalities
    }
    
    // 数据获取由 ModelRepository 负责，避免模型类型直接依赖网络层。
}

enum ModelProvider: String, Codable, Hashable {
    /// OpenRouter（聚合多个模型，其中不少有赞助/免费用量）
    case openrouter
}
