import Foundation

enum ModelDecisionKit {
    static func inferTaskIntent(
        content: String,
        hasMedia: Bool,
        requestMessages: [Message]
    ) -> TaskIntent {
        let normalized = content.lowercased()
        let type: TaskType

        if hasMedia {
            type = .vision
        } else if normalized.contains("翻译") || normalized.contains("translate") {
            type = .translation
        } else if normalized.contains("总结") || normalized.contains("摘要") || normalized.contains("summary") {
            type = .summarization
        } else if normalized.contains("代码")
                    || normalized.contains("报错")
                    || normalized.contains("debug")
                    || normalized.contains("bug")
                    || normalized.contains("swift")
                    || normalized.contains("python")
                    || normalized.contains("javascript") {
            type = .coding
        } else if normalized.contains("写") || normalized.contains("文案") || normalized.contains("润色") {
            type = .writing
        } else {
            type = .general
        }

        let estimatedContextChars = requestMessages.reduce(0) { partial, message in
            partial + message.content.count
        }

        return TaskIntent(
            type: type,
            requiresVision: hasMedia,
            estimatedContextChars: estimatedContextChars,
            inputLength: content.count
        )
    }

    static func recommendModel(
        currentModel: AIModel?,
        availableModels: [AIModel],
        content: String,
        hasMedia: Bool,
        requestMessages: [Message],
        budgetMode: BudgetMode
    ) -> RoutingDecision? {
        let intent = inferTaskIntent(
            content: content,
            hasMedia: hasMedia,
            requestMessages: requestMessages
        )
        return recommendModel(currentModel: currentModel, availableModels: availableModels, intent: intent, budgetMode: budgetMode)
    }

    static func recommendModel(
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

    static func nextFallbackModel(
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

        let candidates = rankedFallbackCandidates(
            currentModel: currentModel,
            availableModels: availableModels,
            budgetMode: budgetMode,
            requiresMultimodal: requiresMultimodal
        )

        return candidates.first(where: { !triedModelIds.contains($0.id) })
    }

    static func shouldRetryFallback(for category: ChatErrorCategory) -> Bool {
        switch category {
        case .rateLimited:
            return AppConfig.fallbackRetryOnRateLimited
        case .timeout:
            return AppConfig.fallbackRetryOnTimeout
        case .serverUnavailable:
            return AppConfig.fallbackRetryOnServerUnavailable
        case .network:
            return AppConfig.fallbackRetryOnNetwork
        case .insufficientCredits, .invalidModel, .modelNotFound, .modelNotSupportMultimodal, .contextTooLong, .missingAPIKey, .cancelled:
            return false
        case .unknown:
            return false
        }
    }

    static func rankedFallbackCandidates(
        currentModel: AIModel,
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
                let lhsScore = fallbackQualityScore(model: lhs)
                let rhsScore = fallbackQualityScore(model: rhs)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return compareCost(lhs, rhs)
            }
        }
    }

    private static func score(model: AIModel, intent: TaskIntent, budgetMode: BudgetMode) -> Double {
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
        let promptPrice = DataTools.ValueParser.decimal(from: model.pricing?.prompt) ?? unknownPrice
        let completionPrice = DataTools.ValueParser.decimal(from: model.pricing?.completion) ?? unknownPrice
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
            value += routingQualityBoost(for: lowerName)
            if !model.isFree {
                value += 6
            }
        }

        return value
    }

    private static func routingQualityBoost(for normalizedName: String) -> Double {
        if normalizedName.contains("gpt-4") || normalizedName.contains("o3") || normalizedName.contains("claude-3") || normalizedName.contains("claude 3") {
            return 22
        }
        if normalizedName.contains("gemini") || normalizedName.contains("sonnet") {
            return 16
        }
        return 8
    }

    private static func compareCost(_ lhs: AIModel, _ rhs: AIModel) -> Bool {
        let lhsCost = promptPlusCompletionCost(lhs)
        let rhsCost = promptPlusCompletionCost(rhs)
        if lhsCost != rhsCost {
            return lhsCost < rhsCost
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func promptPlusCompletionCost(_ model: AIModel) -> Double {
        let unknownCost = Double.greatestFiniteMagnitude / 4
        let prompt = DataTools.ValueParser.decimal(from: model.pricing?.prompt) ?? unknownCost
        let completion = DataTools.ValueParser.decimal(from: model.pricing?.completion) ?? unknownCost
        return prompt + completion
    }

    private static func fallbackQualityScore(model: AIModel) -> Int {
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
