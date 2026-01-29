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
    @Published var messages: [Message] = [] {
        didSet {
            emitSnapshotIfNeeded()
        }
    }
    @Published var isLoading: Bool = false {
        didSet {
            emitSnapshotIfNeeded()
        }
    }
    @Published var errorMessage: String?
    @Published private(set) var modelListState: ModelListState = .idle

    var selectedModel: AIModel? {
        get { modelListState.selectedModel }
        set {
            modelSelection.persistSelection(newValue)
            modelListState.selectedModel = newValue
        }
    }
    /// 当前是否有助手回复的打字机动画在进行中（用于禁用再次发送）
    @Published var isTypingAnimating: Bool = false {
        didSet { }
    }
    /// 用于停止打字机动画的 token
    @Published var animationStopToken: UUID = UUID()
    var availableModels: [AIModel] { modelListState.models }
    var isLoadingModels: Bool { modelListState.isLoading }
    @Published var conversations: [ConversationRecord] = []
    @Published private(set) var listSnapshot: ChatListSnapshot = .empty
    
    private var conversationId: UUID = UUID()
    private var currentTurnId: UUID?
    private var isBatchingSnapshot: Bool = false
    private var loadConversationsTask: Task<Void, Never>?
    
    private let chatService: ChatServiceProtocol
    private let contextBuilder: ChatContextBuilding
    private let specialResponsePolicy: SpecialResponsePolicy
    private let turnRunner: ChatTurnRunner
    private let persistence: ChatMessagePersistence
    private let conversationCoordinator: ConversationCoordinator
    private let sessionCoordinator: ChatSessionCoordinating
    private let modelSelection: ModelSelectionCoordinator
    private let turnIdFactory: ChatTurnIdFactory
    private let logger: ChatLogger
    private let sendMessageUseCase: ChatSendMessageUseCase
    @Published var currentConversationId: String? {
        didSet { emitSnapshotIfNeeded() }
    }
    
    /// 应用启动时加载模型列表（从API获取）
    func loadModels(forceRefresh: Bool = false) async {
        await MainActor.run {
            modelListState.isLoading = true
            modelListState.errorMessage = nil
        }

        let result = await modelSelection.loadModels(forceRefresh: forceRefresh)

        await MainActor.run {
            modelListState.models = result.models
            selectedModel = result.selected
            if result.models.isEmpty {
                modelListState.errorMessage = "无法加载在线模型列表，请检查网络连接或API配置"
            }
            modelListState.isLoading = false
        }
    }
    
    /// 发送给 OpenAI 的最大上下文消息条数（越小越省流量、越快，越大上下文越完整）
    private let maxContextMessages: Int = 20
    
    /// 本地保留的最大消息条数，用于避免长时间对话导致内存占用过大
    private let maxStoredMessages: Int = 200
    
    
    init(chatService: ChatServiceProtocol = OpenRouterChatService.shared,
         modelRepository: ModelRepositoryProtocol = ModelRepository.shared,
         conversationRepository: ConversationRepository = ConversationRepository.shared,
         messageRepository: MessageRepository = MessageRepository.shared) {
        self.chatService = chatService
        self.contextBuilder = ChatContextBuilder()
        self.specialResponsePolicy = DefaultSpecialResponsePolicy()
        self.turnRunner = ChatTurnRunner(chatService: chatService)
        self.persistence = ChatMessagePersistence(
            conversationRepository: conversationRepository,
            messageRepository: messageRepository
        )
        self.conversationCoordinator = ConversationCoordinator(
            conversationRepository: conversationRepository,
            messageRepository: messageRepository
        )
        self.sessionCoordinator = ChatSessionCoordinator()
        self.modelSelection = ModelSelectionCoordinator(modelRepository: modelRepository)
        self.turnIdFactory = ChatTurnIdFactory()
        self.logger = ChatLogger(isPhase4Enabled: { AppConfig.enablePhase4Logs })
        self.sendMessageUseCase = ChatSendMessageUseCase(
            specialResponsePolicy: self.specialResponsePolicy,
            modelSelection: self.modelSelection,
            turnRunner: self.turnRunner,
            turnIdFactory: self.turnIdFactory,
            logger: self.logger
        )
        // 可以添加欢迎消息
        // messages.append(Message(content: "您好！我是AI助手，有什么可以帮助您的吗？", role: .assistant))
        bootstrapConversation()
    }
    
    func loadConversations() {
        scheduleLoadConversations(debounceMs: 0)
    }
    
    func startNewConversation() {
        applySessionSnapshot(sessionCoordinator.startNewConversation())
    }
    
    func selectConversation(id: String) {
        Task {
            do {
                let loadedMessages = try conversationCoordinator.fetchMessages(conversationId: id)
                await MainActor.run {
                    self.applySessionSnapshot(
                        self.sessionCoordinator.selectConversation(
                            conversationId: id,
                            loadedMessages: loadedMessages
                        )
                    )
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
                try conversationCoordinator.renameConversation(id: id, title: trimmed)
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
                try conversationCoordinator.setPinned(id: id, isPinned: isPinned)
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
                try conversationCoordinator.deleteConversationAndMessages(id: id)
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
        let env = ChatSendMessageEnvironment(
            ensureConversation: { self.ensureConversation() },
            setAnimationStopToken: { self.animationStopToken = $0 },
            setCurrentTurnId: { self.currentTurnId = $0 },
            getSelectedModel: { self.selectedModel },
            buildMessagesForRequest: { self.buildMessagesForRequest(currentUserMessage: $0) },
            appendMessage: { self.appendMessage($0) },
            updateMessageContent: { messageId, content in self.updateMessageContent(messageId: messageId, content: content) },
            finalizeStreamingMessage: { messageId in self.finalizeStreamingMessage(messageId: messageId) },
            updatePersistedMessage: { message in
                await self.updatePersistedMessage(message)
            },
            batchUpdate: { updates in
                self.batchSnapshotUpdate(updates)
            },
            setIsLoading: { self.isLoading = $0 },
            setIsTypingAnimating: { self.isTypingAnimating = $0 },
            setErrorMessage: { self.errorMessage = $0 }
        )

        await sendMessageUseCase.execute(
            content: content,
            imageData: imageData,
            imageMimeType: imageMimeType,
            mediaContents: mediaContents,
            env: env
        )
    }
    
    @MainActor
    func clearMessages() {
        applySessionSnapshot(sessionCoordinator.clearMessages())
        logger.phase4("conversation reset | conversationId=\(conversationId.uuidString)")
        Task {
            await resetPersistence()
        }
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

    @MainActor
    private func updateMessageContent(messageId: UUID, content: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        messages[index].content = content
    }

    @MainActor
    private func finalizeStreamingMessage(messageId: UUID) -> Message? {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return nil }
        messages[index].isStreaming = false
        messages[index].wasStreamed = true
        return messages[index]
    }
    
    private func bootstrapConversation() {
        Task {
            await MainActor.run {
                self.applySessionSnapshot(self.sessionCoordinator.bootstrap())
            }
            scheduleLoadConversations(debounceMs: 0)
        }
    }
    
    private func persistMessage(_ message: Message) async {
        guard let conversationId = currentConversationId else { return }
        do {
            let now = Date()
            if let newTitle = try await persistence.persistNewMessage(message, conversationId: conversationId) {
                await MainActor.run {
                    if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
                        conversations[index].title = newTitle
                        conversations[index].updatedAt = now
                    }
                }
            }
            await MainActor.run {
                applyConversationTouch(conversationId: conversationId, touchedAt: now)
            }
        } catch {
            print("[ChatViewModel] ⚠️ Failed to persist message: \(error)")
        }
    }
    
    private func updatePersistedMessage(_ message: Message) async {
        guard let conversationId = currentConversationId else { return }
        do {
            let now = Date()
            try await persistence.updateMessage(message, conversationId: conversationId)
            await MainActor.run {
                applyConversationTouch(conversationId: conversationId, touchedAt: now)
            }
        } catch {
            print("[ChatViewModel] ⚠️ Failed to update message: \(error)")
        }
    }
    
    private func buildMessagesForRequest(currentUserMessage: Message) -> [Message] {
        contextBuilder.buildMessagesForRequest(
            allMessages: messages,
            currentUserMessage: currentUserMessage,
            strategy: AppConfig.contextStrategy,
            maxContextMessages: maxContextMessages
        )
    }
    
    private func resetPersistence() async {
        do {
            try await persistence.resetAll()
            await MainActor.run {
                self.currentConversationId = nil
            }
        } catch {
            print("[ChatViewModel] ⚠️ Failed to reset persistence: \(error)")
        }
    }
    
    @MainActor
    private func ensureConversation() -> Bool {
        if currentConversationId != nil {
            return true
        }
        do {
            let conversation = try conversationCoordinator.createConversation()
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

    private func applySessionSnapshot(_ snapshot: ChatSessionSnapshot) {
        batchSnapshotUpdate {
            currentConversationId = snapshot.currentConversationId
            messages = snapshot.messages
            conversationId = snapshot.conversationId
            turnIdFactory.conversationId = snapshot.conversationId
            currentTurnId = snapshot.currentTurnId
            if let token = snapshot.animationStopToken {
                animationStopToken = token
            }
        }
    }

    private func batchSnapshotUpdate(_ updates: () -> Void) {
        let wasBatching = isBatchingSnapshot
        isBatchingSnapshot = true
        updates()
        isBatchingSnapshot = wasBatching
        if !isBatchingSnapshot {
            emitSnapshot()
        }
    }

    private func emitSnapshotIfNeeded() {
        guard !isBatchingSnapshot else { return }
        emitSnapshot()
    }

    private func emitSnapshot() {
        listSnapshot = ChatListSnapshot(
            messages: messages,
            isLoading: isLoading,
            conversationId: currentConversationId
        )
    }

    private func scheduleLoadConversations(debounceMs: Int = 150) {
        loadConversationsTask?.cancel()
        loadConversationsTask = Task { [weak self] in
            guard let self else { return }
            if debounceMs > 0 {
                try? await Task.sleep(nanoseconds: UInt64(debounceMs) * 1_000_000)
            }
            guard !Task.isCancelled else { return }
            do {
                let records = try self.conversationCoordinator.fetchAllConversations()
                await MainActor.run {
                    self.conversations = records
                }
            } catch {
                print("[ChatViewModel] ⚠️ Failed to load conversations: \(error)")
            }
        }
    }

    @MainActor
    private func applyConversationTouch(conversationId: String, touchedAt: Date) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            // 极少数情况下（内存列表未同步），fallback 一次全量刷新。
            scheduleLoadConversations(debounceMs: 150)
            return
        }
        conversations[index].updatedAt = touchedAt
        conversations = conversations.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }
    
}
