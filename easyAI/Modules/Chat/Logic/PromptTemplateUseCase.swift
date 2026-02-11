//
//  PromptTemplateUseCase.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - Prompt 模板查询与推荐模型匹配
//

import Foundation

final class PromptTemplateUseCase {
    private let repository: PromptTemplateRepositoryProtocol

    init(repository: PromptTemplateRepositoryProtocol = PromptTemplateRepository.shared) {
        self.repository = repository
    }

    func fetchTemplates() -> [PromptTemplate] {
        repository.fetchTemplates()
    }

    func findRecommendedModel(for template: PromptTemplate, availableModels: [AIModel]) -> AIModel? {
        if let matched = availableModels.first(where: { $0.id == template.recommendedModelId }) {
            return matched
        }
        return availableModels.first(where: { $0.apiModel == template.recommendedModelId })
    }
}

