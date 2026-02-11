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
