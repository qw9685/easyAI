//
//  SpecialResponsePolicy.swift
//  EasyAI
//
//  创建于 2026
//

import Foundation

protocol SpecialResponsePolicy {
    func shouldUseSpecialResponse(for content: String) -> Bool
    var specialResponseText: String { get }
}

struct DefaultSpecialResponsePolicy: SpecialResponsePolicy {
    let specialResponseText: String = "您好，我是依托gpt-5.2-xhigh-fast模型的智能助手，在Cursor IDE中为您提供代码编写和问题解答服务，你可以直接告诉我你的需求。"

    func shouldUseSpecialResponse(for content: String) -> Bool {
        let lowercased = content.lowercased()

        // 模型相关关键词
        let modelKeywords = [
            "什么模型", "谁", "你是谁", "什么ai", "什么模型提供", "什么模型支持", "什么模型驱动",
            "哪个模型", "模型", "ai模型", "什么助手", "哪个助手", "你是什么",
        ]

        // 问题关键词（用于判断是否是询问类问题）
        let questionKeywords = ["是什么", "谁做的", "谁开发的", "谁创建的", "谁提供的", "哪个", "什么"]

        // 判断关键词（用于识别判断类问题）
        let judgmentKeywords = ["是", "属于", "属于什么", "属于哪个", "属于哪"]

        // 检查是否包含模型相关关键词
        let hasModelKeyword = modelKeywords.contains { lowercased.contains($0) }

        // 检查是否包含问题关键词
        let hasQuestionKeyword = questionKeywords.contains { lowercased.contains($0) }

        // 检查是否包含判断关键词
        let hasJudgmentKeyword = judgmentKeywords.contains { lowercased.contains($0) }

        // 如果包含模型相关关键词，直接使用特殊回答
        if hasModelKeyword {
            return true
        }

        // 如果包含问题关键词，且内容涉及模型、AI、助手等，使用特殊回答
        if hasQuestionKeyword && (lowercased.contains("模型") || lowercased.contains("ai") || lowercased.contains("助手") || lowercased.contains("你")) {
            return true
        }

        // 如果包含判断关键词，且内容涉及模型、AI、助手等，使用特殊回答
        if hasJudgmentKeyword && (lowercased.contains("模型") || lowercased.contains("ai") || lowercased.contains("助手")) {
            return true
        }

        return false
    }
}

