//
//  OpenRouterResponseValidator.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 统一校验 HTTP 响应与错误映射
//

import Foundation

struct OpenRouterResponseValidator {
    @discardableResult
    func validate(response: URLResponse, data: Data?, model: String?) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
            if AppConfig.enablephaseLogs {
                RuntimeTools.AppDiagnostics.warn("OpenRouterChatService", "❌ API error: \(errorMessage)")
            }

            if httpResponse.statusCode == 402 {
                let maxTokens = OpenRouterRuntimeConfig.current().maxTokens
                let friendlyMessage = "账户余额不足。\n\n错误详情：\(errorMessage)\n\n解决方案：\n1. 访问 https://openrouter.ai/settings/credits 充值\n2. 切换到免费模型（如 Gemini 2.0 Flash、Llama 3.1 8B 等）\n3. 在设置中减少 max_tokens 参数（当前设置为 \(maxTokens)）"
                throw OpenRouterError.insufficientCredits(message: friendlyMessage)
            }

            if httpResponse.statusCode == 400, let model = model {
                let lowercasedErrorMessage = errorMessage.lowercased()
                if lowercasedErrorMessage.contains("not a valid model id") ||
                    lowercasedErrorMessage.contains("invalid model") {
                    let friendlyMessage = "模型ID无效：'\(model)'\n\n可能的原因：\n1. 模型ID格式不正确\n2. 模型已下架或改名\n3. 模型在OpenRouter上不可用\n\n解决方案：\n1. 打开模型选择器，从列表中选择可用模型\n2. 模型列表会自动从OpenRouter API获取最新的可用模型\n3. 建议使用：Gemini 2.0 Flash（免费，支持图片）"
                    throw OpenRouterError.invalidModelID(model: model, message: friendlyMessage)
                }
            }

            if httpResponse.statusCode == 404, let model = model {
                let lowercasedErrorMessage = errorMessage.lowercased()
                if lowercasedErrorMessage.contains("no endpoints found that support") {
                    let friendlyMessage = "当前模型不支持图片输入。请切换到支持多模态的模型（如 GPT-4 Vision、Claude 3、Gemini 等）。"
                    throw OpenRouterError.modelNotSupportMultimodal(model: model, message: friendlyMessage)
                } else if lowercasedErrorMessage.contains("no endpoints found") {
                    let friendlyMessage = "模型 '\(model)' 在 OpenRouter 上不可用。\n\n可能的原因：\n1. 模型ID不正确\n2. 模型已下架或改名\n3. 需要API密钥权限\n\n建议切换到其他可用模型，或从模型列表中选择。"
                    throw OpenRouterError.modelNotFound(model: model, message: friendlyMessage)
                }
            }

            throw OpenRouterError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        return httpResponse
    }
}
