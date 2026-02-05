//
//  OpenRouterChatService.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - OpenRouter 请求与 SSE 流式处理
//
//


import Foundation

/// OpenRouter 聊天接口服务（统一处理非流式与流式请求）
final class OpenRouterChatService: ChatServiceProtocol {
    static let shared = OpenRouterChatService()

    private let parser = SSEParser()
    private let requestBuilder = OpenRouterRequestBuilder()
    private let validator = OpenRouterResponseValidator()
    private let mock = OpenRouterMock()

    private init() {}

    // MARK: - Non-streaming
    func sendMessage(messages: [Message], model: String) async throws -> String {
        if AppConfig.enableStream {
            var fullContent = ""
            for try await chunk in sendMessageStream(messages: messages, model: model) {
                fullContent += chunk
            }
            return fullContent
        }

        if AppConfig.useMockData {
            print("[OpenRouterChatService] MOCK request → model=\(model), messages=\(messages.count)")
            return try await mock.response(messages: messages, model: model)
        }

        let request = try requestBuilder.makeChatRequest(messages: messages, model: model, stream: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try validator.validate(response: response, data: data, model: model)

        print("[OpenRouterChatService] ◀️ Response status =", httpResponse.statusCode)

        let decoder = JSONDecoder()
        let responseData = try decoder.decode(OpenRouterChatResponse.self, from: data)
        guard let content = responseData.choices.first?.message.content else {
            throw OpenRouterError.invalidResponse
        }

        return content
    }

    // MARK: - Streaming (SSE)
    func sendMessageStream(messages: [Message], model: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    if AppConfig.useMockData {
                        let mockContent = try await mock.response(messages: messages, model: model)
                        for char in mockContent {
                            try Task.checkCancellation()
                            continuation.yield(String(char))
                            try await Task.sleep(nanoseconds: 20_000_000)
                        }
                        continuation.finish()
                        return
                    }

                    try Task.checkCancellation()
                    let request = try requestBuilder.makeChatRequest(messages: messages, model: model, stream: true)
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                    try Task.checkCancellation()
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw OpenRouterError.invalidResponse
                    }

                    if httpResponse.statusCode != 200 {
                        var errorData = Data()
                        for try await byte in asyncBytes {
                            try Task.checkCancellation()
                            errorData.append(byte)
                        }
                        _ = try validator.validate(response: response, data: errorData, model: model)
                        continuation.finish()
                        return
                    }

                    for try await delta in parser.parse(asyncBytes: asyncBytes) {
                        try Task.checkCancellation()
                        continuation.yield(delta)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - Models
    func fetchModels() async throws -> [OpenRouterModelInfo] {
        let request = try requestBuilder.makeModelsRequest()

        print("[OpenRouterChatService] 📋 Fetching models list...")
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try validator.validate(response: response, data: data, model: nil)
        print("[OpenRouterChatService] ◀️ Models response status =", httpResponse.statusCode)

        let decoder = JSONDecoder()
        let modelsResponse = try decoder.decode(OpenRouterModelsResponse.self, from: data)
        print("[OpenRouterChatService] ✅ Fetched \(modelsResponse.data.count) models")
        return modelsResponse.data
    }

}
