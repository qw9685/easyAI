//
//  ModelSelectionCoordinator.swift
//  EasyAI
//
//  创建于 2026
//

import Foundation

enum ModelSelectionValidationResult {
    case ready(AIModel)
    case error(message: String, reason: String)
}

final class ModelSelectionCoordinator {
    private let modelRepository: ModelRepositoryProtocol

    init(modelRepository: ModelRepositoryProtocol) {
        self.modelRepository = modelRepository
    }

    func persistSelection(_ model: AIModel?) {
        AppConfig.selectedModelId = model?.id
    }

    func loadModels(forceRefresh: Bool) async -> (models: [AIModel], selected: AIModel?) {
        let models = await modelRepository.fetchModels(filter: .all, forceRefresh: forceRefresh)

        let selected: AIModel?
        if let savedId = AppConfig.selectedModelId,
           let savedModel = models.first(where: { $0.id == savedId }) {
            selected = savedModel
        } else {
            selected = models.first
        }

        return (models: models, selected: selected)
    }

    func validateSelection(selectedModel: AIModel?, userMessage: Message) -> ModelSelectionValidationResult {
        guard let model = selectedModel else {
            return .error(message: "⚠️ 模型列表正在加载中，请稍候再试。", reason: "model_not_ready")
        }

        if userMessage.hasMedia && !model.supportsMultimodal {
            let message =
                "⚠️ 当前选择的模型（\(model.name)）不支持图片输入。\n\n请切换到支持多模态的模型，例如：\n• GPT-4 Vision\n• Claude 3 Sonnet\n• Gemini Pro Vision\n• Gemini 2.0 Flash"
            return .error(message: message, reason: "model_not_support_multimodal")
        }

        return .ready(model)
    }
}

