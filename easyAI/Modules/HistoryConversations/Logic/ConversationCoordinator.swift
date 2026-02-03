//
//  ConversationCoordinator.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 会话与消息的组合操作协调
//
//

import Foundation

final class ConversationCoordinator {
    private let conversationRepository: ConversationRepository
    private let messageRepository: MessageRepository

    init(
        conversationRepository: ConversationRepository,
        messageRepository: MessageRepository
    ) {
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
    }

    func fetchAllConversations() throws -> [ConversationRecord] {
        try conversationRepository.fetchAll()
    }

    func createConversation(title: String = "新对话") throws -> ConversationRecord {
        try conversationRepository.createConversation(title: title)
    }

    func fetchMessages(conversationId: String) throws -> [Message] {
        try messageRepository.fetchMessages(conversationId: conversationId)
    }

    func renameConversation(id: String, title: String) throws {
        try conversationRepository.renameConversation(id: id, title: title)
    }

    func setPinned(id: String, isPinned: Bool) throws {
        try conversationRepository.setPinned(id: id, isPinned: isPinned)
    }

    func deleteConversationAndMessages(id: String) throws {
        try messageRepository.deleteMessages(conversationId: id)
        try conversationRepository.deleteConversation(id: id)
    }
}

