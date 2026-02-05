//
//  AppContainer.swift
//  easyAI
//
//  依赖容器（集中管理 shared 依赖）
//
//  目标：
//  - 统一创建依赖，减少散落的 `.shared`
//  - 保持现有行为不变（默认仍使用 shared 实现）
//  - 为后续替换/测试提供单点入口
//

import Foundation

final class AppContainer {
    static let shared = AppContainer()

    let chatService: ChatServiceProtocol
    let modelRepository: ModelRepositoryProtocol
    let conversationRepository: ConversationRepository
    let messageRepository: MessageRepository

    init(chatService: ChatServiceProtocol = OpenRouterChatService.shared,
         modelRepository: ModelRepositoryProtocol = ModelRepository.shared,
         conversationRepository: ConversationRepository = ConversationRepository.shared,
         messageRepository: MessageRepository = MessageRepository.shared) {
        self.chatService = chatService
        self.modelRepository = modelRepository
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
    }

    func makeChatViewModel() -> ChatViewModel {
        ChatViewModel(
            chatService: chatService,
            modelRepository: modelRepository,
            conversationRepository: conversationRepository,
            messageRepository: messageRepository
        )
    }
}
