//
//  ChatServiceProtocol.swift
//  EasyAI
//
//  Created by cc on 2026
//

import Foundation

protocol ChatServiceProtocol {
    func sendMessage(messages: [Message], model: String) async throws -> String
    func sendMessageStream(messages: [Message], model: String) -> AsyncThrowingStream<String, Error>
    func fetchModels() async throws -> [OpenRouterModelInfo]
}
