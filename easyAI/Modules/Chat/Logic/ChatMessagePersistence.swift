//
//  ChatMessagePersistence.swift
//  EasyAI
//
//  创建于 2026
//

import Foundation

final class ChatMessagePersistence {
    private let conversationRepository: ConversationRepository
    private let messageRepository: MessageRepository

    init(
        conversationRepository: ConversationRepository,
        messageRepository: MessageRepository
    ) {
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
    }

    func persistNewMessage(_ message: Message, conversationId: String) async throws -> String? {
        try messageRepository.insertMessage(message, conversationId: conversationId)

        if message.role == .user,
           let newTitle = try? makeTitleIfNeeded(conversationId: conversationId, content: message.content) {
            try conversationRepository.renameConversation(id: conversationId, title: newTitle)
            return newTitle
        }

        try conversationRepository.touch(id: conversationId)
        return nil
    }

    func updateMessage(_ message: Message, conversationId: String) async throws {
        try messageRepository.updateMessage(message, conversationId: conversationId)
        try conversationRepository.touch(id: conversationId)
    }

    func resetAll() async throws {
        try messageRepository.deleteAll()
        try conversationRepository.deleteAll()
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
}

