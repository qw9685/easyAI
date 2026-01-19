//
//  OpenAIService.swift
//  EasyAI
//
//  Created on 2024
//

import Foundation

/// OpenRouter 聊天接口服务
/// 统一通过 OpenRouter 访问不同模型（Llama、Mistral、Qwen 等）
class OpenRouterService {
    static let shared = OpenRouterService()
    
    private let apiKey: String
    /// OpenRouter Chat Completions 接口
    /// 文档: https://openrouter.ai/docs/api-reference/chat/create
    private let baseURL = "https://openrouter.ai/api/v1/chat/completions"
    
    private init() {
        // 从配置或环境变量读取 API Key
        // 实际使用时应该从安全存储中读取
        self.apiKey = Config.apiKey
    }
    
    func sendMessage(messages: [Message], model: String) async throws -> String {
        // 如果启用 stream 模式，使用流式响应
        if Config.enableStream {
            let streamService = OpenRouterStreamService.shared
            var fullContent = ""
            for try await chunk in streamService.sendMessageStream(messages: messages, model: model) {
                fullContent += chunk
            }
            return fullContent
        }
        
        // 如果使用假数据模式，直接返回模拟响应
        if Config.useMockData {
            print("[OpenRouterService] MOCK request → model=\(model), messages=\(messages.count)")
            return try await mockResponse(messages: messages, model: model)
        }
        
        guard !apiKey.isEmpty && apiKey != "YOUR_OPENAI_API_KEY_HERE" else {
            throw OpenRouterError.missingAPIKey
        }
        
        // 构建请求体，添加合理的参数以控制成本
        // 使用配置中的 maxTokens，如果没有配置则使用默认值
        let maxTokens = Config.maxTokens > 0 ? Config.maxTokens : 1000
        
        var requestBody: [String: Any] = [
            "model": model,
            "messages": MessageConverter.toOpenRouterFormat(messages),
            "max_tokens": maxTokens  // 使用配置的 max_tokens，避免超出账户余额
        ]
        
        // 如果消息包含媒体内容，可能需要更多 tokens
        let hasMedia = messages.contains { $0.hasMedia }
        if hasMedia {
            // 对于多模态请求，适当增加 max_tokens（最多不超过配置值的2倍）
            requestBody["max_tokens"] = min(maxTokens * 2, 4096)
        }
        
        guard let url = URL(string: baseURL) else {
            throw OpenRouterError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // OpenRouter 推荐附带这两个 header（可选，用于统计与来源标识）
        request.setValue("https://github.com/yourusername/easyAI", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("EasyAI", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // 网络请求前的简单日志
        print("[OpenRouterService] ▶️ Sending request")
        print("  • URL      :", baseURL)
        print("  • Model    :", model)
        print("  • Messages :", messages.count)
        
        // 调试：打印请求体（仅前1000字符，避免太长）
        if let jsonData = request.httpBody,
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let preview = String(jsonString.prefix(1000))
            print("  • Request body preview:", preview)
            if jsonString.count > 1000 {
                print("  • ... (truncated, total \(jsonString.count) chars)")
            }
        }
        
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterError.invalidResponse
        }
        
        // 简单响应日志（不打印全部 JSON，避免太长）
        print("[OpenRouterService] ◀️ Response status =", httpResponse.statusCode)
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[OpenRouterService] ❌ API error:", errorMessage)
            
            // 检查是否是账户余额不足的错误
            if httpResponse.statusCode == 402 {
                let maxTokens = Config.maxTokens > 0 ? Config.maxTokens : 1000
                let friendlyMessage = "账户余额不足。\n\n错误详情：\(errorMessage)\n\n解决方案：\n1. 访问 https://openrouter.ai/settings/credits 充值\n2. 切换到免费模型（如 Gemini 2.0 Flash、Llama 3.1 8B 等）\n3. 在设置中减少 max_tokens 参数（当前设置为 \(maxTokens)）"
                throw OpenRouterError.insufficientCredits(message: friendlyMessage)
            }
            
            // 检查是否是模型ID无效的错误
            if httpResponse.statusCode == 400 {
                if errorMessage.contains("not a valid model ID") || errorMessage.contains("invalid model") {
                    let friendlyMessage = "模型ID无效：'\(model)'\n\n可能的原因：\n1. 模型ID格式不正确\n2. 模型已下架或改名\n3. 模型在OpenRouter上不可用\n\n解决方案：\n1. 打开模型选择器，从列表中选择可用模型\n2. 模型列表会自动从OpenRouter API获取最新的可用模型\n3. 建议使用：Gemini 2.0 Flash（免费，支持图片）"
                    throw OpenRouterError.invalidModelID(model: model, message: friendlyMessage)
                }
            }
            
            // 检查是否是模型找不到的错误
            if httpResponse.statusCode == 404 {
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
        
        let decoder = JSONDecoder()
        let responseData = try decoder.decode(OpenRouterChatResponse.self, from: data)
        
        guard let content = responseData.choices.first?.message.content else {
            throw OpenRouterError.invalidResponse
        }
        
        print("[OpenRouterService] ✅ responseData:", responseData)
        
        return content
    }
    
    /// 获取 OpenRouter 可用的模型列表
    /// 文档: https://openrouter.ai/docs/api-reference/models/list
    func fetchModels() async throws -> [OpenRouterModelInfo] {
        guard !apiKey.isEmpty && apiKey != "YOUR_OPENAI_API_KEY_HERE" else {
            throw OpenRouterError.missingAPIKey
        }
        
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else {
            throw OpenRouterError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("[OpenRouterService] 📋 Fetching models list...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterError.invalidResponse
        }
        
        print("[OpenRouterService] ◀️ Models response status =", httpResponse.statusCode)
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[OpenRouterService] ❌ API error:", errorMessage)
            throw OpenRouterError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // 打印 JSON 数据的前 1000 个字符用于调试
        if let jsonString = String(data: data, encoding: .utf8) {
            let preview = String(jsonString.prefix(1000))
            print("[OpenRouterService] 📄 JSON preview: \(preview)...")
        }
        
        let decoder = JSONDecoder()
        do {
            let modelsResponse = try decoder.decode(OpenRouterModelsResponse.self, from: data)
            print("[OpenRouterService] ✅ Fetched \(modelsResponse.data.count) models")
            return modelsResponse.data
        } catch {
            // 打印详细的解码错误信息
            print("[OpenRouterService] ❌ Decode error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("  Type mismatch: expected \(type), path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("  Value not found: \(type), path: \(context.codingPath)")
                case .keyNotFound(let key, let context):
                    print("  Key not found: \(key.stringValue), path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("  Data corrupted: \(context.debugDescription), path: \(context.codingPath)")
                @unknown default:
                    print("  Unknown decoding error")
                }
            }
            throw error
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

// MARK: - Response Models（OpenRouter Chat）
struct OpenRouterChatResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: MessageResponse
        
        struct MessageResponse: Codable {
            let content: String
        }
    }
}

// MARK: - Response Models（OpenRouter Models List）
struct OpenRouterModelsResponse: Codable {
    let data: [OpenRouterModelInfo]
}

struct OpenRouterModelInfo: Codable, Identifiable {
    let id: String
    let canonicalSlug: String?
    let name: String?
    let created: Int?
    let description: String?
    let pricing: OpenRouterPricing?
    let contextLength: Int?
    let architecture: OpenRouterArchitecture?
    let topProvider: OpenRouterProvider?
    let perRequestLimits: [String: AnyCodable]?
    let supportedParameters: [String]?
    let defaultParameters: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case canonicalSlug = "canonical_slug"
        case name
        case created
        case description
        case pricing
        case contextLength = "context_length"
        case architecture
        case topProvider = "top_provider"
        case perRequestLimits = "per_request_limits"
        case supportedParameters = "supported_parameters"
        case defaultParameters = "default_parameters"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        canonicalSlug = try container.decodeIfPresent(String.self, forKey: .canonicalSlug)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        created = try container.decodeIfPresent(Int.self, forKey: .created)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        pricing = try container.decodeIfPresent(OpenRouterPricing.self, forKey: .pricing)
        contextLength = try container.decodeIfPresent(Int.self, forKey: .contextLength)
        architecture = try container.decodeIfPresent(OpenRouterArchitecture.self, forKey: .architecture)
        topProvider = try container.decodeIfPresent(OpenRouterProvider.self, forKey: .topProvider)
        supportedParameters = try container.decodeIfPresent([String].self, forKey: .supportedParameters)
        
        // 处理可能为 null 或字典的字段
        perRequestLimits = try container.decodeIfPresent([String: AnyCodable].self, forKey: .perRequestLimits)
        defaultParameters = try container.decodeIfPresent([String: AnyCodable].self, forKey: .defaultParameters)
    }
}

struct OpenRouterPricing: Codable {
    let prompt: String?
    let completion: String?
    let request: String?
    let image: String?
}

struct OpenRouterArchitecture: Codable {
    let modality: String?
    let inputModalities: [String]?
    let outputModalities: [String]?
    let tokenizer: String?
    let instructType: String?
    
    enum CodingKeys: String, CodingKey {
        case modality
        case inputModalities = "input_modalities"
        case outputModalities = "output_modalities"
        case tokenizer
        case instructType = "instruct_type"
    }
}

struct OpenRouterProvider: Codable {
    let isModerated: Bool?
    let contextLength: Int?
    let maxCompletionTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case isModerated = "is_moderated"
        case contextLength = "context_length"
        case maxCompletionTokens = "max_completion_tokens"
    }
}

// 辅助类型用于解码 Any 类型
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // 首先检查是否是 null
        if container.decodeNil() {
            // 对于 null 值，我们使用一个特殊的标记值
            // 由于 Any 不能直接存储，我们使用一个空字典作为 null 的表示
            value = [String: Any]()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            // 如果都无法解码，使用空字典作为默认值
            value = [String: Any]()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
        }
    }
}

// MARK: - Errors
enum OpenRouterError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case modelNotSupportMultimodal(model: String, message: String)
    case modelNotFound(model: String, message: String)
    case insufficientCredits(message: String)
    case invalidModelID(model: String, message: String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenRouter API Key 未配置，请在 Config.swift 中设置。"
        case .invalidURL:
            return "无效的 OpenRouter URL"
        case .invalidResponse:
            return "OpenRouter 返回了无效响应"
        case .apiError(let statusCode, let message):
            return "OpenRouter API 错误 (状态码: \(statusCode)): \(message)"
        case .modelNotSupportMultimodal(_, let message):
            return message
        case .modelNotFound(_, let message):
            return message
        case .insufficientCredits(let message):
            return message
        case .invalidModelID(_, let message):
            return message
        }
    }
}

