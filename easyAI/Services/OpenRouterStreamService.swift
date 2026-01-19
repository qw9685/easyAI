//
//  OpenRouterStreamService.swift
//  EasyAI
//
//  Created on 2024
//

import Foundation

/// OpenRouter 流式响应服务
/// 专门处理 Server-Sent Events (SSE) 格式的流式响应
class OpenRouterStreamService {
    static let shared = OpenRouterStreamService()
    
    private let apiKey: String
    /// OpenRouter Chat Completions 接口
    /// 文档: https://openrouter.ai/docs/api-reference/chat/create
    private let baseURL = "https://openrouter.ai/api/v1/chat/completions"
    
    private init() {
        // 从配置或环境变量读取 API Key
        self.apiKey = Config.apiKey
    }
    
    /// 流式发送消息（Server-Sent Events）
    func sendMessageStream(messages: [Message], model: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // 如果使用假数据模式，模拟流式响应
                    if Config.useMockData {
                        let mockContent = try await mockResponse(messages: messages, model: model)
                        // 模拟逐字符发送
                        for char in mockContent {
                            continuation.yield(String(char))
                            try await Task.sleep(nanoseconds: 20_000_000) // 20ms
                        }
                        continuation.finish()
                        return
                    }
                    
                    guard !apiKey.isEmpty && apiKey != "YOUR_OPENAI_API_KEY_HERE" else {
                        continuation.finish(throwing: OpenRouterError.missingAPIKey)
                        return
                    }
                    
                    // 构建请求体，添加合理的参数以控制成本
                    // 使用配置中的 maxTokens，如果没有配置则使用默认值
                    let maxTokens = Config.maxTokens > 0 ? Config.maxTokens : 1000
                    
                    var requestBody: [String: Any] = [
                        "model": model,
                        "messages": MessageConverter.toOpenRouterFormat(messages),
                        "stream": true,
                        "max_tokens": maxTokens  // 使用配置的 max_tokens，避免超出账户余额
                    ]
                    
                    // 如果消息包含媒体内容，可能需要更多 tokens
                    let hasMedia = messages.contains { $0.hasMedia }
                    if hasMedia {
                        // 对于多模态请求，适当增加 max_tokens（最多不超过配置值的2倍）
                        requestBody["max_tokens"] = min(maxTokens * 2, 4096)
                    }
                    
                    guard let url = URL(string: baseURL) else {
                        continuation.finish(throwing: OpenRouterError.invalidURL)
                        return
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("https://github.com/yourusername/easyAI", forHTTPHeaderField: "HTTP-Referer")
                    request.setValue("EasyAI", forHTTPHeaderField: "X-Title")
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    
                    print("[OpenRouterStreamService] ▶️ Sending stream request")
                    print("  • URL      :", baseURL)
                    print("  • Model    :", model)
                    print("  • Messages :", messages.count)
                    
                    // 检查是否有媒体消息
                    let hasMediaMessages = messages.contains { $0.hasMedia }
                    if hasMediaMessages {
                        let mediaCount = messages.filter { $0.hasMedia }.count
                        print("  • Media    :", mediaCount, "message(s) with media")
                        
                        // 打印每个媒体消息的详细信息
                        for message in messages where message.hasMedia {
                            let debugInfo = MessageConverter.getDebugInfo(message)
                            print("  • Message[\(message.id.uuidString.prefix(8))]: \(debugInfo)")
                        }
                    }
                    
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: OpenRouterError.invalidResponse)
                        return
                    }
                    
                    print("[OpenRouterStreamService] ◀️ Stream response status =", httpResponse.statusCode)
                    
                    guard httpResponse.statusCode == 200 else {
                        var errorData = Data()
                        for try await byte in asyncBytes {
                            errorData.append(byte)
                        }
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        print("[OpenRouterStreamService] ❌ Stream API error:", errorMessage)
                        
                        // 检查是否是账户余额不足的错误
                        if httpResponse.statusCode == 402 {
                            let maxTokens = Config.maxTokens > 0 ? Config.maxTokens : 1000
                            let friendlyMessage = "账户余额不足。\n\n错误详情：\(errorMessage)\n\n解决方案：\n1. 访问 https://openrouter.ai/settings/credits 充值\n2. 切换到免费模型（如 Gemini 2.0 Flash、Llama 3.1 8B 等）\n3. 在设置中减少 max_tokens 参数（当前设置为 \(maxTokens)）"
                            continuation.finish(throwing: OpenRouterError.insufficientCredits(message: friendlyMessage))
                            return
                        }
                        
                        // 检查是否是模型ID无效的错误
                        if httpResponse.statusCode == 400 {
                            if errorMessage.contains("not a valid model ID") || errorMessage.contains("invalid model") {
                                let friendlyMessage = "模型ID无效：'\(model)'\n\n可能的原因：\n1. 模型ID格式不正确\n2. 模型已下架或改名\n3. 模型在OpenRouter上不可用\n\n解决方案：\n1. 打开模型选择器，从列表中选择可用模型\n2. 模型列表会自动从OpenRouter API获取最新的可用模型\n3. 建议使用：Gemini 2.0 Flash（免费，支持图片）"
                                continuation.finish(throwing: OpenRouterError.invalidModelID(model: model, message: friendlyMessage))
                                return
                            }
                        }
                        
                        // 检查是否是模型找不到的错误
                        if httpResponse.statusCode == 404 {
                            if errorMessage.contains("No endpoints found") {
                                let friendlyMessage = "模型 '\(model)' 在 OpenRouter 上不可用。\n\n可能的原因：\n1. 模型ID不正确\n2. 模型已下架或改名\n3. 需要API密钥权限\n\n建议切换到其他可用模型，或从模型列表中选择。"
                                continuation.finish(throwing: OpenRouterError.modelNotFound(model: model, message: friendlyMessage))
                                return
                            } else if errorMessage.contains("No endpoints found that support") {
                                let friendlyMessage = "当前模型不支持图片输入。请切换到支持多模态的模型（如 GPT-4 Vision、Claude 3、Gemini 等）。"
                                continuation.finish(throwing: OpenRouterError.modelNotSupportMultimodal(model: model, message: friendlyMessage))
                                return
                            }
                        }
                        
                        continuation.finish(throwing: OpenRouterError.apiError(statusCode: httpResponse.statusCode, message: errorMessage))
                        return
                    }
                    
                    // 解析 Server-Sent Events (SSE) 格式
                    var buffer = Data()
                    for try await byte in asyncBytes {
                        buffer.append(byte)
                        
                        // 查找完整的行（以 \n 结尾，可能前面有 \r）
                        if let newlineIndex = buffer.firstIndex(of: 0x0A) { // \n
                            var lineData = buffer[..<newlineIndex]
                            buffer = buffer[buffer.index(after: newlineIndex)...]
                            
                            // 移除可能的 \r（如果行以 \r\n 结尾）
                            if lineData.last == 0x0D {
                                lineData = lineData.dropLast()
                            }
                            
                            guard let line = String(data: lineData, encoding: .utf8) else {
                                continue
                            }
                            
                            // 处理 SSE 数据行
                            if line.hasPrefix("data: ") {
                                let jsonString = String(line.dropFirst(6)) // 移除 "data: " 前缀
                                
                                // 检查是否是结束标记
                                if jsonString.trimmingCharacters(in: .whitespaces) == "[DONE]" {
                                    continuation.finish()
                                    return
                                }
                                
                                // 解析 JSON
                                if let jsonData = jsonString.data(using: .utf8) {
                                    do {
                                        let decoder = JSONDecoder()
                                        let streamResponse = try decoder.decode(OpenRouterStreamResponse.self, from: jsonData)
                                        
                                        // 提取 delta content
                                        if let delta = streamResponse.choices.first?.delta.content, !delta.isEmpty {
                                            continuation.yield(delta)
                                        }
                                    } catch {
                                        // 忽略解析错误，继续处理下一个数据块
                                        print("[OpenRouterStreamService] ⚠️ Failed to parse SSE data: \(error)")
                                        if let jsonPreview = String(data: jsonData.prefix(200), encoding: .utf8) {
                                            print("  JSON preview: \(jsonPreview)")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // 处理剩余的 buffer（如果有）
                    if !buffer.isEmpty, let remainingString = String(data: buffer, encoding: .utf8) {
                        if remainingString.hasPrefix("data: ") {
                            let jsonString = String(remainingString.dropFirst(6))
                            if jsonString.trimmingCharacters(in: .whitespaces) != "[DONE]" {
                                if let jsonData = jsonString.data(using: .utf8) {
                                    do {
                                        let decoder = JSONDecoder()
                                        let streamResponse = try decoder.decode(OpenRouterStreamResponse.self, from: jsonData)
                                        if let delta = streamResponse.choices.first?.delta.content, !delta.isEmpty {
                                            continuation.yield(delta)
                                        }
                                    } catch {
                                        print("[OpenRouterStreamService] ⚠️ Failed to parse final SSE data: \(error)")
                                    }
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Mock Data
    private func mockResponse(messages: [Message], model: String) async throws -> String {
        // 模拟网络延迟
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        guard let lastMessage = messages.last else {
            return "您好！我是AI助手，有什么可以帮助您的吗？"
        }
        
        let userContent = lastMessage.content.lowercased()
        
        // 根据用户输入返回不同的模拟响应
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
            // 默认响应：回应用户的问题
            return "我理解您说的是：\"\(lastMessage.content)\"。这是一个很好的问题！在真实环境中，\(model)模型会为您提供详细的回答。当前使用的是模拟数据模式，您可以稍后配置API Key来使用真实的AI响应。"
        }
    }
}

// MARK: - Stream Response Models
struct OpenRouterStreamResponse: Codable {
    let choices: [StreamChoice]
    
    struct StreamChoice: Codable {
        let delta: Delta
        
        struct Delta: Codable {
            let content: String?
        }
    }
}

