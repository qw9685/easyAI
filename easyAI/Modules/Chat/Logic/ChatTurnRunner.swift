//
//  ChatTurnRunner.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 执行流式/非流式请求并聚合结果
//
//

import Foundation

struct ChatStreamProgress {
    let chunkCount: Int
    let fullContent: String
}

struct ChatStreamResult {
    let fullContent: String
    let chunkCount: Int
    let durationMs: Int
}

final class ChatTurnRunner {
    private let chatService: ChatServiceProtocol

    init(chatService: ChatServiceProtocol) {
        self.chatService = chatService
    }

    func runNonStream(messages: [Message], model: String, fallbackModelIDs: [String] = []) async throws -> ChatServiceResponse {
        try await chatService.sendMessage(messages: messages, model: model, fallbackModelIDs: fallbackModelIDs)
    }

    func runStream(
        messages: [Message],
        model: String,
        fallbackModelIDs: [String] = [],
        onProgress: @MainActor @escaping (ChatStreamProgress) -> Void
    ) async throws -> ChatStreamResult {
        var fullContent = ""
        var chunkCount = 0
        let startTime = Date()
        var lastChunkTime = startTime
        var totalChunkIntervalMs: Double = 0
        var maxChunkIntervalMs: Double = 0

        for try await chunk in chatService.sendMessageStream(messages: messages, model: model, fallbackModelIDs: fallbackModelIDs) {
            if Task.isCancelled {
                throw CancellationError()
            }
            let now = Date()
            let chunkIntervalMs = now.timeIntervalSince(lastChunkTime) * 1000
            lastChunkTime = now

            chunkCount += 1
            if chunkCount > 1 {
                totalChunkIntervalMs += chunkIntervalMs
                maxChunkIntervalMs = max(maxChunkIntervalMs, chunkIntervalMs)
            }
            fullContent += chunk

            if AppConfig.enablephaseLogs,
               (chunkCount == 1 || chunkCount % 40 == 0) {
                let avgChunkMs = chunkCount > 1
                    ? totalChunkIntervalMs / Double(chunkCount - 1)
                    : 0
                print(
                    "[ConversationPerf][stream] model=\(model) | chunks=\(chunkCount) | len=\(fullContent.count) | lastChunkMs=\(String(format: "%.1f", chunkIntervalMs)) | avgChunkMs=\(String(format: "%.1f", avgChunkMs))"
                )
            }

            await MainActor.run {
                onProgress(ChatStreamProgress(chunkCount: chunkCount, fullContent: fullContent))
            }
        }

        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
        if AppConfig.enablephaseLogs {
            let avgChunkMs = chunkCount > 1
                ? totalChunkIntervalMs / Double(chunkCount - 1)
                : 0
            print(
                "[ConversationPerf][stream] done | model=\(model) | chunks=\(chunkCount) | len=\(fullContent.count) | durationMs=\(durationMs) | avgChunkMs=\(String(format: "%.1f", avgChunkMs)) | maxChunkMs=\(String(format: "%.1f", maxChunkIntervalMs))"
            )
        }
        return ChatStreamResult(fullContent: fullContent, chunkCount: chunkCount, durationMs: durationMs)
    }
}
