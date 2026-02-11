//
//  ChatViewModel.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 聊天核心状态与会话管理
//  - 协调发送、持久化、模型加载与快照
//
//


import Foundation
import RxSwift
import RxCocoa

@MainActor
final class ChatViewModel {
    private var messages: [Message] = [] {
        didSet {
            emitSnapshotIfNeeded()
        }
    }
    private(set) var isLoading: Bool = false {
        didSet {
            isLoadingRelay.accept(isLoading)
            emitSnapshotIfNeeded()
        }
    }
    private(set) var errorMessage: String? {
        didSet {
            errorMessageRelay.accept(errorMessage)
        }
    }
    private(set) var modelListState: ModelListState = .idle {
        didSet {
            modelListStateRelay.accept(modelListState)
        }
    }

    var selectedModel: AIModel? {
        get { modelListState.selectedModel }
        set {
            modelSelection.persistSelection(newValue)
            modelListState.selectedModel = newValue
        }
    }
    var availableModels: [AIModel] { modelListState.models }
    var isLoadingModels: Bool { modelListState.isLoading }
    private(set) var conversations: [ConversationRecord] = [] {
        didSet {
            conversationsRelay.accept(conversations)
        }
    }
    private(set) var listSnapshot: ChatListSnapshot = .empty {
        didSet {
            listSnapshotRelay.accept(listSnapshot)
        }
    }
    private(set) var isSwitchingConversation: Bool = false {
        didSet {
            isSwitchingConversationRelay.accept(isSwitchingConversation)
        }
    }
    private var stopNotices: [ChatStopNotice] = []
    private var inputDisposeBag = DisposeBag()
    private let eventRelay = PublishRelay<Event>()
    private let listSnapshotRelay = BehaviorRelay<ChatListSnapshot>(value: .empty)
    private let conversationsRelay = BehaviorRelay<[ConversationRecord]>(value: [])
    private let modelListStateRelay = BehaviorRelay<ModelListState>(value: .idle)
    private let isSwitchingConversationRelay = BehaviorRelay<Bool>(value: false)
    private let errorMessageRelay = BehaviorRelay<String?>(value: nil)
    private let isLoadingRelay = BehaviorRelay<Bool>(value: false)
    
    private var conversationId: UUID = UUID()
    private var currentTurnId: UUID?
    private var isBatchingSnapshot: Bool = false
    private var pendingMessageContentUpdates: [UUID: String] = [:]
    private var isMessageContentFlushScheduled: Bool = false
    private var isResettingPersistence: Bool = false
    
    private let chatService: ChatServiceProtocol
    private let contextBuilder: ChatContextBuilding
    private let turnRunner: ChatTurnRunner
    private let persistence: ChatMessagePersistence
    private let conversationUseCase: ConversationListUseCase
    private let sessionCoordinator: ChatSessionCoordinating
    private let modelSelection: ModelSelectionCoordinator
    private let turnIdFactory: ChatTurnIdFactory
    private let logger: ChatLogger
    private let sendMessageUseCase: ChatSendMessageUseCase
    private var activeSendTask: Task<Void, Never>?
    private var activeSendTaskToken: UUID?
    private var latestSelectionRequestId: UUID?
    private var currentConversationId: String? {
        didSet { emitSnapshotIfNeeded() }
    }

    struct SendPayload {
        let content: String
        let imageData: Data?
        let imageMimeType: String?
        let mediaContents: [MediaContent]
    }

    enum Event {
        case switchToChat
        case switchToSettings
    }

    enum Action {
        case loadModels(forceRefresh: Bool)
        case loadConversations
        case startNewConversation
        case selectConversation(String)
        case renameConversation(id: String, title: String)
        case setPinned(id: String, isPinned: Bool)
        case deleteConversation(String)
        case deleteMessage(UUID)
        case sendMessage(SendPayload)
        case stopGenerating
        case clearMessages
    }

    struct Input {
        let actions: Observable<Action>
    }

    struct Output {
        let listSnapshot: Observable<ChatListSnapshot>
        let conversations: Observable<[ConversationRecord]>
        let modelListState: Observable<ModelListState>
        let isSwitchingConversation: Observable<Bool>
        let errorMessage: Observable<String?>
        let events: Observable<Event>
    }

    var events: Observable<Event> {
        eventRelay.asObservable()
    }

    var listSnapshotObservable: Observable<ChatListSnapshot> {
        listSnapshotRelay.asObservable()
    }

    var conversationsObservable: Observable<[ConversationRecord]> {
        conversationsRelay.asObservable()
    }

    var modelListStateObservable: Observable<ModelListState> {
        modelListStateRelay.asObservable()
    }

    var isSwitchingConversationObservable: Observable<Bool> {
        isSwitchingConversationRelay.asObservable()
    }

    var errorMessageObservable: Observable<String?> {
        errorMessageRelay.asObservable()
    }

    var isLoadingObservable: Observable<Bool> {
        isLoadingRelay.asObservable()
    }
    
    // MARK: - Models
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
    
    
    // MARK: - Init
    convenience init() {
        self.init(
            chatService: OpenRouterChatService.shared,
            modelRepository: ModelRepository.shared,
            conversationRepository: ConversationRepository.shared,
            messageRepository: MessageRepository.shared
        )
    }

    init(chatService: ChatServiceProtocol,
         modelRepository: ModelRepositoryProtocol,
         conversationRepository: ConversationRepository,
         messageRepository: MessageRepository) {
        self.chatService = chatService
        self.contextBuilder = ChatContextBuilder()
        self.turnRunner = ChatTurnRunner(chatService: chatService)
        self.persistence = ChatMessagePersistence(
            conversationRepository: conversationRepository,
            messageRepository: messageRepository
        )
        let conversationCoordinator = ConversationCoordinator(
            conversationRepository: conversationRepository,
            messageRepository: messageRepository
        )
        self.conversationUseCase = ConversationListUseCase(coordinator: conversationCoordinator)
        self.sessionCoordinator = ChatSessionCoordinator()
        self.modelSelection = ModelSelectionCoordinator(modelRepository: modelRepository)
        self.turnIdFactory = ChatTurnIdFactory()
        self.logger = ChatLogger(isphaseEnabled: { AppConfig.enablephaseLogs })
        self.sendMessageUseCase = ChatSendMessageUseCase(
            modelSelection: self.modelSelection,
            turnRunner: self.turnRunner,
            turnIdFactory: self.turnIdFactory,
            logger: self.logger
        )
        bootstrapConversation()
    }

    func transform(_ input: Input) -> Output {
        inputDisposeBag = DisposeBag()
        input.actions
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] action in
                self?.handle(action)
            })
            .disposed(by: inputDisposeBag)

        return Output(
            listSnapshot: listSnapshotRelay.asObservable(),
            conversations: conversationsRelay.asObservable(),
            modelListState: modelListStateRelay.asObservable(),
            isSwitchingConversation: isSwitchingConversationRelay.asObservable(),
            errorMessage: errorMessageRelay.asObservable(),
            events: eventRelay.asObservable()
        )
    }

    func dispatch(_ action: Action) {
        if Thread.isMainThread {
            handle(action)
        } else {
            Task { @MainActor in
                handle(action)
            }
        }
    }

    @MainActor
    private func handle(_ action: Action) {
        switch action {
        case .loadModels(let forceRefresh):
            Task { await loadModels(forceRefresh: forceRefresh) }
        case .loadConversations:
            loadConversations()
        case .startNewConversation:
            startNewConversation()
        case .selectConversation(let id):
            Task { await selectConversationAfterLoaded(id: id) }
        case .renameConversation(let id, let title):
            renameConversation(id: id, title: title)
        case .setPinned(let id, let isPinned):
            setPinned(id: id, isPinned: isPinned)
        case .deleteConversation(let id):
            deleteConversation(id: id)
        case .deleteMessage(let id):
            deleteMessage(id: id)
        case .sendMessage(let payload):
            startSendMessage(
                payload.content,
                imageData: payload.imageData,
                imageMimeType: payload.imageMimeType,
                mediaContents: payload.mediaContents
            )
        case .stopGenerating:
            stopGenerating()
        case .clearMessages:
            clearMessages()
        }
    }

    @MainActor
    func emitEvent(_ event: Event) {
        eventRelay.accept(event)
    }
    
    // MARK: - Conversations
    func loadConversations() {
        scheduleLoadConversations(debounceMs: 0)
    }
    
    func startNewConversation() {
        cancelActiveGenerationForContextChange()
        clearStopNotices()
        applySessionSnapshot(sessionCoordinator.startNewConversation())
    }

    /// 用于“会话列表点击后，等数据加载完再切换”的体验：不会短暂展示上一会话内容。
    func selectConversationAfterLoaded(id: String) async {
        let requestId = UUID()
        await MainActor.run {
            cancelActiveGenerationForContextChange()
            clearStopNotices()
            latestSelectionRequestId = requestId
            isSwitchingConversation = true
        }

        do {
            let loadedMessages = try await fetchMessagesInBackground(conversationId: id)
            await MainActor.run {
                guard latestSelectionRequestId == requestId else { return }
                applySessionSnapshot(
                    sessionCoordinator.selectConversation(
                        conversationId: id,
                        loadedMessages: loadedMessages
                    )
                )
                isSwitchingConversation = false
                latestSelectionRequestId = nil
            }
        } catch {
            RuntimeTools.AppDiagnostics.warn("ChatViewModel", "Failed to load conversation: \(error)")
            await MainActor.run {
                guard latestSelectionRequestId == requestId else { return }
                isSwitchingConversation = false
                latestSelectionRequestId = nil
            }
        }
    }

    private func fetchMessagesInBackground(conversationId: String) async throws -> [Message] {
        try await conversationUseCase.fetchMessagesInBackground(conversationId: conversationId)
    }

    private func runInBackground<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await RuntimeTools.AsyncExecutor.run(work)
    }
    
    func renameConversation(id: String, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await runInBackground {
                    try self.conversationUseCase.renameConversation(id: id, title: trimmed)
                }
                await MainActor.run {
                    self.conversations = self.conversationUseCase.applyRename(
                        id: id,
                        title: trimmed,
                        conversations: self.conversations
                    )
                }
            } catch {
                RuntimeTools.AppDiagnostics.warn("ChatViewModel", "Failed to rename conversation: \(error)")
            }
        }
    }
    
    func setPinned(id: String, isPinned: Bool) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await runInBackground {
                    try self.conversationUseCase.setPinned(id: id, isPinned: isPinned)
                }
                await MainActor.run {
                    self.conversations = self.conversationUseCase.applyPinned(
                        id: id,
                        isPinned: isPinned,
                        conversations: self.conversations
                    )
                }
            } catch {
                RuntimeTools.AppDiagnostics.warn("ChatViewModel", "Failed to update pin: \(error)")
            }
        }
    }
    
    func deleteConversation(id: String) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await runInBackground {
                    try self.conversationUseCase.deleteConversation(id: id)
                }
                await MainActor.run {
                    self.conversations = self.conversationUseCase.removeConversation(
                        id: id,
                        conversations: self.conversations
                    )
                    if self.currentConversationId == id {
                        self.cancelActiveGenerationForContextChange()
                        self.applySessionSnapshot(self.sessionCoordinator.clearMessages())
                    }
                }
            } catch {
                RuntimeTools.AppDiagnostics.warn("ChatViewModel", "Failed to delete conversation: \(error)")
            }
        }
    }

    // MARK: - Messages
    func deleteMessage(id: UUID) {
        messages.removeAll { $0.id == id }
        if stopNotices.contains(where: { $0.messageId == id }) {
            stopNotices.removeAll { $0.messageId == id }
            emitSnapshot()
        }
        Task {
            do {
                try await runInBackground {
                    try self.conversationUseCase.deleteMessage(id: id.uuidString)
                }
            } catch {
                RuntimeTools.AppDiagnostics.warn("ChatViewModel", "Failed to delete message: \(error)")
            }
        }
    }

    @MainActor
    func canStartSendMessage(content: String, mediaContents: [MediaContent]) -> Bool {
        if isResettingPersistence {
            errorMessage = "正在清空数据，请稍后重试。"
            return false
        }

        let apiKey = AppConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !AppConfig.useMockData, apiKey.isEmpty {
            errorMessage = "请先在设置中填写 OpenRouter API Key"
            emitEvent(.switchToSettings)
            return false
        }

        let previewUserMessage = Message(
            content: content,
            role: .user,
            mediaContents: mediaContents
        )
        let validation = modelSelection.validateSelection(
            selectedModel: selectedModel,
            userMessage: previewUserMessage
        )
        switch validation {
        case .ready:
            return true
        case .error(let message, _):
            errorMessage = message
            return false
        }
    }
    
    /// UI 入口：开始发送
    @MainActor
    func startSendMessage(_ content: String, imageData: Data? = nil, imageMimeType: String? = nil, mediaContents: [MediaContent] = []) {
        activeSendTask?.cancel()
        activeSendTaskToken = nil

        let taskToken = UUID()
        activeSendTaskToken = taskToken

        let task = Task { [weak self] in
            guard let self else { return }
            await self.sendMessage(content, imageData: imageData, imageMimeType: imageMimeType, mediaContents: mediaContents)
            await MainActor.run {
                guard self.activeSendTaskToken == taskToken else { return }
                self.activeSendTask = nil
                self.activeSendTaskToken = nil
            }
        }
        activeSendTask = task
    }

    @MainActor
    private func cancelActiveGenerationForContextChange() {
        activeSendTask?.cancel()
        activeSendTask = nil
        activeSendTaskToken = nil
        sendMessageUseCase.cancelActive()
        latestSelectionRequestId = nil
        if isSwitchingConversation {
            isSwitchingConversation = false
        }
        if isLoading {
            isLoading = false
        }
        currentTurnId = nil
    }

    /// UI 入口：停止当前生成
    @MainActor
    func stopGenerating() {
        activeSendTask?.cancel()
        activeSendTask = nil
        activeSendTaskToken = nil
        sendMessageUseCase.cancelActive()

        guard isLoading else { return }
        var updatedMessage: Message?
        var noticeMessageId: UUID?
        batchSnapshotUpdate {
            isLoading = false
            if let index = messages.lastIndex(where: { $0.isStreaming }) {
                messages[index].isStreaming = false
                messages[index].wasStreamed = true
                updatedMessage = messages[index]
                noticeMessageId = messages[index].id
            }
            currentTurnId = nil
        }

        let notice = ChatStopNotice(messageId: noticeMessageId, text: "已停止", timestamp: Date())
        appendStopNotice(notice)

        if let updatedMessage {
            let persistedConversationId = currentConversationId
            Task {
                await updatePersistedMessage(updatedMessage, conversationId: persistedConversationId)
            }
        }
    }

    /// 发送入口（实际执行在 UseCase 内部）
    @MainActor
    func sendMessage(_ content: String, imageData: Data? = nil, imageMimeType: String? = nil, mediaContents: [MediaContent] = []) async {
        let env = ChatSendMessageEnvironment(
            ensureConversation: { self.ensureConversation() },
            setCurrentTurnId: { self.currentTurnId = $0 },
            clearCurrentTurnIdIfMatches: { turnId in
                if self.currentTurnId == turnId {
                    self.currentTurnId = nil
                }
            },
            getCurrentConversationId: { self.currentConversationId },
            getSelectedModel: { self.selectedModel },
            getAvailableModels: { self.availableModels },
            setSelectedModel: { self.selectedModel = $0 },
            buildMessagesForRequest: { self.buildMessagesForRequest(currentUserMessage: $0) },
            appendMessage: { self.appendMessage($0) },
            updateMessageContent: { messageId, content in self.updateMessageContent(messageId: messageId, content: content) },
            finalizeStreamingMessage: { messageId, metrics, runtimeStatusText, routingMetadata in
                self.finalizeStreamingMessage(
                    messageId: messageId,
                    metrics: metrics,
                    runtimeStatusText: runtimeStatusText,
                    routingMetadata: routingMetadata
                )
            },
            updatePersistedMessage: { message, conversationId in
                await self.updatePersistedMessage(message, conversationId: conversationId)
            },
            batchUpdate: { updates in
                self.batchSnapshotUpdate(updates)
            },
            setIsLoading: { self.isLoading = $0 },
            setErrorMessage: { self.errorMessage = $0 },
            emitEvent: { event in
                self.emitEvent(event)
            }
        )

        await sendMessageUseCase.execute(
            content: content,
            imageData: imageData,
            imageMimeType: imageMimeType,
            mediaContents: mediaContents,
            env: env
        )
    }
    
    // MARK: - Snapshot
    @MainActor
    func clearMessages() {
        guard !isResettingPersistence else { return }

        cancelActiveGenerationForContextChange()
        clearStopNotices()
        applySessionSnapshot(sessionCoordinator.clearMessages())
        conversations = []
        logger.phase("conversation reset | conversationId=\(conversationId.uuidString)")

        isResettingPersistence = true
        Task {
            await resetPersistence()
        }
    }
    
    /// 统一追加消息并做数量裁剪，避免内存无限增长
    private func appendMessage(_ message: Message) {
        messages.append(message)

        let persistedConversationId = currentConversationId
        Task {
            await persistMessage(message, conversationId: persistedConversationId)
        }
        
        if messages.count > maxStoredMessages {
            let overflow = messages.count - maxStoredMessages
            messages.removeFirst(overflow)
        }
    }

    @MainActor
    private func updateMessageContent(messageId: UUID, content: String) {
        pendingMessageContentUpdates[messageId] = content
        scheduleMessageContentFlushIfNeeded()
    }

    @MainActor
    private func finalizeStreamingMessage(
        messageId: UUID,
        metrics: MessageMetrics?,
        runtimeStatusText: String?,
        routingMetadata: MessageRoutingMetadata?
    ) -> Message? {
        flushPendingMessageContentUpdates()
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return nil }

        var nextMessages = messages
        nextMessages[index].isStreaming = false
        nextMessages[index].wasStreamed = true
        nextMessages[index].metrics = metrics
        nextMessages[index].runtimeStatusText = runtimeStatusText
        nextMessages[index].routingMetadata = routingMetadata
        let updated = nextMessages[index]
        messages = nextMessages
        return updated
    }

    private func scheduleMessageContentFlushIfNeeded() {
        guard !isMessageContentFlushScheduled else { return }
        isMessageContentFlushScheduled = true
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.flushPendingMessageContentUpdates()
        }
    }

    private func flushPendingMessageContentUpdates() {
        guard !pendingMessageContentUpdates.isEmpty else {
            isMessageContentFlushScheduled = false
            return
        }

        let updates = pendingMessageContentUpdates
        pendingMessageContentUpdates.removeAll(keepingCapacity: true)
        isMessageContentFlushScheduled = false

        var nextMessages = messages
        var didChange = false
        for (messageId, content) in updates {
            guard let index = nextMessages.firstIndex(where: { $0.id == messageId }) else { continue }
            if nextMessages[index].content != content {
                nextMessages[index].content = content
                didChange = true
            }
        }

        if didChange {
            messages = nextMessages
        }

        if !pendingMessageContentUpdates.isEmpty {
            scheduleMessageContentFlushIfNeeded()
        }
    }

    private func clearPendingMessageContentUpdates() {
        pendingMessageContentUpdates.removeAll(keepingCapacity: false)
        isMessageContentFlushScheduled = false
    }
    
    private func bootstrapConversation() {
        Task {
            await MainActor.run {
                self.applySessionSnapshot(self.sessionCoordinator.bootstrap())
            }
            scheduleLoadConversations(debounceMs: 0)
        }
    }
    
    // MARK: - Persistence
    private func persistMessage(_ message: Message, conversationId: String?) async {
        guard let conversationId else { return }
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
            RuntimeTools.AppDiagnostics.warn("ChatViewModel", "Failed to persist message: \(error)")
        }
    }
    
    private func updatePersistedMessage(_ message: Message, conversationId: String?) async {
        guard let conversationId else { return }
        do {
            let now = Date()
            try await persistence.updateMessage(message, conversationId: conversationId)
            await MainActor.run {
                applyConversationTouch(conversationId: conversationId, touchedAt: now)
            }
        } catch {
            RuntimeTools.AppDiagnostics.warn("ChatViewModel", "Failed to update message: \(error)")
        }
    }
    
    // MARK: - Context
    private func buildMessagesForRequest(currentUserMessage: Message) -> [Message] {
        contextBuilder.buildMessagesForRequest(
            allMessages: messages,
            currentUserMessage: currentUserMessage,
            strategy: AppConfig.contextStrategy,
            maxContextMessages: maxContextMessages
        )
    }
    
    private func resetPersistence() async {
        var resetError: Error?
        do {
            try await persistence.resetAll()
        } catch {
            resetError = error
            RuntimeTools.AppDiagnostics.warn("ChatViewModel", "Failed to reset persistence: \(error)")
        }

        await MainActor.run {
            self.isResettingPersistence = false
            if resetError != nil {
                self.errorMessage = "清空数据失败，请稍后重试。"
            }
            self.scheduleLoadConversations(debounceMs: 0)
        }
    }
    
    // MARK: - Conversation Creation
    @MainActor
    private func ensureConversation() -> Bool {
        if isResettingPersistence {
            errorMessage = "正在清空数据，请稍后重试。"
            return false
        }

        if currentConversationId != nil {
            return true
        }
        do {
            let conversation = try conversationUseCase.createConversation()
            clearPendingMessageContentUpdates()
            currentConversationId = conversation.id
            conversationId = UUID()
            turnIdFactory.conversationId = conversationId
            currentTurnId = nil
            messages = []
            stopNotices.removeAll()
            conversations.insert(conversation, at: 0)
            return true
        } catch {
            RuntimeTools.AppDiagnostics.warn("ChatViewModel", "Failed to create conversation: \(error)")
            errorMessage = "无法创建会话，请稍后重试。"
            return false
        }
    }

    /// 应用会话快照到 UI 状态
    private func applySessionSnapshot(_ snapshot: ChatSessionSnapshot) {
        batchSnapshotUpdate {
            clearPendingMessageContentUpdates()
            currentConversationId = snapshot.currentConversationId
            messages = snapshot.messages
            conversationId = snapshot.conversationId
            turnIdFactory.conversationId = snapshot.conversationId
            currentTurnId = snapshot.currentTurnId
            stopNotices.removeAll()
        }
    }

    /// 批量更新：避免 snapshot 重算
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
            conversationId: currentConversationId,
            stopNotices: stopNotices
        )
    }

    /// “停止生成”的 UI 提示（不写入 DB）
    private func appendStopNotice(_ notice: ChatStopNotice) {
        if let messageId = notice.messageId,
           let index = stopNotices.firstIndex(where: { $0.messageId == messageId }) {
            stopNotices[index] = notice
        } else {
            stopNotices.append(notice)
        }
        emitSnapshot()
    }

    private func clearStopNotices() {
        guard !stopNotices.isEmpty else { return }
        stopNotices.removeAll()
        emitSnapshot()
    }

    private func scheduleLoadConversations(debounceMs: Int = 150) {
        conversationUseCase.loadConversations(
            debounceMs: debounceMs,
            onLoaded: { [weak self] records in
                guard let self else { return }
                guard !self.isResettingPersistence else { return }
                self.conversations = records
            },
            onError: { error in
                RuntimeTools.AppDiagnostics.warn("ChatViewModel", "Failed to load conversations: \(error)")
            }
        )
    }

    @MainActor
    private func applyConversationTouch(conversationId: String, touchedAt: Date) {
        switch conversationUseCase.applyConversationTouch(
            conversationId: conversationId,
            touchedAt: touchedAt,
            conversations: conversations
        ) {
        case .updated(let updated):
            conversations = updated
        case .needsReload:
            // 极少数情况下（内存列表未同步），fallback 一次全量刷新。
            scheduleLoadConversations(debounceMs: 150)
        }
    }
    
}
