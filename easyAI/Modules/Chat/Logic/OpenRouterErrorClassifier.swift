//
//  OpenRouterErrorClassifier.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 统一分类 OpenRouter 错误
//

import Foundation

enum ChatErrorCategory: String {
    case missingAPIKey
    case insufficientCredits
    case invalidModel
    case modelNotFound
    case modelNotSupportMultimodal
    case contextTooLong
    case rateLimited
    case serverUnavailable
    case timeout
    case network
    case cancelled
    case unknown

    var isRetryable: Bool {
        switch self {
        case .rateLimited, .serverUnavailable, .timeout, .network:
            return true
        default:
            return false
        }
    }
}

struct ClassifiedChatError {
    let category: ChatErrorCategory
    let userMessage: String
    let technicalMessage: String

    var recoverySuggestion: String? {
        switch category {
        case .rateLimited:
            return "请稍后重试，或切换到更稳定的模型。"
        case .insufficientCredits:
            return "请检查 OpenRouter 余额或更换免费模型。"
        case .contextTooLong:
            return "建议清空部分历史消息后重试。"
        case .timeout:
            return "请检查网络后重试，必要时切换模型。"
        case .serverUnavailable:
            return "可稍后重试，或临时切换其他模型。"
        case .network:
            return "请检查网络连接后重试。"
        case .missingAPIKey:
            return "请前往设置页填写有效 API Key。"
        default:
            return nil
        }
    }

    var bannerMessage: String {
        guard let recoverySuggestion, !recoverySuggestion.isEmpty else {
            return userMessage
        }
        return "\(userMessage) \(recoverySuggestion)"
    }

    var statusMessage: String {
        let categoryText: String
        switch category {
        case .rateLimited:
            categoryText = "限流"
        case .insufficientCredits:
            categoryText = "余额不足"
        case .contextTooLong:
            categoryText = "上下文超限"
        case .timeout:
            categoryText = "请求超时"
        case .serverUnavailable:
            categoryText = "服务不可用"
        case .network:
            categoryText = "网络异常"
        case .missingAPIKey:
            categoryText = "缺少 API Key"
        case .invalidModel:
            categoryText = "模型无效"
        case .modelNotFound:
            categoryText = "模型不存在"
        case .modelNotSupportMultimodal:
            categoryText = "模型不支持多模态"
        case .cancelled:
            categoryText = "已取消"
        case .unknown:
            categoryText = "未知错误"
        }

        guard let recoverySuggestion, !recoverySuggestion.isEmpty else {
            return categoryText
        }
        return "\(categoryText)：\(recoverySuggestion)"
    }
}

enum OpenRouterErrorClassifier {
    static func classify(_ error: Error) -> ClassifiedChatError {
        if error is CancellationError {
            return ClassifiedChatError(
                category: .cancelled,
                userMessage: "请求已取消",
                technicalMessage: "cancelled"
            )
        }

        if let openRouterError = error as? OpenRouterError {
            return classifyOpenRouterError(openRouterError)
        }

        if let urlError = error as? URLError {
            return classifyURLError(urlError)
        }

        let description = error.localizedDescription
        let lower = description.lowercased()

        if lower.contains("timed out") || lower.contains("timeout") {
            return ClassifiedChatError(
                category: .timeout,
                userMessage: "请求超时，请稍后重试。",
                technicalMessage: description
            )
        }

        if lower.contains("network") || lower.contains("internet") {
            return ClassifiedChatError(
                category: .network,
                userMessage: "网络异常，请检查网络后重试。",
                technicalMessage: description
            )
        }

        return ClassifiedChatError(
            category: .unknown,
            userMessage: description,
            technicalMessage: description
        )
    }

    private static func classifyOpenRouterError(_ error: OpenRouterError) -> ClassifiedChatError {
        switch error {
        case .missingAPIKey:
            return ClassifiedChatError(
                category: .missingAPIKey,
                userMessage: "请先在设置中填写 OpenRouter API Key",
                technicalMessage: error.localizedDescription
            )
        case .insufficientCredits(let message):
            return ClassifiedChatError(
                category: .insufficientCredits,
                userMessage: message,
                technicalMessage: message
            )
        case .invalidModelID(_, let message):
            return ClassifiedChatError(
                category: .invalidModel,
                userMessage: message,
                technicalMessage: message
            )
        case .modelNotFound(_, let message):
            return ClassifiedChatError(
                category: .modelNotFound,
                userMessage: message,
                technicalMessage: message
            )
        case .modelNotSupportMultimodal(_, let message):
            return ClassifiedChatError(
                category: .modelNotSupportMultimodal,
                userMessage: message,
                technicalMessage: message
            )
        case .apiError(let statusCode, let message):
            if statusCode == 408 {
                return ClassifiedChatError(
                    category: .timeout,
                    userMessage: "请求超时，请稍后重试。",
                    technicalMessage: message
                )
            }
            if statusCode == 429 {
                return ClassifiedChatError(
                    category: .rateLimited,
                    userMessage: "请求过于频繁，已触发限流。",
                    technicalMessage: message
                )
            }
            if (500...599).contains(statusCode) {
                return ClassifiedChatError(
                    category: .serverUnavailable,
                    userMessage: "服务暂时不可用，请稍后重试。",
                    technicalMessage: message
                )
            }
            let lower = message.lowercased()
            if lower.contains("context") || lower.contains("maximum context") || lower.contains("max tokens") {
                return ClassifiedChatError(
                    category: .contextTooLong,
                    userMessage: "上下文过长，请尝试减少历史消息或降低最大 Token。",
                    technicalMessage: message
                )
            }
            return ClassifiedChatError(
                category: .unknown,
                userMessage: "OpenRouter 请求失败：\(message)",
                technicalMessage: message
            )
        case .invalidResponse:
            return ClassifiedChatError(
                category: .serverUnavailable,
                userMessage: "服务响应异常，请稍后重试。",
                technicalMessage: error.localizedDescription
            )
        case .invalidURL:
            return ClassifiedChatError(
                category: .unknown,
                userMessage: "请求地址无效，请检查配置。",
                technicalMessage: error.localizedDescription
            )
        }
    }

    private static func classifyURLError(_ error: URLError) -> ClassifiedChatError {
        switch error.code {
        case .timedOut:
            return ClassifiedChatError(
                category: .timeout,
                userMessage: "请求超时，请稍后重试。",
                technicalMessage: error.localizedDescription
            )
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost:
            return ClassifiedChatError(
                category: .network,
                userMessage: "网络异常，请检查网络后重试。",
                technicalMessage: error.localizedDescription
            )
        default:
            return ClassifiedChatError(
                category: .unknown,
                userMessage: error.localizedDescription,
                technicalMessage: error.localizedDescription
            )
        }
    }
}
