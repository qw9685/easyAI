//
//  OpenAIService.swift
//  EasyAI
//
//  Created on 2024
//

import Foundation

class OpenAIService {
    static let shared = OpenAIService()
    
    private let urlSession: URLSession
    
    /// 复用 JSONDecoder，避免每次请求都创建
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()
    
    // 不同服务商的基础配置
    private struct ProviderConfig {
        let baseURL: String
        let apiKey: String
    }
    
    private init() {
        // 轻量优化的 URLSession 配置，避免不必要的缓存和过长超时
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: configuration)
    }
    
    /// 根据模型服务商选择对应的基础 URL 和 API Key
    private func providerConfiguration(for provider: ModelProvider) throws -> ProviderConfig {
        print("🔍 [OpenAIService] 检查 Provider 配置: \(provider.rawValue)")
        
        switch provider {
        case .openrouter:
            print("   OpenRouter API Key 长度: \(Config.openRouterAPIKey.count)")
            guard !Config.openRouterAPIKey.isEmpty else {
                print("❌ OpenRouter API Key 为空")
                throw OpenAIError.missingAPIKeyForProvider(.openrouter)
            }
            return ProviderConfig(
                baseURL: "https://openrouter.ai/api/v1/chat/completions",
                apiKey: Config.openRouterAPIKey
            )
        }
    }
    
    func sendMessage(messages: [Message], model: AIModel) async throws -> String {
        // 如果开启了 Mock 模式，直接返回本地假数据，方便在没有任何 Key 的情况下体验 App
        if Config.useMockData {
            return "（本地模拟回答）这是来自 \(model.name) 的示例回复。请在 Config.swift 中填写对应的 API Key 后即可调用真实在线模型。"
        }
        
        let providerConfig = try providerConfiguration(for: model.provider)
        
        // 打印调试信息
        print("🔵 [OpenAIService] 准备发送请求")
        print("   Provider: \(model.provider.rawValue)")
        print("   Model: \(model.apiModel)")
        print("   BaseURL: \(providerConfig.baseURL)")
        print("   API Key 长度: \(providerConfig.apiKey.count) 字符")
        print("   API Key 前缀: \(String(providerConfig.apiKey.prefix(10)))...")
        
        let requestBody: [String: Any] = [
            "model": model.apiModel,
            "messages": messages.map { message in
                [
                    "role": message.role.rawValue,
                    "content": message.content
                ]
            }
        ]
        
        // 打印请求体（不包含完整消息内容，避免日志过长）
        if let requestBodyData = try? JSONSerialization.data(withJSONObject: requestBody),
           let requestBodyString = String(data: requestBodyData, encoding: .utf8) {
            let preview = String(requestBodyString.prefix(500))
            print("   Request Body 预览: \(preview)...")
        }
        
        guard let url = URL(string: providerConfig.baseURL) else {
            print("❌ [OpenAIService] 无效的 URL: \(providerConfig.baseURL)")
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(providerConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // OpenRouter 需要额外的 HTTP-Referer header
        if model.provider == .openrouter {
            request.setValue("https://github.com/yourusername/easyAI", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("EasyAI", forHTTPHeaderField: "X-Title")
        }
        
        // 打印请求头信息
        print("   Request Headers:")
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                if key == "Authorization" {
                    let keyPrefix = String(value.prefix(20))
                    print("     \(key): \(keyPrefix)...")
                } else {
                    print("     \(key): \(value)")
                }
            }
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("   Request URL: \(url.absoluteString)")
        print("   Request Body 大小: \(request.httpBody?.count ?? 0) bytes")
        print("🟢 [OpenAIService] 开始发送网络请求...")
        
        // 复用自定义 URLSession，减少系统开销
        let (data, response) = try await urlSession.data(for: request)
        
        print("🟡 [OpenAIService] 收到响应")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [OpenAIService] 无效的 HTTP 响应")
            throw OpenAIError.invalidResponse
        }
        
        print("   Status Code: \(httpResponse.statusCode)")
        print("   Response Headers: \(httpResponse.allHeaderFields)")
        print("   Response Data 大小: \(data.count) bytes")
        
        if let responseString = String(data: data, encoding: .utf8) {
            let preview = String(responseString.prefix(1000))
            print("   Response Body 预览: \(preview)")
        }
        
        guard httpResponse.statusCode == 200 else {
            // 尝试解析 JSON 错误响应
            let errorMessage = parseErrorMessage(from: data, statusCode: httpResponse.statusCode)
            print("❌ [OpenAIService] API 错误: \(httpResponse.statusCode) - \(errorMessage)")
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let responseData = try OpenAIService.decoder.decode(OpenAIResponse.self, from: data)
        
        guard let content = responseData.choices.first?.message.content else {
            print("❌ [OpenAIService] 响应中未找到 content")
            throw OpenAIError.invalidResponse
        }
        
        print("✅ [OpenAIService] 请求成功，响应长度: \(content.count) 字符")
        return content
    }
    
    /// 解析 API 错误响应，提取友好的错误消息
    private func parseErrorMessage(from data: Data, statusCode: Int) -> String {
        // 尝试解析 JSON 错误格式：{"error":{"message":"...","code":"..."}}
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            
            // 针对常见错误提供更友好的提示
            if statusCode == 402 || message.lowercased().contains("insufficient balance") || message.lowercased().contains("余额不足") {
                return "账户余额不足，请前往 DeepSeek 平台充值后再试"
            }
            if statusCode == 401 || message.lowercased().contains("invalid api key") || message.lowercased().contains("unauthorized") {
                return "API Key 无效，请检查 Config.swift 中的配置"
            }
            if statusCode == 429 || message.lowercased().contains("rate limit") {
                return "请求过于频繁，请稍后再试"
            }
            
            return message
        }
        
        // 如果无法解析 JSON，返回原始文本或默认消息
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }
        
        return "未知错误（状态码: \(statusCode)）"
    }
    
    // MARK: - OpenRouter Models API
    
    /// 根据 OpenRouter API 文档获取所有可用模型列表
    /// 参考：https://openrouter.ai/docs/api/api-reference/models/get-models
    func fetchOpenRouterModels() async throws -> [OpenRouterModel] {
        guard !Config.openRouterAPIKey.isEmpty else {
            throw OpenAIError.missingAPIKeyForProvider(.openrouter)
        }
        
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(Config.openRouterAPIKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = parseErrorMessage(from: data, statusCode: httpResponse.statusCode)
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let modelsResponse = try OpenAIService.decoder.decode(OpenRouterModelsResponse.self, from: data)
        return modelsResponse.data
    }
}

// MARK: - OpenRouter Models Response
struct OpenRouterModelsResponse: Codable {
    let data: [OpenRouterModel]
}

struct OpenRouterModel: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let pricing: OpenRouterPricing
    let contextLength: Int?
    let architecture: OpenRouterArchitecture
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case pricing
        case contextLength = "context_length"
        case architecture
    }
}

struct OpenRouterPricing: Codable {
    let prompt: String
    let completion: String
    let request: String?
}

struct OpenRouterArchitecture: Codable {
    let modality: String?
    let inputModalities: [String]
    let outputModalities: [String]
    
    enum CodingKeys: String, CodingKey {
        case modality
        case inputModalities = "input_modalities"
        case outputModalities = "output_modalities"
    }
}

// MARK: - Response Models
struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: MessageResponse
        
        struct MessageResponse: Codable {
            let content: String
        }
    }
}

// MARK: - Errors
enum OpenAIError: LocalizedError {
    case missingAPIKey
    case missingAPIKeyForProvider(ModelProvider)
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API Key 未配置，请在 Config.swift 中设置您的 API Key"
        case .missingAPIKeyForProvider(let provider):
            return "未为服务商 \(provider.rawValue) 配置 API Key，请在 Config.swift 中填写对应的 Key。"
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "无效的响应"
        case .apiError(let statusCode, let message):
            return "API错误 (状态码: \(statusCode)): \(message)"
        }
    }
}

