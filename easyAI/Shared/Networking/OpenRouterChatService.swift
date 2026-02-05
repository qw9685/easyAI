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

/// OpenRouter 聊天接口服务
/// 统一处理非流式与流式请求
final class OpenRouterChatService: ChatServiceProtocol {
    static let shared = OpenRouterChatService()

    private let baseURL = "https://openrouter.ai/api/v1/chat/completions"
    private let modelsURL = "https://openrouter.ai/api/v1/models"
    private let parser = SSEParser()

    private init() {}

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
            return try await mockResponse(messages: messages, model: model)
        }

        let request = try buildRequest(messages: messages, model: model, stream: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try validate(response: response, data: data, model: model)

        print("[OpenRouterChatService] ◀️ Response status =", httpResponse.statusCode)

        let decoder = JSONDecoder()
        let responseData = try decoder.decode(OpenRouterChatResponse.self, from: data)
        guard let content = responseData.choices.first?.message.content else {
            throw OpenRouterError.invalidResponse
        }

        return content
    }

    func sendMessageStream(messages: [Message], model: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    if AppConfig.useMockData {
                        let mockContent = try await mockResponse(messages: messages, model: model)
                        for char in mockContent {
                            try Task.checkCancellation()
                            continuation.yield(String(char))
                            try await Task.sleep(nanoseconds: 20_000_000)
                        }
                        continuation.finish()
                        return
                    }

                    try Task.checkCancellation()
                    let request = try buildRequest(messages: messages, model: model, stream: true)
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
                        _ = try validate(response: response, data: errorData, model: model)
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

    func fetchModels() async throws -> [OpenRouterModelInfo] {
        let apiKey = AppConfig.apiKey
        guard !apiKey.isEmpty && apiKey != "YOUR_OPENAI_API_KEY_HERE" else {
            throw OpenRouterError.missingAPIKey
        }
        guard let url = URL(string: modelsURL) else {
            throw OpenRouterError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = AppConfig.requestTimeoutSeconds
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        print("[OpenRouterChatService] 📋 Fetching models list...")
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try validate(response: response, data: data, model: nil)
        print("[OpenRouterChatService] ◀️ Models response status =", httpResponse.statusCode)

        let decoder = JSONDecoder()
        let modelsResponse = try decoder.decode(OpenRouterModelsResponse.self, from: data)
        print("[OpenRouterChatService] ✅ Fetched \(modelsResponse.data.count) models")
        return modelsResponse.data
    }

    // MARK: - 辅助方法
    private func buildRequest(messages: [Message], model: String, stream: Bool) throws -> URLRequest {
        let apiKey = AppConfig.apiKey
        guard !apiKey.isEmpty && apiKey != "YOUR_OPENAI_API_KEY_HERE" else {
            throw OpenRouterError.missingAPIKey
        }
        guard let url = URL(string: baseURL) else {
            throw OpenRouterError.invalidURL
        }

        let maxTokens = AppConfig.maxTokens > 0 ? AppConfig.maxTokens : 1000
        var requestBody: [String: Any] = [
            "model": model,
            "messages": MessageConverter.toOpenRouterFormat(messages),
            "max_tokens": maxTokens
        ]
        if stream {
            requestBody["stream"] = true
        }

        if messages.contains(where: { $0.hasMedia }) {
            requestBody["max_tokens"] = min(maxTokens * 2, 4096)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = AppConfig.requestTimeoutSeconds
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://github.com/yourusername/easyAI", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("EasyAI", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("[OpenRouterChatService] ▶️ Sending request")
        print("  • URL      :", baseURL)
        print("  • Model    :", model)
        print("  • Messages :", messages.count)

        if let jsonData = request.httpBody,
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let preview = String(jsonString.prefix(1000))
            print("  • Request body preview:", preview)
            if jsonString.count > 1000 {
                print("  • ... (truncated, total \(jsonString.count) chars)")
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

        return request
    }

    @discardableResult
    private func validate(response: URLResponse, data: Data?, model: String?) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
            print("[OpenRouterChatService] ❌ API error:", errorMessage)

            if httpResponse.statusCode == 402 {
                let maxTokens = AppConfig.maxTokens > 0 ? AppConfig.maxTokens : 1000
                let friendlyMessage = "账户余额不足。\n\n错误详情：\(errorMessage)\n\n解决方案：\n1. 访问 https://openrouter.ai/settings/credits 充值\n2. 切换到免费模型（如 Gemini 2.0 Flash、Llama 3.1 8B 等）\n3. 在设置中减少 max_tokens 参数（当前设置为 \(maxTokens)）"
                throw OpenRouterError.insufficientCredits(message: friendlyMessage)
            }

            if httpResponse.statusCode == 400, let model = model {
                if errorMessage.contains("not a valid model ID") || errorMessage.contains("invalid model") {
                    let friendlyMessage = "模型ID无效：'\(model)'\n\n可能的原因：\n1. 模型ID格式不正确\n2. 模型已下架或改名\n3. 模型在OpenRouter上不可用\n\n解决方案：\n1. 打开模型选择器，从列表中选择可用模型\n2. 模型列表会自动从OpenRouter API获取最新的可用模型\n3. 建议使用：Gemini 2.0 Flash（免费，支持图片）"
                    throw OpenRouterError.invalidModelID(model: model, message: friendlyMessage)
                }
            }

            if httpResponse.statusCode == 404, let model = model {
                if errorMessage.contains("No endpoints found") {
                    let friendlyMessage = "模型 '\(model)' 在 OpenRouter 上不可用。\n\n可能的原因：\n1. 模型ID不正确\n2. 模型已下架或改名\n3. 需要API密钥权限\n\n建议切换到其他可用模型，或从模型列表中选择。"
                    throw OpenRouterError.modelNotFound(model: model, message: friendlyMessage)
                } else if errorMessage.contains("No endpoints found that support") {
                    let friendlyMessage = "当前模型不支持图片输入。请切换到支持多模态的模型（如 GPT-4 Vision、Claude 3、Gemini 等）。"
                    throw OpenRouterError.modelNotSupportMultimodal(model: model, message: friendlyMessage)
                }
            }

            throw OpenRouterError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        return httpResponse
    }

    // MARK: - 模拟数据
    private func mockResponse(messages: [Message], model: String) async throws -> String {
        try await Task.sleep(nanoseconds: 500_000_000)

        guard let lastMessage = messages.last else {
            return "您好！我是AI助手，有什么可以帮助您的吗？"
        }

        let userContent = lastMessage.content.lowercased()

        if userContent.contains("你好") || userContent.contains("hello") || userContent.contains("hi") {
            return "您好！很高兴为您服务。我是\(model)模型，有什么可以帮助您的吗？"
        } else if userContent.contains("名字") || userContent.contains("name") {
            return "我是EasyAI助手，由\(model)模型驱动。"
        } else if userContent.contains("功能") || userContent.contains("能做什么") || userContent.contains("what can") {
            return "我可以回答您的问题、进行对话、帮助您解决问题。请随时向我提问！"
        } else if userContent.contains("天气") || userContent.contains("weather") {
            return "抱歉，我目前无法获取实时天气信息。但如果您有其他问题，我很乐意帮助您！"
        } else if userContent.contains("时间") || userContent.contains("time") {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
            return "当前时间是：\(formatter.string(from: Date()))"
        } else {
            return "我理解您说的是：\"\(lastMessage.content)\"。这是一个很好的问题！在真实环境中，\(model)模型会为您提供详细的回答。当前使用的是模拟数据模式，您可以稍后配置API Key来使用真实的AI响应。"
        }
    }
}
