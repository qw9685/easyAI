//
//  ModelFallbackPolicy.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 根据错误类型和预算策略给出模型 fallback 序列
//

import Foundation

struct ModelFallbackPolicy {
    func nextModel(
        currentModel: AIModel,
        availableModels: [AIModel],
        attemptIndex: Int,
        category: ChatErrorCategory,
        budgetMode: FallbackBudgetMode,
        triedModelIds: Set<String>,
        requiresMultimodal: Bool
    ) -> AIModel? {
        guard category.isRetryable || category == .modelNotFound || category == .invalidModel || category == .modelNotSupportMultimodal else {
            return nil
        }

        let maxAttempts = max(1, AppConfig.fallbackMaxRetries)
        guard attemptIndex < maxAttempts else { return nil }

        let candidates = rankedCandidates(
            basedOn: currentModel,
            availableModels: availableModels,
            budgetMode: budgetMode,
            requiresMultimodal: requiresMultimodal
        )

        return candidates.first(where: { !triedModelIds.contains($0.id) })
    }

    private func rankedCandidates(
        basedOn currentModel: AIModel,
        availableModels: [AIModel],
        budgetMode: FallbackBudgetMode,
        requiresMultimodal: Bool
    ) -> [AIModel] {
        let filtered = availableModels.filter { model in
            guard model.id != currentModel.id else { return false }
            if requiresMultimodal {
                return model.supportsMultimodal
            }
            return true
        }

        switch budgetMode {
        case .freeFirst:
            return filtered.sorted { lhs, rhs in
                if lhs.isFree != rhs.isFree {
                    return lhs.isFree && !rhs.isFree
                }
                return compareCost(lhs, rhs)
            }
        case .costEffective:
            return filtered.sorted(by: compareCost)
        case .qualityFirst:
            return filtered.sorted { lhs, rhs in
                let lhsScore = qualityScore(model: lhs)
                let rhsScore = qualityScore(model: rhs)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return compareCost(lhs, rhs)
            }
        }
    }

    private func compareCost(_ lhs: AIModel, _ rhs: AIModel) -> Bool {
        let lhsCost = promptPlusCompletionCost(lhs)
        let rhsCost = promptPlusCompletionCost(rhs)
        if lhsCost != rhsCost {
            return lhsCost < rhsCost
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func promptPlusCompletionCost(_ model: AIModel) -> Double {
        let unknownCost = Double.greatestFiniteMagnitude / 4
        let prompt = parsePrice(model.pricing?.prompt) ?? unknownCost
        let completion = parsePrice(model.pricing?.completion) ?? unknownCost
        return prompt + completion
    }

    private func parsePrice(_ raw: String?) -> Double? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let normalized = raw
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        return Double(normalized)
    }

    private func qualityScore(model: AIModel) -> Int {
        var score = 0
        if let context = model.contextLength {
            if context >= 1_000_000 {
                score += 4
            } else if context >= 200_000 {
                score += 3
            } else if context >= 64_000 {
                score += 2
            } else if context >= 16_000 {
                score += 1
            }
        }

        if model.supportsMultimodal {
            score += 1
        }

        if !model.isFree {
            score += 1
        }

        return score
    }
}
