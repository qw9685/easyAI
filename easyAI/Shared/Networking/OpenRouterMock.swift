//
//  OpenRouterMock.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - OpenRouter 模拟响应
//

import Foundation

struct OpenRouterMock {
    func response(messages: [Message], model: String) async throws -> String {
        try await Task.sleep(nanoseconds: 500_000_000)

        guard let lastMessage = messages.last else {
            return "您好！我是AI助手，有什么可以帮助您的吗？"
        }

        let userContent = lastMessage.content.lowercased()

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
            return "我理解您说的是：\"\(lastMessage.content)\"。这是一个很好的问题！在真实环境中，\(model)模型会为您提供详细的回答。当前使用的是模拟数据模式，您可以稍后配置API Key来使用真实的AI响应。"
        }
    }
}
