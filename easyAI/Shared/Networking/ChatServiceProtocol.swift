//
//  ChatServiceProtocol.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 聊天网络服务协议定义
//
//


import Foundation

struct ChatTokenUsage {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
}

struct ChatServiceResponse {
    let content: String
    let usage: ChatTokenUsage?
}

protocol ChatServiceProtocol {
    func sendMessage(messages: [Message], model: String, fallbackModelIDs: [String]) async throws -> ChatServiceResponse
    func sendMessageStream(messages: [Message], model: String, fallbackModelIDs: [String]) -> AsyncThrowingStream<String, Error>
    func fetchModels() async throws -> [OpenRouterModelInfo]
}

extension ChatServiceProtocol {
    func sendMessage(messages: [Message], model: String) async throws -> ChatServiceResponse {
        try await sendMessage(messages: messages, model: model, fallbackModelIDs: [])
    }

    func sendMessageStream(messages: [Message], model: String) -> AsyncThrowingStream<String, Error> {
        sendMessageStream(messages: messages, model: model, fallbackModelIDs: [])
    }
}
