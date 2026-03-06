//
//  ModelSelectionCoordinator.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 加载模型并记住选择
//  - 校验多模态支持
//

import Foundation

nonisolated enum ModelSelectionFailureReason: Equatable, Sendable {
    case missingAPIKey
    case modelUnavailable
    case modelNotSupportMultimodal
}

nonisolated enum ModelSelectionValidationResult {
    case ready(AIModel)
    case error(message: String, reason: ModelSelectionFailureReason)
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

    func validateSendPrerequisites(
        apiKey: String = AppConfig.apiKey,
        useMockData: Bool = AppConfig.useMockData,
        selectedModel: AIModel?,
        availableModels: [AIModel],
        userMessage: Message
    ) -> ModelSelectionValidationResult {
        if !useMockData, !AppConfig.isUsableAPIKey(apiKey) {
            return .error(
                message: "请先在设置中填写有效的 OpenRouter API Key",
                reason: .missingAPIKey
            )
        }

        guard let model = selectedModel ?? availableModels.first else {
            let message: String
            if useMockData {
                message = "当前没有可用模型，请先在设置中选择模型。"
            } else {
                message = "当前没有可用模型，请检查 API Key、网络连接，或在设置中重新加载模型。"
            }
            return .error(message: message, reason: .modelUnavailable)
        }

        if userMessage.hasMedia && !model.supportsMultimodal {
            let message = """
⚠️ 当前选择的模型（\(model.name)）不支持图片输入。

请切换到支持多模态的模型，例如：
• GPT-4 Vision
• Claude 3 Sonnet
• Gemini Pro Vision
• Gemini 2.0 Flash
"""
            return .error(message: message, reason: .modelNotSupportMultimodal)
        }

        return .ready(model)
    }
}
