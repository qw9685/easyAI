//
//  ModelRepository.swift
//  EasyAI
//
//  Created by cc on 2026
//

import Foundation

enum ModelFilter {
    case all
    case freeOnly
}

protocol ModelRepositoryProtocol {
    func fetchModels(filter: ModelFilter) async -> [AIModel]
}

final class ModelRepository: ModelRepositoryProtocol {
    static let shared = ModelRepository()

    private let service: ChatServiceProtocol

    init(service: ChatServiceProtocol = OpenRouterChatService.shared) {
        self.service = service
    }

    func fetchModels(filter: ModelFilter) async -> [AIModel] {
        do {
            let models = try await service.fetchModels()
            let filtered = applyFilter(models, filter: filter)
            return filtered.map { mapToAIModel($0) }
        } catch {
            print("[ModelRepository] ⚠️ Failed to fetch models: \(error)")
            return []
        }
    }

    private func applyFilter(_ models: [OpenRouterModelInfo], filter: ModelFilter) -> [OpenRouterModelInfo] {
        switch filter {
        case .all:
            return models
        case .freeOnly:
            return models.filter { model in
                guard let pricing = model.pricing else { return true }
                let promptPrice = Double(pricing.prompt ?? "0") ?? 0
                let completionPrice = Double(pricing.completion ?? "0") ?? 0
                return promptPrice == 0 && completionPrice == 0
            }
        }
    }

    private func mapToAIModel(_ modelInfo: OpenRouterModelInfo) -> AIModel {
        let inputModalities = modelInfo.architecture?.inputModalities ?? []
        let outputModalities = modelInfo.architecture?.outputModalities ?? []
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
}
