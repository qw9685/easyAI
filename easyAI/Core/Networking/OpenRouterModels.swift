//
//  OpenRouterModels.swift
//  EasyAI
//
//  Created by cc on 2026
//

import Foundation

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

// MARK: - AnyCodable
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
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
            return "OpenRouter API Key 未配置，请在设置中添加或在 Info.plist 中配置。"
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
