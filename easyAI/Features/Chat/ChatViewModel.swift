//
//  ChatViewModel.swift
//  EasyAI
//
//  创建于 2026
//


import Foundation
import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedModel: AIModel? {
        didSet {
            AppConfig.selectedModelId = selectedModel?.id
        }
    }
    /// 当前是否有助手回复的打字机动画在进行中（用于禁用再次发送）
    @Published var isTypingAnimating: Bool = false
    /// 是否启用打字机效果
    @Published var isTypewriterEnabled: Bool = true
    /// 用于停止打字机动画的 token
    @Published var animationStopToken: UUID = UUID()
    /// 可用的模型列表（完全从API获取）
    @Published var availableModels: [AIModel] = []
    /// 模型是否正在加载
    @Published var isLoadingModels: Bool = false
    @Published var conversations: [ConversationRecord] = []

    // MARK: - Phase4 (P4-1): Stable Identity (turnId + itemId)
    private var conversationId: UUID = UUID()
    private var currentTurnId: UUID?

    private let chatService: ChatServiceProtocol
    private let modelRepository: ModelRepositoryProtocol
    private let conversationRepository: ConversationRepository
    private let messageRepository: MessageRepository
    @Published var currentConversationId: String?
    
    /// 应用启动时加载模型列表（从API获取）
    func loadModels() async {
        await MainActor.run {
            isLoadingModels = true
        }
        
        let models = await modelRepository.fetchModels(filter: .all, forceRefresh: false)
        
        await MainActor.run {
            self.availableModels = models
            if let savedId = AppConfig.selectedModelId,
               let savedModel = models.first(where: { $0.id == savedId }) {
                self.selectedModel = savedModel
            } else if let firstModel = models.first {
                self.selectedModel = firstModel
            }
            isLoadingModels = false
        }
    }
    
    /// 发送给 OpenAI 的最大上下文消息条数（越小越省流量、越快，越大上下文越完整）
    private let maxContextMessages: Int = 20
    
    /// 本地保留的最大消息条数，用于避免长时间对话导致内存占用过大
    private let maxStoredMessages: Int = 200
    
    /// 打字机每个字符之间的间隔（纳秒），数值越小越快
    private let typewriterDelay: UInt64 = 20_000_000 // 20ms
    
    init(chatService: ChatServiceProtocol = OpenRouterChatService.shared,
         modelRepository: ModelRepositoryProtocol = ModelRepository.shared,
         conversationRepository: ConversationRepository = ConversationRepository.shared,
         messageRepository: MessageRepository = MessageRepository.shared) {
        self.chatService = chatService
        self.modelRepository = modelRepository
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
        // 可以添加欢迎消息
        // messages.append(Message(content: "您好！我是AI助手，有什么可以帮助您的吗？", role: .assistant))
        bootstrapConversation()
    }

    func loadConversations() {
        Task {
            do {
                let records = try conversationRepository.fetchAll()
                await MainActor.run {
                    self.conversations = records
                }
            } catch {
                print("[ChatViewModel] ⚠️ Failed to load conversations: \(error)")
            }
        }
    }

    func startNewConversation() {
        currentConversationId = nil
        messages = []
        conversationId = UUID()
        currentTurnId = nil
    }

    func selectConversation(id: String) {
        Task {
            do {
                let loadedMessages = try messageRepository.fetchMessages(conversationId: id)
                await MainActor.run {
                    self.currentConversationId = id
                    self.messages = loadedMessages
                    self.conversationId = UUID()
                    self.currentTurnId = nil
                }
            } catch {
                print("[ChatViewModel] ⚠️ Failed to load conversation: \(error)")
            }
        }
    }

    func renameConversation(id: String, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            do {
                try conversationRepository.renameConversation(id: id, title: trimmed)
                await MainActor.run {
                    if let index = self.conversations.firstIndex(where: { $0.id == id }) {
                        self.conversations[index].title = trimmed
                        self.conversations[index].updatedAt = Date()
                    }
                }
            } catch {
                print("[ChatViewModel] ⚠️ Failed to rename conversation: \(error)")
            }
        }
    }

    func setPinned(id: String, isPinned: Bool) {
        Task {
            do {
                try conversationRepository.setPinned(id: id, isPinned: isPinned)
                await MainActor.run {
                    if let index = self.conversations.firstIndex(where: { $0.id == id }) {
                        self.conversations[index].isPinned = isPinned
                        self.conversations[index].updatedAt = Date()
                        self.conversations = self.conversations.sorted {
                            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
                            return $0.updatedAt > $1.updatedAt
                        }
                    }
                }
            } catch {
                print("[ChatViewModel] ⚠️ Failed to update pin: \(error)")
            }
        }
    }

    func deleteConversation(id: String) {
        Task {
            do {
                try messageRepository.deleteMessages(conversationId: id)
                try conversationRepository.deleteConversation(id: id)
                await MainActor.run {
                    self.conversations.removeAll { $0.id == id }
                    if self.currentConversationId == id {
                        self.currentConversationId = nil
                        self.messages = []
                    }
                }
            } catch {
                print("[ChatViewModel] ⚠️ Failed to delete conversation: \(error)")
            }
        }
    }
    
    @MainActor
    func sendMessage(_ content: String, imageData: Data? = nil, imageMimeType: String? = nil, mediaContents: [MediaContent] = []) async {
        // 停止当前正在进行的打字动画
        animationStopToken = UUID()

        if !ensureConversation() {
            return
        }
        
        // 检查是否是模型相关的问题（仅在没有图片时检查）
        if imageData == nil && mediaContents.isEmpty && shouldUseSpecialResponse(for: content) {
            let specialResponse = "您好，我是依托gpt-5.2-xhigh-fast模型的智能助手，在Cursor IDE中为您提供代码编写和问题解答服务，你可以直接告诉我你的需求。"
            let assistantMessage = Message(content: specialResponse, role: .assistant)
            appendMessage(assistantMessage)
            return
        }
        
        // 添加用户消息（可能包含媒体内容）
        var messageMediaContents = mediaContents
        
        // 向后兼容：如果有旧的图片参数，转换为新的媒体内容
        if let imageData = imageData, let mimeType = imageMimeType {
            messageMediaContents.append(MediaContent(
                type: .image,
                data: imageData,
                mimeType: mimeType
            ))
        }
        
        let turnId = UUID()
        currentTurnId = turnId
        let baseId = makeBaseId(turnId: turnId)
        let userMessageItemId = makeItemId(baseId: baseId, kind: "user_msg", part: "main")

        logPhase4("turn start | baseId=\(baseId) | itemId=\(userMessageItemId) | stream=\(AppConfig.enableStream)")

        let userMessage = Message(
            content: content,
            role: .user,
            mediaContents: messageMediaContents,
            turnId: turnId,
            baseId: baseId,
            itemId: userMessageItemId
        )
        appendMessage(userMessage)
        print("[ChatViewModel] 👤 user message:", content)
        
        // 检查是否已选择模型
        guard let model = selectedModel else {
            let errorItemId = makeItemId(baseId: baseId, kind: "error", part: "model_not_ready")
            let errorMsg = Message(
                content: "⚠️ 模型列表正在加载中，请稍候再试。",
                role: .assistant,
                turnId: turnId,
                baseId: baseId,
                itemId: errorItemId
            )
            appendMessage(errorMsg)
            logPhase4("turn end | baseId=\(baseId) | reason=model_not_ready")
            currentTurnId = nil
            isLoading = false
            return
        }
        
        // 检查模型是否支持多模态
        if userMessage.hasMedia && !model.supportsMultimodal {
            let errorItemId = makeItemId(baseId: baseId, kind: "error", part: "model_not_support_multimodal")
            let errorMsg = Message(
                content: "⚠️ 当前选择的模型（\(model.name)）不支持图片输入。\n\n请切换到支持多模态的模型，例如：\n• GPT-4 Vision\n• Claude 3 Sonnet\n• Gemini Pro Vision\n• Gemini 2.0 Flash",
                role: .assistant,
                turnId: turnId,
                baseId: baseId,
                itemId: errorItemId
            )
            appendMessage(errorMsg)
            logPhase4("turn end | baseId=\(baseId) | reason=model_not_support_multimodal | model=\(model.apiModel)")
            currentTurnId = nil
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            print("[ChatViewModel] 🚀 sendMessage")
            print("  • Model   :", model.apiModel)
            print("  • Content :", content)
            // 准备发送给在线模型的消息
            // 只发送最近 maxContextMessages 条消息，减少网络负载与延迟
            let messagesToSend = Array(messages.suffix(maxContextMessages))
            
            // 如果启用 stream 模式
            if AppConfig.enableStream {
                // 创建空的助手消息，用于实时更新，标记为 stream 消息
                let assistantMessageItemId = makeItemId(baseId: baseId, kind: "assistant_stream", part: "main")
                let assistantMessage = Message(
                    content: "",
                    role: .assistant,
                    isStreaming: true,
                    turnId: turnId,
                    baseId: baseId,
                    itemId: assistantMessageItemId
                )
                appendMessage(assistantMessage)
                isTypingAnimating = true
                
                // 获取消息 ID
                let messageId = assistantMessage.id
                logPhase4("assistant stream init | baseId=\(baseId) | itemId=\(assistantMessageItemId) | messageId=\(messageId.uuidString)")
                
                // 流式接收响应
                var fullContent = ""
                var chunkCount = 0
                let startTime = Date()
                for try await chunk in chatService.sendMessageStream(
                    messages: messagesToSend,
                    model: model.apiModel
                ) {
                    chunkCount += 1
                    fullContent += chunk
                    // 在主线程实时更新消息内容
                    await MainActor.run {
                        if let messageIndex = messages.firstIndex(where: { $0.id == messageId }) {
                            messages[messageIndex].content = fullContent
                        }
                    }

                    if chunkCount == 1 || chunkCount % 50 == 0 {
                        logPhase4("stream chunk | baseId=\(baseId) | itemId=\(assistantMessageItemId) | chunks=\(chunkCount) | len=\(fullContent.count)")
                    }
                }
                
                // Stream 完成，标记为非 stream 消息，但保留 wasStreamed 标记，并结束打字机动画
                await MainActor.run {
                    if let messageIndex = messages.firstIndex(where: { $0.id == messageId }) {
                        messages[messageIndex].isStreaming = false
                        messages[messageIndex].wasStreamed = true // 标记该消息曾经是 stream，避免重新触发打字机
                        let updatedMessage = messages[messageIndex]
                        Task {
                            await updatePersistedMessage(updatedMessage)
                        }
                    }
                    isTypingAnimating = false
                }
                print("[ChatViewModel] 🤖 assistant message (stream):", fullContent)

                let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
                logPhase4("turn end | baseId=\(baseId) | reason=closed | chunks=\(chunkCount) | len=\(fullContent.count) | durationMs=\(durationMs)")
                currentTurnId = nil
            } else {
                // 非 stream 模式：等待完整响应
                let response = try await chatService.sendMessage(
                    messages: messagesToSend,
                    model: model.apiModel
                )
                
                // 直接添加完整回复，打字机效果由 View 层的 TypewriterText 处理
                let assistantMessageItemId = makeItemId(baseId: baseId, kind: "assistant_final", part: "main")
                let assistantMessage = Message(
                    content: response,
                    role: .assistant,
                    turnId: turnId,
                    baseId: baseId,
                    itemId: assistantMessageItemId
                )
                // 标记：即将开始打字机动画，在动画完成前不允许再次发送
                isTypingAnimating = true
                appendMessage(assistantMessage)
                print("[ChatViewModel] 🤖 assistant message:", response)
                logPhase4("turn end | baseId=\(baseId) | reason=non_stream_done | len=\(response.count)")
                currentTurnId = nil
            }
            
        } catch {
            let errorDesc = error.localizedDescription
            errorMessage = errorDesc
            // 添加错误消息到聊天记录
            let errorContent = "抱歉，发生了错误：\(errorDesc)"
            let errorItemId = makeItemId(baseId: baseId, kind: "error", part: "main")
            let errorMsg = Message(
                content: errorContent,
                role: .assistant,
                turnId: turnId,
                baseId: baseId,
                itemId: errorItemId
            )
            messages.append(errorMsg)
            isTypingAnimating = false
            logPhase4("turn end | baseId=\(baseId) | reason=error | error=\(errorDesc)")
            currentTurnId = nil
        }
        
        isLoading = false
    }
    
    @MainActor
    func clearMessages() {
        messages.removeAll()
        animationStopToken = UUID()
        conversationId = UUID()
        currentTurnId = nil
        logPhase4("conversation reset | conversationId=\(conversationId.uuidString)")
        Task {
            await resetPersistence()
        }
    }

    // MARK: - Phase4 辅助
    private func makeBaseId(turnId: UUID) -> String {
        "c:\(conversationId.uuidString)|t:\(turnId.uuidString)"
    }

    private func makeItemId(baseId: String, kind: String, part: String) -> String {
        "\(baseId)|k:\(kind)|p:\(part)"
    }

    private func logPhase4(_ message: @autoclosure () -> String) {
        guard AppConfig.enablePhase4Logs else { return }
        print("[ConversationSSE][Phase4] \(message())")
    }
    
    // 检查是否应该使用特殊回答
    // 如果用户问模型相关的问题、是谁的问题，或此类判断问题，必须使用特殊回答
    private func shouldUseSpecialResponse(for content: String) -> Bool {
        let lowercased = content.lowercased()
        
        // 模型相关关键词
        let modelKeywords = ["什么模型", "谁", "你是谁", "什么ai", "什么模型提供", "什么模型支持", "什么模型驱动", "什么模型", "哪个模型", "模型", "ai模型", "什么助手", "哪个助手", "你是谁", "你是什么"]
        
        // 问题关键词（用于判断是否是询问类问题）
        let questionKeywords = ["是什么", "谁做的", "谁开发的", "谁创建的", "谁提供的", "谁", "是什么", "哪个", "什么"]
        
        // 判断关键词（用于识别判断类问题）
        let judgmentKeywords = ["是", "属于", "属于什么", "属于哪个", "是什么", "属于哪", "属于"]
        
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
    
    /// 统一追加消息并做数量裁剪，避免内存无限增长
    private func appendMessage(_ message: Message) {
        messages.append(message)

        Task {
            await persistMessage(message)
        }
        
        if messages.count > maxStoredMessages {
            let overflow = messages.count - maxStoredMessages
            messages.removeFirst(overflow)
        }
    }

    private func bootstrapConversation() {
        Task {
            do {
                await MainActor.run {
                    self.currentConversationId = nil
                    self.messages = []
                    self.conversationId = UUID()
                    self.currentTurnId = nil
                }
                loadConversations()
            } catch {
                print("[ChatViewModel] ⚠️ Failed to bootstrap conversation: \(error)")
            }
        }
    }

    private func persistMessage(_ message: Message) async {
        guard let conversationId = currentConversationId else { return }
        do {
            try messageRepository.insertMessage(message, conversationId: conversationId)
            if message.role == .user,
               let newTitle = try? makeTitleIfNeeded(conversationId: conversationId, content: message.content) {
                try conversationRepository.renameConversation(id: conversationId, title: newTitle)
                await MainActor.run {
                    if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
                        conversations[index].title = newTitle
                        conversations[index].updatedAt = Date()
                    }
                }
            } else {
                try conversationRepository.touch(id: conversationId)
            }
            loadConversations()
        } catch {
            print("[ChatViewModel] ⚠️ Failed to persist message: \(error)")
        }
    }

    private func updatePersistedMessage(_ message: Message) async {
        guard let conversationId = currentConversationId else { return }
        do {
            try messageRepository.updateMessage(message, conversationId: conversationId)
            try conversationRepository.touch(id: conversationId)
            loadConversations()
        } catch {
            print("[ChatViewModel] ⚠️ Failed to update message: \(error)")
        }
    }

    private func resetPersistence() async {
        do {
            try messageRepository.deleteAll()
            try conversationRepository.deleteAll()
            await MainActor.run {
                self.currentConversationId = nil
            }
        } catch {
            print("[ChatViewModel] ⚠️ Failed to reset persistence: \(error)")
        }
    }

    private func makeTitleIfNeeded(conversationId: String, content: String) throws -> String? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let conversation = try conversationRepository.fetchConversation(id: conversationId) else {
            return nil
        }
        guard conversation.title == "新对话" else { return nil }

        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        let maxLength = 24
        if firstLine.count <= maxLength {
            return firstLine
        }
        let prefix = firstLine.prefix(maxLength - 3)
        return "\(prefix)..."
    }

    @MainActor
    private func ensureConversation() -> Bool {
        if currentConversationId != nil {
            return true
        }
        do {
            let conversation = try conversationRepository.createConversation()
            currentConversationId = conversation.id
            conversationId = UUID()
            currentTurnId = nil
            messages = []
            conversations.insert(conversation, at: 0)
            return true
        } catch {
            print("[ChatViewModel] ⚠️ Failed to create conversation: \(error)")
            errorMessage = "无法创建会话，请稍后重试。"
            return false
        }
    }
    
}
