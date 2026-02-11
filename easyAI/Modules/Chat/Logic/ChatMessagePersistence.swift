//
//  ChatMessagePersistence.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 消息/会话持久化与标题生成
//
//

import Foundation

final class ChatMessagePersistence {
    private let conversationRepository: ConversationRepository
    private let messageRepository: MessageRepository
    private let persistenceQueue = DispatchQueue(label: "easyai.chat.persistence", qos: .userInitiated)

    init(
        conversationRepository: ConversationRepository,
        messageRepository: MessageRepository
    ) {
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
    }

    func persistNewMessage(_ message: Message, conversationId: String) async throws -> String? {
        try await runDatabaseTask {
            try self.messageRepository.insertMessage(message, conversationId: conversationId)

            if message.role == .user,
               let newTitle = try? self.makeTitleIfNeeded(conversationId: conversationId, content: message.content) {
                do {
                    try self.conversationRepository.renameConversation(id: conversationId, title: newTitle)
                    return newTitle
                } catch {
                    print("[ChatMessagePersistence] ⚠️ Failed to rename conversation title: \(error)")
                }
            }

            try self.conversationRepository.touch(id: conversationId)
            return nil
        }
    }

    func updateMessage(_ message: Message, conversationId: String) async throws {
        try await runDatabaseTask {
            try self.messageRepository.updateMessage(message, conversationId: conversationId)
            try self.conversationRepository.touch(id: conversationId)
        }
    }

    func resetAll() async throws {
        try await runDatabaseTask {
            try self.messageRepository.deleteAll()
            try self.conversationRepository.deleteAll()
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

    private func runDatabaseTask<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            persistenceQueue.async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
