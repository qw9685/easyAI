//
//  ChatSessionCoordinator.swift
//  EasyAI
//
//  创建于 2026
//

import Foundation

struct ChatSessionSnapshot {
    let currentConversationId: String?
    let messages: [Message]
    let conversationId: UUID
    let currentTurnId: UUID?
}

protocol ChatSessionCoordinating {
    func bootstrap() -> ChatSessionSnapshot
    func startNewConversation() -> ChatSessionSnapshot
    func selectConversation(conversationId: String, loadedMessages: [Message]) -> ChatSessionSnapshot
    func clearMessages() -> ChatSessionSnapshot
}

struct ChatSessionCoordinator: ChatSessionCoordinating {
    func bootstrap() -> ChatSessionSnapshot {
        ChatSessionSnapshot(
            currentConversationId: nil,
            messages: [],
            conversationId: UUID(),
            currentTurnId: nil
        )
    }

    func startNewConversation() -> ChatSessionSnapshot {
        ChatSessionSnapshot(
            currentConversationId: nil,
            messages: [],
            conversationId: UUID(),
            currentTurnId: nil
        )
    }

    func selectConversation(conversationId: String, loadedMessages: [Message]) -> ChatSessionSnapshot {
        ChatSessionSnapshot(
            currentConversationId: conversationId,
            messages: loadedMessages,
            conversationId: UUID(),
            currentTurnId: nil
        )
    }

    func clearMessages() -> ChatSessionSnapshot {
        ChatSessionSnapshot(
            currentConversationId: nil,
            messages: [],
            conversationId: UUID(),
            currentTurnId: nil
        )
    }
}
