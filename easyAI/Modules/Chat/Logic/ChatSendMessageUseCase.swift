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
    var getSelectedModel: @MainActor () -> AIModel?
    var buildMessagesForRequest: @MainActor (_ currentUserMessage: Message) -> [Message]

    var appendMessage: @MainActor (Message) -> Void
    var updateMessageContent: @MainActor (_ messageId: UUID, _ content: String) -> Void
    var finalizeStreamingMessage: @MainActor (_ messageId: UUID) -> Message?
    var updatePersistedMessage: (_ message: Message) async -> Void

    var batchUpdate: @MainActor (_ updates: () -> Void) -> Void
    var setIsLoading: @MainActor (Bool) -> Void
    var setErrorMessage: @MainActor (String?) -> Void
}

@MainActor
final class ChatSendMessageUseCase {
    private let modelSelection: ModelSelectionCoordinator
    private let turnRunner: ChatTurnRunner
    private let turnIdFactory: ChatTurnIdFactory
    private let logger: ChatLogger
    private var activeTypewriter: ChatTypewriter?

    init(
        modelSelection: ModelSelectionCoordinator,
        turnRunner: ChatTurnRunner,
        turnIdFactory: ChatTurnIdFactory,
        logger: ChatLogger
    ) {
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
        guard env.ensureConversation() else { return }
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
        let model: AIModel
        switch validation {
        case .ready(let selected):
            model = selected
        case .error(let message, let reason):
            let errorItemId = turnIdFactory.makeItemId(baseId: baseId, kind: "error", part: reason)
            let errorMsg = Message(content: message, role: .assistant, turnId: turnId, baseId: baseId, itemId: errorItemId)
            env.appendMessage(errorMsg)
            logger.phase("turn end | baseId=\(baseId) | reason=\(reason)")
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

                let messageId = assistantMessage.id
                logger.phase("assistant stream init | baseId=\(baseId) | itemId=\(assistantMessageItemId) | messageId=\(messageId.uuidString)")

                if !useTypewriter {
                    let result = try await turnRunner.runStream(
                        messages: messagesToSend,
                        model: model.apiModel,
                        onProgress: { progress in
                            env.updateMessageContent(messageId, progress.fullContent)
                            if progress.chunkCount == 1 || progress.chunkCount % 50 == 0 {
                                self.logger.phase(
                                    "stream chunk | baseId=\(baseId) | itemId=\(assistantMessageItemId) | chunks=\(progress.chunkCount) | len=\(progress.fullContent.count)"
                                )
                            }
                        }
                    )

                    let updated: Message? = await MainActor.run {
                        var updated: Message?
                        env.batchUpdate {
                            env.setIsLoading(false)
                            updated = env.finalizeStreamingMessage(messageId)
                        }
                        return updated
                    }

                    if let updated {
                        await env.updatePersistedMessage(updated)
                    }

                    logger.phase(
                        "turn end | baseId=\(baseId) | reason=closed | chunks=\(result.chunkCount) | len=\(result.fullContent.count) | durationMs=\(result.durationMs)"
                    )
                    env.setCurrentTurnId(nil)
                    return
                }

                var streamResult: ChatStreamResult?
                let typewriterConfig = ChatTypewriter.Config(
                    tickInterval: max(0.02, 0.08 / AppConfig.typewriterSpeed),
                    minCharsPerTick: 1,
                    maxCharsPerTick: 8
                )
                let typewriter = ChatTypewriter(
                    config: typewriterConfig,
                    updateDisplay: { text in
                        env.updateMessageContent(messageId, text)
                    },
                    onFinish: { [weak self] in
                        var updated: Message?
                        env.batchUpdate {
                            env.setIsLoading(false)
                            updated = env.finalizeStreamingMessage(messageId)
                        }
                        if let updated {
                            Task { await env.updatePersistedMessage(updated) }
                        }
                        if let result = streamResult {
                            self?.logger.phase(
                                "turn end | baseId=\(baseId) | reason=closed | chunks=\(result.chunkCount) | len=\(result.fullContent.count) | durationMs=\(result.durationMs)"
                            )
                        }
                        env.setCurrentTurnId(nil)
                        self?.activeTypewriter = nil
                    }
                )
                activeTypewriter = typewriter
                typewriter.start()

                let result = try await turnRunner.runStream(
                    messages: messagesToSend,
                    model: model.apiModel,
                    onProgress: { progress in
                        typewriter.updateTarget(progress.fullContent)
                        if progress.chunkCount == 1 || progress.chunkCount % 50 == 0 {
                            self.logger.phase(
                                "stream chunk | baseId=\(baseId) | itemId=\(assistantMessageItemId) | chunks=\(progress.chunkCount) | len=\(progress.fullContent.count)"
                            )
                        }
                    }
                )
                streamResult = result
                typewriter.updateTarget(result.fullContent)
                typewriter.markStreamEnded()
            } else {
                let messagesToSend = env.buildMessagesForRequest(userMessage)
                let response = try await turnRunner.runNonStream(messages: messagesToSend, model: model.apiModel)

                let assistantMessageItemId = turnIdFactory.makeItemId(baseId: baseId, kind: "assistant_final", part: "main")
                if !useTypewriter {
                    let assistantMessage = Message(
                        content: response,
                        role: .assistant,
                        turnId: turnId,
                        baseId: baseId,
                        itemId: assistantMessageItemId
                    )

                    env.batchUpdate {
                        env.setIsLoading(false)
                        env.appendMessage(assistantMessage)
                    }

                    logger.phase("turn end | baseId=\(baseId) | reason=non_stream_done | len=\(response.count)")
                    env.setCurrentTurnId(nil)
                    return
                }

                let assistantMessage = Message(
                    content: "",
                    role: .assistant,
                    isStreaming: true,
                    turnId: turnId,
                    baseId: baseId,
                    itemId: assistantMessageItemId
                )

                env.appendMessage(assistantMessage)

                let messageId = assistantMessage.id
                let typewriterConfig = ChatTypewriter.Config(
                    tickInterval: max(0.02, 0.08 / AppConfig.typewriterSpeed),
                    minCharsPerTick: 1,
                    maxCharsPerTick: 8
                )
                let typewriter = ChatTypewriter(
                    config: typewriterConfig,
                    updateDisplay: { text in
                        env.updateMessageContent(messageId, text)
                    },
                    onFinish: { [weak self] in
                        var updated: Message?
                        env.batchUpdate {
                            env.setIsLoading(false)
                            updated = env.finalizeStreamingMessage(messageId)
                        }
                        if let updated {
                            Task { await env.updatePersistedMessage(updated) }
                        }
                        self?.logger.phase("turn end | baseId=\(baseId) | reason=non_stream_done | len=\(response.count)")
                        env.setCurrentTurnId(nil)
                        self?.activeTypewriter = nil
                    }
                )
                activeTypewriter = typewriter
                typewriter.start()
                typewriter.updateTarget(response)
                typewriter.markStreamEnded()
            }
        } catch {
            activeTypewriter?.cancel()
            activeTypewriter = nil
            let errorDesc = error.localizedDescription
            env.setErrorMessage(errorDesc)
            env.batchUpdate {
                env.setIsLoading(false)
                let errorContent = "抱歉，发生了错误：\(errorDesc)"
                let errorItemId = turnIdFactory.makeItemId(baseId: baseId, kind: "error", part: "main")
                let errorMsg = Message(content: errorContent, role: .assistant, turnId: turnId, baseId: baseId, itemId: errorItemId)
                env.appendMessage(errorMsg)
                env.setCurrentTurnId(nil)
            }
            logger.phase("turn end | baseId=\(baseId) | reason=error | error=\(errorDesc)")
        }
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
        task = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func updateTarget(_ text: String) {
        if text.count >= targetText.count {
            targetText = text
        } else {
            targetText = text
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
                displayText = nextDisplayText(current: displayText, target: targetText)
                updateDisplay(safeDisplayText(displayText, isFinal: false))
            } else if streamEnded {
                updateDisplay(safeDisplayText(targetText, isFinal: true))
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

        let ranges = tableRanges(in: target)
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
