//
//  ModelRepository.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 模型列表获取与缓存
//
//


import Foundation

enum ModelFilter {
    case all
    case freeOnly
}

protocol ModelRepositoryProtocol {
    func fetchModels(filter: ModelFilter, forceRefresh: Bool) async -> [AIModel]
}

final class ModelRepository: ModelRepositoryProtocol {
    static let shared = ModelRepository()

    private let service: ChatServiceProtocol
    private let cacheRepository: ModelCacheRepository
    private let cacheTTL: TimeInterval = 60 * 60 * 12

    init(service: ChatServiceProtocol = OpenRouterChatService.shared,
         cacheRepository: ModelCacheRepository = ModelCacheRepository.shared) {
        self.service = service
        self.cacheRepository = cacheRepository
    }

    func fetchModels(filter: ModelFilter, forceRefresh: Bool = false) async -> [AIModel] {
        if !forceRefresh, let cached = cacheRepository.readCache(),
           Date().timeIntervalSince(cached.updatedAt) < cacheTTL {
            let filtered = applyFilter(cached.models, filter: filter)
            return filtered.map { mapToAIModel($0) }
        }

        do {
            let models = try await service.fetchModels()
            if models.isEmpty, let cached = cacheRepository.readCache() {
                let filtered = applyFilter(cached.models, filter: filter)
                return filtered.map { mapToAIModel($0) }
            }

            if !models.isEmpty {
                cacheRepository.writeCache(models: models)
            }
            let filtered = applyFilter(models, filter: filter)
            return filtered.map { mapToAIModel($0) }
        } catch {
            RuntimeTools.AppDiagnostics.warn("ModelRepository", "Failed to fetch models: \(error)")
            if let cached = cacheRepository.readCache() {
                let filtered = applyFilter(cached.models, filter: filter)
                return filtered.map { mapToAIModel($0) }
            }
            return []
        }
    }

    private func applyFilter(_ models: [OpenRouterModelInfo], filter: ModelFilter) -> [OpenRouterModelInfo] {
        switch filter {
        case .all:
            return models
        case .freeOnly:
            return models.filter { model in
                guard let pricing = model.pricing else { return false }
                guard let promptPrice = DataTools.ValueParser.decimal(from: pricing.prompt),
                      let completionPrice = DataTools.ValueParser.decimal(from: pricing.completion) else {
                    return false
                }
                return promptPrice == 0 && completionPrice == 0
            }
        }
    }

    private func mapToAIModel(_ modelInfo: OpenRouterModelInfo) -> AIModel {
        let inputModalities = modelInfo.architecture?.inputModalities ?? []
        let outputModalities = modelInfo.architecture?.outputModalities ?? []
        let supportsMultimodal = inputModalities.contains { $0.lowercased() == "image" }

        return AIModel(
            id: "openrouter-\(modelInfo.id.replacingOccurrences(of: "/", with: "-"))",
            name: modelInfo.name ?? modelInfo.id,
            description: modelInfo.description ?? "OpenRouter 模型",
            provider: .openrouter,
            apiModel: modelInfo.id,
            supportsMultimodal: supportsMultimodal,
            inputModalities: inputModalities,
            outputModalities: outputModalities,
            contextLength: modelInfo.contextLength,
            pricing: ModelPricing(prompt: modelInfo.pricing?.prompt,
                                  completion: modelInfo.pricing?.completion)
        )
    }
}
