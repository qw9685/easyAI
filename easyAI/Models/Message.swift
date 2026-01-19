//
//  Message.swift
//  EasyAI
//
//  Created on 2024
//

import Foundation
import UIKit

struct Message: Identifiable, Codable {
    let id: UUID
    /// 内容需要在打字机效果中逐步更新，因此使用 `var`
    var content: String
    let role: MessageRole
    let timestamp: Date
    /// 是否为流式消息（stream 模式下，直接显示文本，不使用打字机效果）
    var isStreaming: Bool
    /// 是否曾经是流式消息（用于标记该消息应该始终直接显示，不使用打字机效果）
    var wasStreamed: Bool
    /// 媒体内容列表（图片、视频、音频、PDF等）
    var mediaContents: [MediaContent]
    /// Phase4: 一轮对话的 turnId（用于稳定 identity 与日志关联）
    let turnId: UUID?
    /// Phase4: 稳定的 baseId（推荐：c:<conversationId>|t:<turnId>）
    let baseId: String?
    /// Phase4: 稳定的 itemId（推荐：<baseId>|k:<kind>|p:<part>）
    let itemId: String?

    init(
        id: UUID = UUID(),
        content: String,
        role: MessageRole,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        wasStreamed: Bool = false,
        mediaContents: [MediaContent] = [],
        turnId: UUID? = nil,
        baseId: String? = nil,
        itemId: String? = nil
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.wasStreamed = wasStreamed
        self.mediaContents = mediaContents
        self.turnId = turnId
        self.baseId = baseId
        self.itemId = itemId
    }

    // MARK: - Convenience
    var hasMedia: Bool {
        !mediaContents.isEmpty
    }

    var hasImage: Bool {
        mediaContents.contains(where: { $0.type == .image })
    }

    func getImageDataURL() -> String? {
        mediaContents.first(where: { $0.type == .image })?.getDataURL()
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}
