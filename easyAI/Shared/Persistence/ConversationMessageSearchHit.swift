//
//  ConversationMessageSearchHit.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 会话消息搜索命中结果
//

import Foundation

nonisolated struct ConversationMessageSearchHit: Equatable, Sendable {
    let conversationId: String
    let messageId: String
    let content: String
    let timestamp: Date
}
