import Foundation

enum ChatFailureKit {
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

    static func classifyOpenRouterError(_ error: OpenRouterError) -> ClassifiedChatError {
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

    static func classifyURLError(_ error: URLError) -> ClassifiedChatError {
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
