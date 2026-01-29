//
//  ChatSendMessageUseCase.swift
//  EasyAI
//
//  创建于 2026
//

import Foundation

struct ChatSendMessageEnvironment {
    var ensureConversation: @MainActor () -> Bool
    var setAnimationStopToken: @MainActor (UUID) -> Void
    var setCurrentTurnId: @MainActor (UUID?) -> Void
    var getSelectedModel: @MainActor () -> AIModel?
    var buildMessagesForRequest: @MainActor (_ currentUserMessage: Message) -> [Message]

    var appendMessage: @MainActor (Message) -> Void
    var updateMessageContent: @MainActor (_ messageId: UUID, _ content: String) -> Void
    var finalizeStreamingMessage: @MainActor (_ messageId: UUID) -> Message?
    var updatePersistedMessage: (_ message: Message) async -> Void

    var batchUpdate: @MainActor (_ updates: () -> Void) -> Void
    var setIsLoading: @MainActor (Bool) -> Void
    var setIsTypingAnimating: @MainActor (Bool) -> Void
    var setErrorMessage: @MainActor (String?) -> Void
}

@MainActor
final class ChatSendMessageUseCase {
    private let specialResponsePolicy: SpecialResponsePolicy
    private let modelSelection: ModelSelectionCoordinator
    private let turnRunner: ChatTurnRunner
    private let turnIdFactory: ChatTurnIdFactory
    private let logger: ChatLogger

    init(
        specialResponsePolicy: SpecialResponsePolicy,
        modelSelection: ModelSelectionCoordinator,
        turnRunner: ChatTurnRunner,
        turnIdFactory: ChatTurnIdFactory,
        logger: ChatLogger
    ) {
        self.specialResponsePolicy = specialResponsePolicy
        self.modelSelection = modelSelection
        self.turnRunner = turnRunner
        self.turnIdFactory = turnIdFactory
        self.logger = logger
    }

    func execute(
        content: String,
        imageData: Data? = nil,
        imageMimeType: String? = nil,
        mediaContents: [MediaContent] = [],
        env: ChatSendMessageEnvironment
    ) async {
        env.setAnimationStopToken(UUID())

        guard env.ensureConversation() else { return }

        if imageData == nil && mediaContents.isEmpty && specialResponsePolicy.shouldUseSpecialResponse(for: content) {
            let assistantMessage = Message(content: specialResponsePolicy.specialResponseText, role: .assistant)
            env.appendMessage(assistantMessage)
            return
        }

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
        logger.phase4("turn start | baseId=\(baseId) | itemId=\(userMessageItemId) | stream=\(AppConfig.enableStream)")

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
        let model: AIModel
        switch validation {
        case .ready(let selected):
            model = selected
        case .error(let message, let reason):
            let errorItemId = turnIdFactory.makeItemId(baseId: baseId, kind: "error", part: reason)
            let errorMsg = Message(content: message, role: .assistant, turnId: turnId, baseId: baseId, itemId: errorItemId)
            env.appendMessage(errorMsg)
            logger.phase4("turn end | baseId=\(baseId) | reason=\(reason)")
            env.setCurrentTurnId(nil)
            env.setIsLoading(false)
            return
        }

        env.setIsLoading(true)
        env.setErrorMessage(nil)

        do {
            if AppConfig.enableStream {
                // 注意：messagesToSend 不能包含“空的 streaming assistant 占位消息”，否则会污染上下文。
                let messagesToSend = env.buildMessagesForRequest(userMessage)

                let assistantMessageItemId = turnIdFactory.makeItemId(baseId: baseId, kind: "assistant_stream", part: "main")
                let assistantMessage = Message(
                    content: "",
                    role: .assistant,
                    isStreaming: true,
                    turnId: turnId,
                    baseId: baseId,
                    itemId: assistantMessageItemId
                )
                env.appendMessage(assistantMessage)
                env.setIsTypingAnimating(true)

                let messageId = assistantMessage.id
                logger.phase4("assistant stream init | baseId=\(baseId) | itemId=\(assistantMessageItemId) | messageId=\(messageId.uuidString)")

                let result = try await turnRunner.runStream(
                    messages: messagesToSend,
                    model: model.apiModel,
                    onProgress: { progress in
                        env.updateMessageContent(messageId, progress.fullContent)
                        if progress.chunkCount == 1 || progress.chunkCount % 50 == 0 {
                            self.logger.phase4(
                                "stream chunk | baseId=\(baseId) | itemId=\(assistantMessageItemId) | chunks=\(progress.chunkCount) | len=\(progress.fullContent.count)"
                            )
                        }
                    }
                )

                // 规则：流式期间有 loading；结束时先去掉 loading，再显示 timestamp。
                env.batchUpdate {
                    env.setIsLoading(false)
                }
                DispatchQueue.main.async {
                    Task {
                        // 第二步：先显示 timestamp（isStreaming=false）并结束输入禁用，然后再持久化更新。
                        let updated: Message? = await MainActor.run {
                            var updated: Message?
                            env.batchUpdate {
                                env.setIsTypingAnimating(false)
                                updated = env.finalizeStreamingMessage(messageId)
                            }
                            return updated
                        }
                        if let updated {
                            await env.updatePersistedMessage(updated)
                        }
                    }
                }

                logger.phase4(
                    "turn end | baseId=\(baseId) | reason=closed | chunks=\(result.chunkCount) | len=\(result.fullContent.count) | durationMs=\(result.durationMs)"
                )
                env.setCurrentTurnId(nil)
            } else {
                let messagesToSend = env.buildMessagesForRequest(userMessage)
                let response = try await turnRunner.runNonStream(messages: messagesToSend, model: model.apiModel)

                let assistantMessageItemId = turnIdFactory.makeItemId(baseId: baseId, kind: "assistant_final", part: "main")
                let assistantMessage = Message(
                    content: response,
                    role: .assistant,
                    turnId: turnId,
                    baseId: baseId,
                    itemId: assistantMessageItemId
                )

                env.batchUpdate {
                    env.setIsTypingAnimating(false)
                    env.setIsLoading(false)
                    env.appendMessage(assistantMessage)
                }

                logger.phase4("turn end | baseId=\(baseId) | reason=non_stream_done | len=\(response.count)")
                env.setCurrentTurnId(nil)
            }
        } catch {
            let errorDesc = error.localizedDescription
            env.setErrorMessage(errorDesc)
            env.batchUpdate {
                env.setIsLoading(false)
                let errorContent = "抱歉，发生了错误：\(errorDesc)"
                let errorItemId = turnIdFactory.makeItemId(baseId: baseId, kind: "error", part: "main")
                let errorMsg = Message(content: errorContent, role: .assistant, turnId: turnId, baseId: baseId, itemId: errorItemId)
                env.appendMessage(errorMsg)
                env.setIsTypingAnimating(false)
                env.setCurrentTurnId(nil)
            }
            logger.phase4("turn end | baseId=\(baseId) | reason=error | error=\(errorDesc)")
        }
    }
}
