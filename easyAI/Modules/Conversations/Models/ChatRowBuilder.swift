//
//  ChatRowBuilder.swift
//  EasyAI
//
//  创建于 2026
//

import Foundation

enum ChatRowBuilder {
    static func build(
        messages: [Message],
        isLoading: Bool
    ) -> [ChatRow] {
        var items: [ChatRow] = []
        items.reserveCapacity(messages.count * 2)

        for message in messages {
            if !message.mediaContents.isEmpty {
                items.append(.messageMedia(messageId: message.id, role: message.role, mediaContents: message.mediaContents))
            }

            if message.role == .user {
                items.append(.messageSend(messageId: message.id, text: message.content, timestamp: message.timestamp))
            } else if !message.content.isEmpty || message.isStreaming {
                items.append(.messageMarkdown(message))
            }
        }

        if isLoading {
            items.append(.loading)
        }

        return items
    }
}

