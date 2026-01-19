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
    
    /// 从 OpenRouter API 获取所有可用模型
    static func fetchAllModels() async -> [AIModel] {
        do {
            let models = try await OpenRouterService.shared.fetchModels()
            
            // 转换为 AIModel 格式（获取所有模型）
            return models.map { modelInfo in
                // 获取输入和输出类型
                let inputModalities = modelInfo.architecture?.inputModalities ?? []
                let outputModalities = modelInfo.architecture?.outputModalities ?? []
                
                // 检查模型是否支持多模态（通过检查 input_modalities 是否包含 "image"）
                let supportsMultimodal = inputModalities.contains("image")
                
                return AIModel(
                    id: "openrouter-\(modelInfo.id.replacingOccurrences(of: "/", with: "-"))",
                    name: modelInfo.name ?? modelInfo.id,
                    description: modelInfo.description ?? "OpenRouter 模型",
                    provider: .openrouter,
                    apiModel: modelInfo.id,
                    supportsMultimodal: supportsMultimodal,
                    inputModalities: inputModalities,
                    outputModalities: outputModalities
                )
            }
        } catch {
            print("[AIModel] ⚠️ Failed to fetch models from API: \(error)")
            // 如果获取失败，返回空数组
            return []
        }
    }
    
    /// 可用的模型列表（完全从API获取，不写死任何模型）
    static func availableModels() async -> [AIModel] {
        return await fetchAllModels()
    }
}

enum ModelProvider: String, Codable, Hashable {
    /// OpenRouter（聚合多个模型，其中不少有赞助/免费用量）
    case openrouter
}
