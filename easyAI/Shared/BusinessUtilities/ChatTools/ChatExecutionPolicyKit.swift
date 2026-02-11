import Foundation

enum ChatExecutionPolicyKit {
    struct TypewriterConfig {
        let tickInterval: TimeInterval
        let minCharsPerTick: Int
        let maxCharsPerTick: Int
    }

    static func makeTypewriterConfig() -> TypewriterConfig {
        let speed = AppConfig.clampTypewriterSpeed(AppConfig.typewriterSpeed)
        return TypewriterConfig(
            tickInterval: max(0.02, 0.08 / speed),
            minCharsPerTick: AppConfig.typewriterMinCharsPerTick(for: speed),
            maxCharsPerTick: AppConfig.typewriterMaxCharsPerTick(for: speed)
        )
    }

    static func makeMetrics(
        requestMessages: [Message],
        responseText: String,
        model: AIModel,
        latencyMs: Int,
        usage: ChatTokenUsage? = nil
    ) -> MessageMetrics {
        let estimatedPromptTokens = estimatePromptTokens(from: requestMessages)
        let estimatedCompletionTokens = estimateTextTokens(responseText)
        let promptTokens = usage?.promptTokens ?? estimatedPromptTokens
        let completionTokens = usage?.completionTokens ?? estimatedCompletionTokens
        let totalTokens = usage?.totalTokens ?? (promptTokens + completionTokens)
        let estimatedCostUSD = estimateCostUSD(
            model: model,
            promptTokens: promptTokens,
            completionTokens: completionTokens
        )
        let isEstimated = usage == nil

        return MessageMetrics(
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens,
            latencyMs: latencyMs,
            estimatedCostUSD: estimatedCostUSD,
            isEstimated: isEstimated
        )
    }

    static func makeNativeFallbackModels(
        currentModel: AIModel,
        availableModels: [AIModel],
        requiresMultimodal: Bool
    ) -> [String] {
        let nativeFallbackDepth = AppConfig.nativeFallbackDepth
        guard AppConfig.fallbackEnabled, nativeFallbackDepth > 0 else { return [] }

        var triedModelIds: Set<String> = [currentModel.id]
        var cursorModel = currentModel
        var fallbackModelIDs: [String] = []
        var attemptIndex = 0

        while attemptIndex < nativeFallbackDepth,
              let next = ModelDecisionKit.nextFallbackModel(
                currentModel: cursorModel,
                availableModels: availableModels,
                attemptIndex: attemptIndex,
                category: .serverUnavailable,
                budgetMode: AppConfig.fallbackBudgetMode,
                triedModelIds: triedModelIds,
                requiresMultimodal: requiresMultimodal
              ) {
            let apiModel = next.apiModel.trimmingCharacters(in: .whitespacesAndNewlines)
            if !apiModel.isEmpty {
                fallbackModelIDs.append(apiModel)
            }
            triedModelIds.insert(next.id)
            cursorModel = next
            attemptIndex += 1
        }

        return fallbackModelIDs
    }

    private static func estimatePromptTokens(from messages: [Message]) -> Int {
        var approxChars = 0
        for message in messages {
            let roleOverhead = 8
            var mediaOverhead = 0
            for media in message.mediaContents {
                switch media.type {
                case .image:
                    mediaOverhead += 180
                case .video, .audio, .document, .pdf:
                    mediaOverhead += 120
                }
            }
            approxChars += message.content.count + roleOverhead + mediaOverhead
        }
        return estimateTextTokensByCharCount(approxChars)
    }

    private static func estimateTextTokens(_ text: String) -> Int {
        estimateTextTokensByCharCount(text.count)
    }

    private static func estimateTextTokensByCharCount(_ charCount: Int) -> Int {
        guard charCount > 0 else { return 0 }
        return Int((Double(charCount) / 3.6).rounded(.up))
    }

    private static func estimateCostUSD(
        model: AIModel,
        promptTokens: Int,
        completionTokens: Int
    ) -> Double? {
        let promptRate = DataTools.ValueParser.decimal(from: model.pricing?.prompt) ?? 0
        let completionRate = DataTools.ValueParser.decimal(from: model.pricing?.completion) ?? 0
        guard promptRate > 0 || completionRate > 0 else { return nil }

        let promptCost = Double(promptTokens) * promptRate
        let completionCost = Double(completionTokens) * completionRate
        return promptCost + completionCost
    }
}
