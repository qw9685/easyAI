//
//  OpenRouterRequestBuilder.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 构建 OpenRouter 请求
//

import Foundation

struct OpenRouterRequestBuilder {
    func makeChatRequest(messages: [Message], model: String, fallbackModelIDs: [String], stream: Bool) throws -> URLRequest {
        let runtime = OpenRouterRuntimeConfig.current()
        let apiKey = runtime.apiKey
        guard !apiKey.isEmpty && apiKey != "YOUR_OPENAI_API_KEY_HERE" else {
            throw OpenRouterError.missingAPIKey
        }
        guard let url = URL(string: OpenRouterConfig.chatURL) else {
            throw OpenRouterError.invalidURL
        }

        let maxTokens = runtime.maxTokens
        var requestBody: [String: Any] = [
            "model": model,
            "messages": MessageConverter.toOpenRouterFormat(messages),
            "max_tokens": maxTokens
        ]

        let fallbackChain = fallbackModelIDs
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !fallbackChain.isEmpty {
            requestBody["models"] = [model] + fallbackChain
        }
        if stream {
            requestBody["stream"] = true
        }

        if messages.contains(where: { $0.hasMedia }) {
            requestBody["max_tokens"] = min(maxTokens * 2, 4096)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = runtime.timeoutSeconds
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(OpenRouterConfig.referer, forHTTPHeaderField: "HTTP-Referer")
        request.setValue(OpenRouterConfig.appTitle, forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        if AppConfig.enablephaseLogs {
            print("[OpenRouterChatService] ▶️ Sending request")
            print("  • URL      :", OpenRouterConfig.chatURL)
            print("  • Model    :", model)
            if !fallbackChain.isEmpty {
                print("  • Fallback :", fallbackChain.joined(separator: " -> "))
            }
            print("  • Messages :", messages.count)

            if let jsonData = request.httpBody {
                let previewData = jsonData.prefix(1000)
                let preview = String(data: previewData, encoding: .utf8) ?? "<non-utf8 payload preview>"
                print("  • Request body preview:", preview)
                if jsonData.count > 1000 {
                    print("  • ... (truncated, total \(jsonData.count) bytes)")
                }
            }

            if messages.contains(where: { $0.hasMedia }) {
                let mediaCount = messages.filter { $0.hasMedia }.count
                print("  • Media    :", mediaCount, "message(s) with media")
                for message in messages where message.hasMedia {
                    let debugInfo = MessageConverter.getDebugInfo(message)
                    print("  • Message[\(message.id.uuidString.prefix(8))]: \(debugInfo)")
                }
            }
        }

        return request
    }

    func makeChatRequest(messages: [Message], model: String, stream: Bool) throws -> URLRequest {
        try makeChatRequest(messages: messages, model: model, fallbackModelIDs: [], stream: stream)
    }

    func makeModelsRequest() throws -> URLRequest {
        let runtime = OpenRouterRuntimeConfig.current()
        let apiKey = runtime.apiKey
        guard !apiKey.isEmpty && apiKey != "YOUR_OPENAI_API_KEY_HERE" else {
            throw OpenRouterError.missingAPIKey
        }
        guard let url = URL(string: OpenRouterConfig.modelsURL) else {
            throw OpenRouterError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = runtime.timeoutSeconds
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}
