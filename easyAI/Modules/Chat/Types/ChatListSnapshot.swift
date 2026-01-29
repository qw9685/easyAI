//
//  ChatListSnapshot.swift
//  EasyAI
//
//  创建于 2026
//

import Foundation

struct ChatListSnapshot {
    var messages: [Message]
    var isLoading: Bool
    var conversationId: String?

    static let empty = ChatListSnapshot(messages: [], isLoading: false, conversationId: nil)
}

