import Foundation

struct RoutingDecision {
    let model: AIModel
    let reason: String
}

final class ModelRoutingEngine {
    func recommendModel(
        currentModel: AIModel?,
        availableModels: [AIModel],
        intent: TaskIntent,
        budgetMode: BudgetMode
    ) -> RoutingDecision? {
        let candidates = availableModels.filter { model in
            if intent.requiresVision && !model.supportsMultimodal {
                return false
            }
            return true
        }

        guard !candidates.isEmpty else { return nil }

        let scored = candidates.map { model in
            (model: model, score: score(model: model, intent: intent, budgetMode: budgetMode))
        }

        guard let best = scored.max(by: { $0.score < $1.score }) else { return nil }

        if let currentModel, currentModel.id == best.model.id {
            return nil
        }

        let reason = "智能路由：\(intent.type.rawValue) · \(budgetMode.title)"
        return RoutingDecision(model: best.model, reason: reason)
    }

    private func score(model: AIModel, intent: TaskIntent, budgetMode: BudgetMode) -> Double {
        var value: Double = 0

        if model.supportsMultimodal {
            value += intent.requiresVision ? 35 : 4
        }

        if let contextLength = model.contextLength {
            if intent.estimatedContextChars > 12000 {
                value += Double(contextLength) / 4000
            } else {
                value += Double(contextLength) / 12000
            }
        }

        let lowerName = (model.name + " " + model.apiModel).lowercased()
        switch intent.type {
        case .coding:
            if lowerName.contains("code") || lowerName.contains("coder") || lowerName.contains("deepseek") || lowerName.contains("qwen") {
                value += 18
            }
        case .translation:
            if lowerName.contains("gpt") || lowerName.contains("claude") || lowerName.contains("gemini") {
                value += 10
            }
        case .summarization:
            if lowerName.contains("flash") || lowerName.contains("haiku") {
                value += 8
            }
        case .writing:
            if lowerName.contains("claude") || lowerName.contains("gpt") {
                value += 10
            }
        case .vision:
            if lowerName.contains("vision") || lowerName.contains("vl") || lowerName.contains("gemini") {
                value += 20
            }
        case .general:
            break
        }

        let unknownPrice = 1.0
        let promptPrice = parsePrice(model.pricing?.prompt) ?? unknownPrice
        let completionPrice = parsePrice(model.pricing?.completion) ?? unknownPrice
        let totalPrice = promptPrice + completionPrice

        switch budgetMode {
        case .freeFirst:
            value += model.isFree ? 30 : max(0, 12 - totalPrice * 100000)
        case .costEffective:
            value += max(0, 18 - totalPrice * 70000)
            if let contextLength = model.contextLength {
                value += Double(contextLength) / 25000
            }
        case .qualityFirst:
            value += qualityBoost(for: lowerName)
            if !model.isFree {
                value += 6
            }
        }

        return value
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

    private func qualityBoost(for normalizedName: String) -> Double {
        if normalizedName.contains("gpt-4") || normalizedName.contains("o3") || normalizedName.contains("claude-3") || normalizedName.contains("claude 3") {
            return 22
        }
        if normalizedName.contains("gemini") || normalizedName.contains("sonnet") {
            return 16
        }
        return 8
    }
}
