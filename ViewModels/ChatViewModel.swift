//
//  ChatViewModel.swift
//  EasyAI
//
//  Created on 2024
//

import Foundation
import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedModel: AIModel = AIModel.defaultModel
    /// 当前是否有助手回复的打字机动画在进行中（用于禁用再次发送）
    @Published var isTypingAnimating: Bool = false
    /// 是否启用打字机效果
    @Published var isTypewriterEnabled: Bool = true
    /// 用于停止打字机动画的 token
    @Published var animationStopToken: UUID = UUID()
    
    private let openAIService = OpenAIService.shared
    
    /// 发送给 OpenAI 的最大上下文消息条数（越小越省流量、越快，越大上下文越完整）
    private let maxContextMessages: Int = 20
    
    /// 本地保留的最大消息条数，用于避免长时间对话导致内存占用过大
    private let maxStoredMessages: Int = 200
    
    /// 打字机每个字符之间的间隔（纳秒），数值越小越快
    private let typewriterDelay: UInt64 = 20_000_000 // 20ms
    
    init() {
        // 可以添加欢迎消息
        // messages.append(Message(content: "您好！我是AI助手，有什么可以帮助您的吗？", role: .assistant))
    }
    
    @MainActor
    func sendMessage(_ content: String) async {
        // 停止当前正在进行的打字动画
        animationStopToken = UUID()
        
        // 检查是否是模型相关的问题
        if shouldUseSpecialResponse(for: content) {
            let specialResponse = "您好，我是由gpt-5.2-xhigh-fast模型提供支持，作为Cursor IDE的核心功能之一，可协助完成各类开发任务，只要是编程相关的问题，都可以问我！你现在有什么想做的吗？"
            let assistantMessage = Message(content: specialResponse, role: .assistant)
            appendMessage(assistantMessage)
            return
        }
        
        // 添加用户消息
        let userMessage = Message(content: content, role: .user)
        appendMessage(userMessage)
        
        isLoading = true
        errorMessage = nil
        
        do {
            // 准备发送给在线模型的消息
            // 只发送最近 maxContextMessages 条消息，减少网络负载与延迟
            let messagesToSend = Array(messages.suffix(maxContextMessages))
            
            // 根目录下的 OpenAIService 仍然使用 String 类型的 model 参数，这里传 apiModel
            let response = try await openAIService.sendMessage(
                messages: messagesToSend,
                model: selectedModel.apiModel
            )
            
            // 直接添加完整回复，打字机效果由 View 层的 TypewriterText 处理
            let assistantMessage = Message(content: response, role: .assistant)
            // 标记：即将开始打字机动画，在动画完成前不允许再次发送
            isTypingAnimating = true
            appendMessage(assistantMessage)
            
        } catch {
            let errorDesc = error.localizedDescription
            errorMessage = errorDesc
            // 添加错误消息到聊天记录
            let errorContent = "抱歉，发生了错误：\(errorDesc)"
            let errorMsg = Message(content: errorContent, role: .assistant)
            messages.append(errorMsg)
        }
        
        isLoading = false
    }
    
    @MainActor
    func clearMessages() {
        messages.removeAll()
        animationStopToken = UUID()
    }
    
    // 检查是否应该使用特殊回答
    private func shouldUseSpecialResponse(for content: String) -> Bool {
        let lowercased = content.lowercased()
        
        // 检查是否包含模型相关的问题
        let modelKeywords = ["什么模型", "谁", "你是谁", "什么ai", "什么模型提供", "什么模型支持", "什么模型驱动", "什么模型", "哪个模型"]
        let questionKeywords = ["是什么", "谁做的", "谁开发的", "谁创建的", "谁提供的"]
        
        // 检查是否包含模型关键词和问题关键词
        let hasModelKeyword = modelKeywords.contains { lowercased.contains($0) }
        let hasQuestionKeyword = questionKeywords.contains { lowercased.contains($0) }
        
        // 如果包含模型相关关键词或问题关键词，使用特殊回答
        return hasModelKeyword || (hasQuestionKeyword && (lowercased.contains("模型") || lowercased.contains("ai") || lowercased.contains("你")))
    }
    
    /// 统一追加消息并做数量裁剪，避免内存无限增长
    private func appendMessage(_ message: Message) {
        messages.append(message)
        
        if messages.count > maxStoredMessages {
            let overflow = messages.count - maxStoredMessages
            messages.removeFirst(overflow)
        }
    }
    
}

