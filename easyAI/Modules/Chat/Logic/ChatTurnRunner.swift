//
//  ChatTurnRunner.swift
//  EasyAI
//
//  创建于 2026
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

    func runNonStream(messages: [Message], model: String) async throws -> String {
        try await chatService.sendMessage(messages: messages, model: model)
    }

    func runStream(
        messages: [Message],
        model: String,
        onProgress: @MainActor @escaping (ChatStreamProgress) -> Void
    ) async throws -> ChatStreamResult {
        var fullContent = ""
        var chunkCount = 0
        let startTime = Date()

        for try await chunk in chatService.sendMessageStream(messages: messages, model: model) {
            chunkCount += 1
            fullContent += chunk
            await onProgress(ChatStreamProgress(chunkCount: chunkCount, fullContent: fullContent))
        }

        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
        return ChatStreamResult(fullContent: fullContent, chunkCount: chunkCount, durationMs: durationMs)
    }
}

