//
//  ChatSendMessageUseCase.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 组织发送流程并处理流式回填
//  - 统一模型校验与错误输出
//
//

import Foundation

struct ChatSendMessageEnvironment {
    var ensureConversation: @MainActor () -> Bool
    var setCurrentTurnId: @MainActor (UUID?) -> Void
    var clearCurrentTurnIdIfMatches: @MainActor (UUID) -> Void
    var getCurrentConversationId: @MainActor () -> String?
    var getSelectedModel: @MainActor () -> AIModel?
    var getAvailableModels: @MainActor () -> [AIModel]
    var setSelectedModel: @MainActor (AIModel) -> Void
    var buildMessagesForRequest: @MainActor (_ currentUserMessage: Message) -> [Message]

    var appendMessage: @MainActor (Message) -> Void
    var updateMessageContent: @MainActor (_ messageId: UUID, _ content: String) -> Void
    var finalizeStreamingMessage: @MainActor (_ messageId: UUID, _ metrics: MessageMetrics?, _ runtimeStatusText: String?, _ routingMetadata: MessageRoutingMetadata?) -> Message?
    var updatePersistedMessage: (_ message: Message, _ conversationId: String?) async -> Void

    var batchUpdate: @MainActor (_ updates: () -> Void) -> Void
    var setIsLoading: @MainActor (Bool) -> Void
    var setErrorMessage: @MainActor (String?) -> Void
    var emitEvent: @MainActor (_ event: ChatViewModel.Event) -> Void
}

private struct FallbackAttempt {
    let modelName: String
    let attempt: Int
}

private struct SmartRoutingResult {
    let metadata: MessageRoutingMetadata
    let statusText: String
}

@MainActor
final class ChatSendMessageUseCase {
    private let modelSelection: ModelSelectionCoordinator
    private let turnRunner: ChatTurnRunner
    private let turnIdFactory: ChatTurnIdFactory
    private let logger: ChatLogger
    private let fallbackPolicy = ModelFallbackPolicy()
    private let routingEngine = ModelRoutingEngine()
    private let providerStatsRepository: ProviderStatsRepository
    private var activeTypewriter: ChatTypewriter?

    init(
        modelSelection: ModelSelectionCoordinator,
        turnRunner: ChatTurnRunner,
        turnIdFactory: ChatTurnIdFactory,
        logger: ChatLogger,
        providerStatsRepository: ProviderStatsRepository? = nil
    ) {
        self.modelSelection = modelSelection
        self.turnRunner = turnRunner
        self.turnIdFactory = turnIdFactory
        self.logger = logger
        self.providerStatsRepository = providerStatsRepository ?? .shared
    }

    func execute(
        content: String,
        imageData: Data? = nil,
        imageMimeType: String? = nil,
        mediaContents: [MediaContent] = [],
        env: ChatSendMessageEnvironment
    ) async {
        var streamingMessageId: UUID?
        let apiKey = AppConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !AppConfig.useMockData, apiKey.isEmpty {
            env.setErrorMessage("请先在设置中填写 OpenRouter API Key")
            env.emitEvent(.switchToSettings)
            return
        }

        guard env.ensureConversation() else { return }
        let activeConversationId = env.getCurrentConversationId()
        activeTypewriter?.cancel()
        activeTypewriter = nil
        let useTypewriter = AppConfig.enableTypewriter

        var messageMediaContents = mediaContents
        if let imageData, let mimeType = imageMimeType {
            messageMediaContents.append(
                MediaContent(type: .image, data: imageData, mimeType: mimeType)
            )
        }

        let turnId = UUID()
        env.setCurrentTurnId(turnId)

        let baseId = turnIdFactory.makeBaseId(turnId: turnId)
        let userMessageItemId = turnIdFactory.makeItemId(baseId: baseId, kind: "user_msg", part: "main")
        logger.phase("turn start | baseId=\(baseId) | itemId=\(userMessageItemId) | stream=\(AppConfig.enableStream)")

        let userMessage = Message(
            content: content,
            role: .user,
            mediaContents: messageMediaContents,
            turnId: turnId,
            baseId: baseId,
            itemId: userMessageItemId
        )
        env.appendMessage(userMessage)

        let validation = modelSelection.validateSelection(selectedModel: env.getSelectedModel(), userMessage: userMessage)
        var model: AIModel
        switch validation {
        case .ready(let selected):
            model = selected
        case .error(let message, let reason):
            let errorItemId = turnIdFactory.makeItemId(baseId: baseId, kind: "error", part: reason)
            let errorMsg = Message(content: message, role: .assistant, turnId: turnId, baseId: baseId, itemId: errorItemId)
            env.appendMessage(errorMsg)
            logger.phase("turn end | baseId=\(baseId) | reason=\(reason)")
            env.clearCurrentTurnIdIfMatches(turnId)
            env.setIsLoading(false)
            return
        }

        env.setIsLoading(true)
        env.setErrorMessage(nil)

        let requestMessages = env.buildMessagesForRequest(userMessage)
        let routingResult = maybeApplySmartRouting(
            content: content,
            userMessage: userMessage,
            requestMessages: requestMessages,
            currentModel: &model,
            env: env
        )

        var attemptIndex = 0
        var fallbackAttempts: [FallbackAttempt] = []
        var triedModelIds: Set<String> = [model.id]
        let maxRetries = max(0, AppConfig.fallbackMaxRetries)
        let requiresMultimodal = userMessage.hasMedia
        providerStatsRepository.recordRequest(providerId: model.provider.rawValue)

        while true {
            do {
                try await executeOnce(
                    model: model,
                    turnId: turnId,
                    baseId: baseId,
                    userMessage: userMessage,
                    useTypewriter: useTypewriter,
                    fallbackAttempts: fallbackAttempts,
                    routingResult: routingResult,
                    conversationId: activeConversationId,
                    env: env,
                    streamingMessageId: &streamingMessageId
                )
                return
            } catch {
                TextToSpeechManager.shared.finishStreamingSession()
                activeTypewriter?.cancel()
                activeTypewriter = nil

                if Task.isCancelled || error is CancellationError {
                    TextToSpeechManager.shared.stop()
                    var updated: Message?
                    env.batchUpdate {
                        env.setIsLoading(false)
                        if let messageId = streamingMessageId {
                            updated = env.finalizeStreamingMessage(messageId, nil, nil, routingResult?.metadata)
                        }
                    }
                    if let updated {
                        await env.updatePersistedMessage(updated, activeConversationId)
                    }
                    env.clearCurrentTurnIdIfMatches(turnId)
                    logger.phase("turn end | baseId=\(baseId) | reason=cancelled")
                    return
                }

                let classified = OpenRouterErrorClassifier.classify(error)
                let canFallback = AppConfig.fallbackEnabled
                    && attemptIndex < maxRetries
                    && shouldRetryWithFallback(for: classified.category)

                if canFallback,
                   let nextModel = fallbackPolicy.nextModel(
                    currentModel: model,
                    availableModels: env.getAvailableModels(),
                    attemptIndex: attemptIndex,
                    category: classified.category,
                    budgetMode: AppConfig.fallbackBudgetMode,
                    triedModelIds: triedModelIds,
                    requiresMultimodal: requiresMultimodal
                   ) {
                    providerStatsRepository.recordFailure(providerId: model.provider.rawValue, category: classified.category)

                    var finalizedForRetry: Message?
                    if let currentStreamingMessageId = streamingMessageId {
                        env.batchUpdate {
                            finalizedForRetry = env.finalizeStreamingMessage(
                                currentStreamingMessageId,
                                nil,
                                "当前模型请求失败，准备切换重试",
                                routingResult?.metadata
                            )
                        }
                    }
                    if let finalizedForRetry {
                        await env.updatePersistedMessage(finalizedForRetry, activeConversationId)
                    }
                    streamingMessageId = nil

                    attemptIndex += 1
                    model = nextModel
                    fallbackAttempts.append(FallbackAttempt(modelName: nextModel.name, attempt: attemptIndex))
                    triedModelIds.insert(nextModel.id)
                    env.setSelectedModel(nextModel)
                    providerStatsRepository.recordRequest(providerId: nextModel.provider.rawValue)
                    env.setErrorMessage("请求失败，已自动切换到 \(nextModel.name) 重试（\(attemptIndex)/\(maxRetries)）")
                    logger.phase("fallback | baseId=\(baseId) | nextModel=\(nextModel.apiModel) | attempt=\(attemptIndex)")
                    continue
                }

                await emitErrorMessage(
                    classified: classified,
                    turnId: turnId,
                    baseId: baseId,
                    providerId: model.provider.rawValue,
                    env: env,
                    streamingMessageId: streamingMessageId,
                    fallbackStatusText: makeFallbackStatusText(fallbackAttempts),
                    routingMetadata: routingResult?.metadata,
                    conversationId: activeConversationId
                )
                return
            }
        }
    }

    private func executeOnce(
        model: AIModel,
        turnId: UUID,
        baseId: String,
        userMessage: Message,
        useTypewriter: Bool,
        fallbackAttempts: [FallbackAttempt],
        routingResult: SmartRoutingResult?,
        conversationId: String?,
        env: ChatSendMessageEnvironment,
        streamingMessageId: inout UUID?
    ) async throws {
        let fallbackStatusText = makeFallbackStatusText(fallbackAttempts)
        let routingMetadata = routingResult?.metadata
        let routingStatusText = routingResult?.statusText
        if AppConfig.enableStream {
            // 注意：messagesToSend 不能包含“空的 streaming assistant 占位消息”，否则会污染上下文。
            let messagesToSend = env.buildMessagesForRequest(userMessage)
            let nativeFallbackModels = makeNativeFallbackModels(
                currentModel: model,
                availableModels: env.getAvailableModels(),
                requiresMultimodal: userMessage.hasMedia
            )

            let assistantMessageItemId = turnIdFactory.makeItemId(baseId: baseId, kind: "assistant_stream", part: "main")
            let assistantMessage = Message(
                content: "",
                role: .assistant,
                isStreaming: true,
                turnId: turnId,
                baseId: baseId,
                itemId: assistantMessageItemId,
                runtimeStatusText: mergedStatusText(fallbackStatusText: fallbackStatusText, routingStatusText: routingStatusText),
                routingMetadata: routingMetadata
            )
            env.appendMessage(assistantMessage)
            streamingMessageId = assistantMessage.id
            TextToSpeechManager.shared.startStreamingSession()

            let messageId = assistantMessage.id
            logger.phase("assistant stream init | baseId=\(baseId) | itemId=\(assistantMessageItemId) | messageId=\(messageId.uuidString) | model=\(model.apiModel)")

            if !useTypewriter {
                let result = try await turnRunner.runStream(
                    messages: messagesToSend,
                    model: model.apiModel,
                    fallbackModelIDs: nativeFallbackModels,
                    onProgress: { progress in
                        env.updateMessageContent(messageId, progress.fullContent)
                        TextToSpeechManager.shared.updateStreamingText(progress.fullContent)
                        if progress.chunkCount == 1 || progress.chunkCount % 50 == 0 {
                            self.logger.phase(
                                "stream chunk | baseId=\(baseId) | itemId=\(assistantMessageItemId) | chunks=\(progress.chunkCount) | len=\(progress.fullContent.count)"
                            )
                        }
                    }
                )
                let streamMetrics = makeMetrics(
                    requestMessages: messagesToSend,
                    responseText: result.fullContent,
                    model: model,
                    latencyMs: result.durationMs
                )

                let updated: Message? = await MainActor.run {
                    var updated: Message?
                    env.batchUpdate {
                        env.setIsLoading(false)
                        updated = env.finalizeStreamingMessage(
                            messageId,
                            streamMetrics,
                            mergedStatusText(fallbackStatusText: fallbackStatusText, routingStatusText: routingStatusText),
                            routingMetadata
                        )
                    }
                    return updated
                }

                if let updated {
                    providerStatsRepository.recordSuccess(providerId: model.provider.rawValue, metrics: streamMetrics)
                    await env.updatePersistedMessage(updated, conversationId)
                }
                TextToSpeechManager.shared.finishStreamingSession()

                logger.phase(
                    "turn end | baseId=\(baseId) | reason=closed | chunks=\(result.chunkCount) | len=\(result.fullContent.count) | durationMs=\(result.durationMs)"
                )
                env.clearCurrentTurnIdIfMatches(turnId)
                return
            }

            var streamResult: ChatStreamResult?
            var streamMetrics: MessageMetrics?
            let typewriterConfig = makeTypewriterConfig()
            let combinedStatusText = mergedStatusText(fallbackStatusText: fallbackStatusText, routingStatusText: routingStatusText)
            let typewriter = ChatTypewriter(
                config: typewriterConfig,
                updateDisplay: { text in
                    env.updateMessageContent(messageId, text)
                },
                onFinish: { [weak self] in
                    var updated: Message?
                    env.batchUpdate {
                        env.setIsLoading(false)
                        updated = env.finalizeStreamingMessage(
                            messageId,
                            streamMetrics,
                            combinedStatusText,
                            routingMetadata
                        )
                    }
                    if let updated {
                        self?.providerStatsRepository.recordSuccess(providerId: model.provider.rawValue, metrics: streamMetrics)
                        Task { await env.updatePersistedMessage(updated, conversationId) }
                    }
                    Task { @MainActor in
                        TextToSpeechManager.shared.finishStreamingSession()
                    }
                    if let result = streamResult {
                        self?.logger.phase(
                            "turn end | baseId=\(baseId) | reason=closed | chunks=\(result.chunkCount) | len=\(result.fullContent.count) | durationMs=\(result.durationMs)"
                        )
                    }
                    env.clearCurrentTurnIdIfMatches(turnId)
                    self?.activeTypewriter = nil
                }
            )
            activeTypewriter = typewriter
            typewriter.start()

            let result = try await turnRunner.runStream(
                messages: messagesToSend,
                model: model.apiModel,
                fallbackModelIDs: nativeFallbackModels,
                onProgress: { progress in
                    typewriter.updateTarget(progress.fullContent)
                    TextToSpeechManager.shared.updateStreamingText(progress.fullContent)
                    if progress.chunkCount == 1 || progress.chunkCount % 50 == 0 {
                        self.logger.phase(
                            "stream chunk | baseId=\(baseId) | itemId=\(assistantMessageItemId) | chunks=\(progress.chunkCount) | len=\(progress.fullContent.count)"
                        )
                    }
                }
            )
            streamResult = result
            streamMetrics = makeMetrics(
                requestMessages: messagesToSend,
                responseText: result.fullContent,
                model: model,
                latencyMs: result.durationMs
            )
            typewriter.updateTarget(result.fullContent)
            typewriter.markStreamEnded()
            TextToSpeechManager.shared.finishStreamingSession()
            return
        }

        let messagesToSend = env.buildMessagesForRequest(userMessage)
        let nativeFallbackModels = makeNativeFallbackModels(
            currentModel: model,
            availableModels: env.getAvailableModels(),
            requiresMultimodal: userMessage.hasMedia
        )
        if !nativeFallbackModels.isEmpty {
            logger.phase("native fallback chain | primary=\(model.apiModel) | fallbacks=\(nativeFallbackModels.joined(separator: " -> "))")
        }
        let nonStreamStartTime = Date()
        let serviceResponse = try await turnRunner.runNonStream(
            messages: messagesToSend,
            model: model.apiModel,
            fallbackModelIDs: nativeFallbackModels
        )
        let response = serviceResponse.content
        let nonStreamDurationMs = Int(Date().timeIntervalSince(nonStreamStartTime) * 1000)
        let nonStreamMetrics = makeMetrics(
            requestMessages: messagesToSend,
            responseText: response,
            model: model,
            latencyMs: nonStreamDurationMs,
            usage: serviceResponse.usage
        )

        let assistantMessageItemId = turnIdFactory.makeItemId(baseId: baseId, kind: "assistant_final", part: "main")
        if !useTypewriter {
            let assistantMessage = Message(
                content: response,
                role: .assistant,
                turnId: turnId,
                baseId: baseId,
                itemId: assistantMessageItemId,
                metrics: nonStreamMetrics,
                runtimeStatusText: mergedStatusText(fallbackStatusText: fallbackStatusText, routingStatusText: routingStatusText),
                routingMetadata: routingMetadata
            )

            env.batchUpdate {
                env.setIsLoading(false)
                env.appendMessage(assistantMessage)
            }

            providerStatsRepository.recordSuccess(providerId: model.provider.rawValue, metrics: nonStreamMetrics)

            await MainActor.run {
                TextToSpeechManager.shared.speak(assistantMessage.content)
            }

            logger.phase("turn end | baseId=\(baseId) | reason=non_stream_done | len=\(response.count)")
            env.clearCurrentTurnIdIfMatches(turnId)
            return
        }

        let assistantMessage = Message(
            content: "",
            role: .assistant,
            isStreaming: true,
            turnId: turnId,
            baseId: baseId,
            itemId: assistantMessageItemId,
            runtimeStatusText: mergedStatusText(fallbackStatusText: fallbackStatusText, routingStatusText: routingStatusText),
            routingMetadata: routingMetadata
        )

        env.appendMessage(assistantMessage)
        streamingMessageId = assistantMessage.id

        let messageId = assistantMessage.id
        let typewriterConfig = makeTypewriterConfig()
        let combinedStatusText = mergedStatusText(fallbackStatusText: fallbackStatusText, routingStatusText: routingStatusText)
        let typewriter = ChatTypewriter(
            config: typewriterConfig,
            updateDisplay: { text in
                env.updateMessageContent(messageId, text)
            },
            onFinish: { [weak self] in
                var updated: Message?
                env.batchUpdate {
                    env.setIsLoading(false)
                    updated = env.finalizeStreamingMessage(
                        messageId,
                        nonStreamMetrics,
                        combinedStatusText,
                        routingMetadata
                    )
                }
                if let updated {
                    self?.providerStatsRepository.recordSuccess(providerId: model.provider.rawValue, metrics: nonStreamMetrics)
                    Task { await env.updatePersistedMessage(updated, conversationId) }
                    Task { @MainActor in
                        TextToSpeechManager.shared.speak(updated.content)
                    }
                }
                self?.logger.phase("turn end | baseId=\(baseId) | reason=non_stream_done | len=\(response.count)")
                env.clearCurrentTurnIdIfMatches(turnId)
                self?.activeTypewriter = nil
            }
        )
        activeTypewriter = typewriter
        typewriter.start()
        typewriter.updateTarget(response)
        typewriter.markStreamEnded()
    }

    private func emitErrorMessage(
        classified: ClassifiedChatError,
        turnId: UUID,
        baseId: String,
        providerId: String,
        env: ChatSendMessageEnvironment,
        streamingMessageId: UUID?,
        fallbackStatusText: String?,
        routingMetadata: MessageRoutingMetadata?,
        conversationId: String?
    ) async {
        providerStatsRepository.recordFailure(providerId: providerId, category: classified.category)
        env.setErrorMessage(classified.bannerMessage)
        var updated: Message?
        env.batchUpdate {
            env.setIsLoading(false)
            if let messageId = streamingMessageId {
                let mergedStatusText: String?
                if let fallbackStatusText, !fallbackStatusText.isEmpty {
                    mergedStatusText = "\(fallbackStatusText) · \(classified.statusMessage)"
                } else {
                    mergedStatusText = classified.statusMessage
                }
                updated = env.finalizeStreamingMessage(messageId, nil, mergedStatusText, routingMetadata)
            }
            let errorItemId = turnIdFactory.makeItemId(baseId: baseId, kind: "error", part: classified.category.rawValue)
            let errorMsg = Message(
                content: "抱歉，发生了错误：\(classified.userMessage)",
                role: .assistant,
                turnId: turnId,
                baseId: baseId,
                itemId: errorItemId,
                runtimeStatusText: classified.statusMessage,
                routingMetadata: routingMetadata
            )
            env.appendMessage(errorMsg)
            env.clearCurrentTurnIdIfMatches(turnId)
        }
        if let updated {
            await env.updatePersistedMessage(updated, conversationId)
        }
        logger.phase("turn end | baseId=\(baseId) | reason=error | category=\(classified.category.rawValue) | error=\(classified.technicalMessage)")
    }

    private func makeFallbackStatusText(_ attempts: [FallbackAttempt]) -> String? {
        guard let last = attempts.last else { return nil }
        return "已切换到 \(last.modelName)（重试 \(last.attempt) 次）"
    }

    private func mergedStatusText(fallbackStatusText: String?, routingStatusText: String?) -> String? {
        let parts = [routingStatusText, fallbackStatusText].compactMap { text -> String? in
            guard let text, !text.isEmpty else { return nil }
            return text
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }



    private func shouldRetryWithFallback(for category: ChatErrorCategory) -> Bool {
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

    private func maybeApplySmartRouting(
        content: String,
        userMessage: Message,
        requestMessages: [Message],
        currentModel: inout AIModel,
        env: ChatSendMessageEnvironment
    ) -> SmartRoutingResult? {
        guard AppConfig.routingMode == .smart else { return nil }

        let intent = TaskIntent.infer(
            content: content,
            hasMedia: userMessage.hasMedia,
            requestMessages: requestMessages
        )

        guard let decision = routingEngine.recommendModel(
            currentModel: currentModel,
            availableModels: env.getAvailableModels(),
            intent: intent,
            budgetMode: AppConfig.budgetMode
        ) else {
            return nil
        }

        let previousModelId = currentModel.id
        let metadata = MessageRoutingMetadata(
            fromModelId: previousModelId,
            toModelId: decision.model.id,
            reason: decision.reason,
            mode: AppConfig.routingMode,
            budgetMode: AppConfig.budgetMode
        )

        currentModel = decision.model
        env.setSelectedModel(decision.model)
        let statusText = "智能路由：\(decision.model.name)"
        env.setErrorMessage("已按智能路由切换到 \(decision.model.name)")
        logger.phase("smart routing | model=\(decision.model.apiModel) | reason=\(decision.reason)")
        return SmartRoutingResult(metadata: metadata, statusText: statusText)
    }

    /// 尾段速度随“打字机速度”提升，避免最后 200 字固定 1 字/ tick 的视觉拖慢。
    private func makeTypewriterConfig() -> ChatTypewriter.Config {
        let speed = AppConfig.clampTypewriterSpeed(AppConfig.typewriterSpeed)
        return ChatTypewriter.Config(
            tickInterval: max(0.02, 0.08 / speed),
            minCharsPerTick: AppConfig.typewriterMinCharsPerTick(for: speed),
            maxCharsPerTick: AppConfig.typewriterMaxCharsPerTick(for: speed)
        )
    }

    private func makeMetrics(
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

    private func estimatePromptTokens(from messages: [Message]) -> Int {
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

    private func estimateTextTokens(_ text: String) -> Int {
        estimateTextTokensByCharCount(text.count)
    }

    private func estimateTextTokensByCharCount(_ charCount: Int) -> Int {
        guard charCount > 0 else { return 0 }
        return Int((Double(charCount) / 3.6).rounded(.up))
    }

    private func estimateCostUSD(model: AIModel, promptTokens: Int, completionTokens: Int) -> Double? {
        let promptRate = DataTools.ValueParser.decimal(from: model.pricing?.prompt) ?? 0
        let completionRate = DataTools.ValueParser.decimal(from: model.pricing?.completion) ?? 0
        guard promptRate > 0 || completionRate > 0 else { return nil }

        let promptCost = Double(promptTokens) * promptRate
        let completionCost = Double(completionTokens) * completionRate
        return promptCost + completionCost
    }

    private func makeNativeFallbackModels(
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
              let next = fallbackPolicy.nextModel(
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

    func cancelActive() {
        activeTypewriter?.cancel()
        activeTypewriter = nil
        TextToSpeechManager.shared.stop()
    }
}

@MainActor
private final class ChatTypewriter {
    struct Config {
        let tickInterval: TimeInterval
        let minCharsPerTick: Int
        let maxCharsPerTick: Int
    }

    private let config: Config
    private let updateDisplay: (String) -> Void
    private let onFinish: () -> Void
    private var targetText: String = ""
    private var displayText: String = ""
    private var streamEnded = false
    private var task: Task<Void, Never>?
    private var tickCount: Int = 0
    private var lastTickDate: Date = Date()
    private var totalTickIntervalMs: Double = 0
    private var maxTickIntervalMs: Double = 0
    private var cachedTableRanges: [(start: Int, end: Int)] = []
    private var isTableRangesDirty: Bool = true

    init(
        config: Config,
        updateDisplay: @escaping (String) -> Void,
        onFinish: @escaping () -> Void
    ) {
        self.config = config
        self.updateDisplay = updateDisplay
        self.onFinish = onFinish
    }

    func start() {
        guard task == nil else { return }
        tickCount = 0
        totalTickIntervalMs = 0
        maxTickIntervalMs = 0
        lastTickDate = Date()
        cachedTableRanges.removeAll(keepingCapacity: true)
        isTableRangesDirty = true
        task = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func updateTarget(_ text: String) {
        if text.count >= targetText.count {
            targetText = text
            isTableRangesDirty = true
        } else {
            targetText = text
            isTableRangesDirty = true
            if displayText.count > text.count {
                displayText = text
                updateDisplay(safeDisplayText(displayText, isFinal: false))
            }
        }
    }

    func markStreamEnded() {
        streamEnded = true
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

private extension ChatTypewriter {
    func runLoop() async {
        while !Task.isCancelled {
            if displayText.count < targetText.count {
                let now = Date()
                let tickIntervalMs = now.timeIntervalSince(lastTickDate) * 1000
                lastTickDate = now

                tickCount += 1
                if tickCount > 1 {
                    totalTickIntervalMs += tickIntervalMs
                    maxTickIntervalMs = max(maxTickIntervalMs, tickIntervalMs)
                }

                displayText = nextDisplayText(current: displayText, target: targetText)
                updateDisplay(safeDisplayText(displayText, isFinal: false))

                if AppConfig.enablephaseLogs,
                   (tickCount == 1 || tickCount % 60 == 0) {
                    let avgTickMs = tickCount > 1
                        ? totalTickIntervalMs / Double(tickCount - 1)
                        : 0
                    RuntimeTools.AppDiagnostics.debug(
                        "ConversationPerf",
                        "[typewriter] ticks=\(tickCount) | shown=\(displayText.count) | target=\(targetText.count) | lastTickMs=\(String(format: "%.1f", tickIntervalMs)) | avgTickMs=\(String(format: "%.1f", avgTickMs))"
                    )
                }
            } else if streamEnded {
                updateDisplay(safeDisplayText(targetText, isFinal: true))
                if AppConfig.enablephaseLogs {
                    let avgTickMs = tickCount > 1
                        ? totalTickIntervalMs / Double(tickCount - 1)
                        : 0
                    RuntimeTools.AppDiagnostics.debug(
                        "ConversationPerf",
                        "[typewriter] done | ticks=\(tickCount) | len=\(targetText.count) | avgTickMs=\(String(format: "%.1f", avgTickMs)) | maxTickMs=\(String(format: "%.1f", maxTickIntervalMs))"
                    )
                }
                onFinish()
                task = nil
                return
            }
            do {
                try await Task.sleep(nanoseconds: UInt64(currentTickInterval() * 1_000_000_000))
            } catch {
                task = nil
                return
            }
        }
        task = nil
    }

    func nextDisplayText(current: String, target: String) -> String {
        let currentCount = current.count
        let targetCount = target.count
        guard currentCount < targetCount else { return current }
        let nextCount = nextOffset(from: currentCount, target: target)
        if nextCount <= 0 { return current }
        return String(target.prefix(nextCount))
    }

    func nextOffset(from current: Int, target: String) -> Int {
        let targetCount = target.count
        guard current < targetCount else { return current }

        let ranges = currentTableRanges(for: target)
        if let table = ranges.first(where: { current >= $0.start && current < $0.end }) {
            return min(table.end, targetCount)
        }

        let chunk = charsPerTick(remaining: targetCount - current)
        if let nextTableStart = ranges.map({ $0.start }).filter({ $0 > current }).min() {
            let tentative = min(current + chunk, targetCount)
            if nextTableStart < tentative {
                return nextTableStart
            }
            return tentative
        }

        return min(current + chunk, targetCount)
    }

    func charsPerTick(remaining: Int) -> Int {
        let minValue = max(config.minCharsPerTick, 1)
        let maxValue = max(config.maxCharsPerTick, minValue)
        if remaining > 800 { return maxValue }
        if remaining > 400 { return max(minValue, maxValue - 2) }
        if remaining > 200 { return max(minValue, maxValue - 4) }
        return minValue
    }

    func currentTickInterval() -> TimeInterval {
        let speed = max(0.1, min(8.0, AppConfig.typewriterSpeed))
        return max(0.02, 0.08 / speed)
    }

    func safeDisplayText(_ text: String, isFinal: Bool) -> String {
        guard !isFinal else { return text }

        var output = text
        while true {
            let trimmed = trimmedTrailingWhitespace(output)
            if trimmed.isEmpty { return output }

            var removeCount = 0
            if trimmed.hasSuffix("![") { removeCount = 2 }
            else if trimmed.hasSuffix("](") { removeCount = 2 }
            else if trimmed.hasSuffix("[") { removeCount = 1 }
            else if trimmed.hasSuffix("***") { removeCount = 3 }
            else if trimmed.hasSuffix("**") { removeCount = 2 }
            else if trimmed.hasSuffix("*") { removeCount = 1 }
            else if trimmed.hasSuffix("__") { removeCount = 2 }
            else if trimmed.hasSuffix("_") { removeCount = 1 }
            else if trimmed.hasSuffix("~~") { removeCount = 2 }
            else if trimmed.hasSuffix("~") { removeCount = 1 }
            else if trimmed.hasSuffix("`") { removeCount = 1 }

            if removeCount == 0 { break }
            let newLength = max(0, trimmed.count - removeCount)
            output = String(trimmed.prefix(newLength))
        }
        return output
    }

    func trimmedTrailingWhitespace(_ text: String) -> String {
        var end = text.endIndex
        while end > text.startIndex {
            let prev = text.index(before: end)
            if text[prev].isWhitespace {
                end = prev
            } else {
                break
            }
        }
        return String(text[..<end])
    }

    func tableRanges(in text: String) -> [(start: Int, end: Int)] {
        let lines = lineRanges(in: text)
        guard lines.count >= 2 else { return [] }

        var ranges: [(start: Int, end: Int)] = []
        var inCodeBlock = false
        var index = 0

        while index + 1 < lines.count {
            let line = lines[index].content
            if isFenceLine(line) {
                inCodeBlock.toggle()
                index += 1
                continue
            }
            if inCodeBlock {
                index += 1
                continue
            }

            let nextLine = lines[index + 1].content
            if isTableHeader(line), isTableSeparator(nextLine) {
                var end = lines[index + 1].end
                var rowIndex = index + 2
                while rowIndex < lines.count {
                    let rowLine = lines[rowIndex].content
                    if isFenceLine(rowLine) { break }
                    if rowLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { break }
                    if !isTableRow(rowLine) { break }
                    end = lines[rowIndex].end
                    rowIndex += 1
                }
                ranges.append((start: lines[index].start, end: end))
                index = rowIndex
                continue
            }

            index += 1
        }
        return ranges
    }

    func currentTableRanges(for text: String) -> [(start: Int, end: Int)] {
        if isTableRangesDirty {
            cachedTableRanges = tableRanges(in: text)
            isTableRangesDirty = false
        }
        return cachedTableRanges
    }

    func lineRanges(in text: String) -> [(start: Int, end: Int, content: Substring)] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let totalCount = text.count
        var ranges: [(start: Int, end: Int, content: Substring)] = []
        var offset = 0

        for line in lines {
            let start = offset
            offset += line.count
            if offset < totalCount {
                offset += 1
            }
            let end = offset
            ranges.append((start: start, end: end, content: line))
        }
        return ranges
    }

    func isFenceLine(_ line: Substring) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("```")
    }

    func isTableHeader(_ line: Substring) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.contains("|")
    }

    func isTableSeparator(_ line: Substring) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("|") else { return false }

        var hasDash = false
        for ch in trimmed {
            if ch == "-" { hasDash = true; continue }
            if ch == "|" || ch == ":" || ch == " " || ch == "\t" { continue }
            return false
        }
        return hasDash
    }

    func isTableRow(_ line: Substring) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.contains("|")
    }
}
