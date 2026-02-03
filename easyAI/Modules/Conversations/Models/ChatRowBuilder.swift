//
//  ChatRowBuilder.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 将消息与加载状态构建为行模型
//
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
                items.append(.messageMedia(message))
                continue
            }

            if message.role == .user {
                let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    items.append(.messageSend(message))
                }
            } else if !message.content.isEmpty {
                items.append(.messageMarkdown(message))
            }
        }

        if isLoading {
            items.append(.loading)
        }

        return items
    }
}
