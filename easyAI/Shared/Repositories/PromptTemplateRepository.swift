//
//  PromptTemplateRepository.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 提供内置 Prompt 模板
//

import Foundation

protocol PromptTemplateRepositoryProtocol {
    func fetchTemplates() -> [PromptTemplate]
}

final class PromptTemplateRepository: PromptTemplateRepositoryProtocol {
    static let shared = PromptTemplateRepository()

    private init() {}

    func fetchTemplates() -> [PromptTemplate] {
        [
            PromptTemplate(
                id: "summary_meeting",
                title: "会议纪要整理",
                promptTemplate: "请将下面的会议内容整理成结构化纪要，包含：结论、待办、负责人、截止时间。\n\n会议内容：\n",
                recommendedModelId: "openrouter-google/gemini-2.0-flash-001",
                defaultParams: ["temperature": "0.2"]
            ),
            PromptTemplate(
                id: "rewrite_polish",
                title: "润色改写",
                promptTemplate: "请在不改变原意的前提下润色下面文本，输出 3 个版本：正式、简洁、口语化。\n\n原文：\n",
                recommendedModelId: "openrouter-openai/gpt-4o-mini",
                defaultParams: ["temperature": "0.5"]
            ),
            PromptTemplate(
                id: "translate_bilingual",
                title: "中英双语翻译",
                promptTemplate: "请将下列内容翻译为中英双语，保留术语一致性，并给出术语对照表。\n\n内容：\n",
                recommendedModelId: "openrouter-anthropic/claude-3.5-haiku",
                defaultParams: ["temperature": "0.2"]
            ),
            PromptTemplate(
                id: "code_explain",
                title: "代码讲解",
                promptTemplate: "请解释下面代码的作用、关键流程、复杂度与潜在风险，并给出可改进建议。\n\n代码：\n",
                recommendedModelId: "openrouter-openai/gpt-4o-mini",
                defaultParams: ["temperature": "0.1"]
            ),
            PromptTemplate(
                id: "bug_fix",
                title: "Bug 定位修复",
                promptTemplate: "你是一名资深工程师。请基于报错和上下文定位根因，给出最小修复方案，并列出验证步骤。\n\n报错/上下文：\n",
                recommendedModelId: "openrouter-anthropic/claude-3.5-sonnet",
                defaultParams: ["temperature": "0.1"]
            ),
            PromptTemplate(
                id: "image_analysis",
                title: "图片分析",
                promptTemplate: "请分析我上传的图片，先客观描述，再给出关键要点与可执行建议。",
                recommendedModelId: "openrouter-google/gemini-2.0-flash-001",
                defaultParams: ["temperature": "0.2"]
            ),
            PromptTemplate(
                id: "plan_breakdown",
                title: "任务拆解",
                promptTemplate: "请把下面目标拆解为可执行计划（里程碑、优先级、风险、验收标准）。\n\n目标：\n",
                recommendedModelId: "openrouter-openai/gpt-4o-mini",
                defaultParams: ["temperature": "0.2"]
            ),
            PromptTemplate(
                id: "social_post",
                title: "社媒文案",
                promptTemplate: "请根据下面主题写 5 条社媒文案，语气自然，每条包含标题和正文。\n\n主题：\n",
                recommendedModelId: "openrouter-google/gemini-2.0-flash-001",
                defaultParams: ["temperature": "0.7"]
            )
        ]
    }
}

