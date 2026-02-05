//
//  ChatListSnapshot.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 列表快照数据结构
//
//

import Foundation

struct ChatListSnapshot {
    var messages: [Message]
    var isLoading: Bool
    var conversationId: String?
    var stopNotices: [ChatStopNotice]

    static let empty = ChatListSnapshot(messages: [], isLoading: false, conversationId: nil, stopNotices: [])
}

struct ChatStopNotice: Equatable {
    let messageId: UUID?
    let text: String
    let timestamp: Date
}
