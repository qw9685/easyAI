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

protocol ChatServiceProtocol {
    func sendMessage(messages: [Message], model: String) async throws -> String
    func sendMessageStream(messages: [Message], model: String) -> AsyncThrowingStream<String, Error>
    func fetchModels() async throws -> [OpenRouterModelInfo]
}
