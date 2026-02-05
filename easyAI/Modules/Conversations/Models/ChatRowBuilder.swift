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
        isLoading: Bool,
        stopNotices: [ChatStopNotice]
    ) -> [ChatRow] {
        var items: [ChatRow] = []
        items.reserveCapacity(messages.count * 2)

        var noticeAttachedToMessage = Set<UUID>()
        let noticeMap: [UUID: ChatStopNotice] = Dictionary(
            uniqueKeysWithValues: stopNotices.compactMap { notice in
                guard let messageId = notice.messageId else { return nil }
                return (messageId, notice)
            }
        )

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
                // Normal assistant message: render markdown bubble, optionally with a stop status.
                let statusText = noticeMap[message.id]?.text
                items.append(.messageMarkdown(message, statusText: statusText))
                if statusText != nil {
                    noticeAttachedToMessage.insert(message.id)
                }
            } else if let notice = noticeMap[message.id] {
                // Stop happened before any text was produced: render a compact status row instead of a tall empty bubble row.
                items.append(.stopNotice(notice))
                noticeAttachedToMessage.insert(message.id)
            }
        }

        for notice in stopNotices where notice.messageId == nil {
            items.append(.stopNotice(notice))
        }

        for notice in stopNotices where notice.messageId != nil {
            guard let messageId = notice.messageId else { continue }
            if !noticeAttachedToMessage.contains(messageId) {
                items.append(.stopNotice(notice))
            }
        }

        if isLoading {
            items.append(.loading)
        }

        return items
    }
}
