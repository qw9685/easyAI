//
//  ChatContextBuilder.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 按策略构建请求上下文
//
//

import Foundation

protocol ChatContextBuilding {
    func buildMessagesForRequest(
        allMessages: [Message],
        currentUserMessage: Message,
        strategy: MessageContextStrategy,
        maxContextMessages: Int
    ) -> [Message]
}

struct ChatContextBuilder: ChatContextBuilding {
    func buildMessagesForRequest(
        allMessages: [Message],
        currentUserMessage: Message,
        strategy: MessageContextStrategy,
        maxContextMessages: Int
    ) -> [Message] {
        let contextMessages = Array(allMessages.suffix(maxContextMessages))

        switch strategy {
        case .fullContext:
            return sanitizeMessages(
                contextMessages,
                currentUserMessageId: currentUserMessage.id,
                allowCurrentImage: true
            )
        case .textOnly:
            return sanitizeMessages(
                contextMessages,
                currentUserMessageId: currentUserMessage.id,
                allowCurrentImage: false
            )
        case .currentOnly:
            return sanitizeMessages(
                [currentUserMessage],
                currentUserMessageId: currentUserMessage.id,
                allowCurrentImage: true
            )
        }
    }

    private func sanitizeMessages(
        _ source: [Message],
        currentUserMessageId: UUID?,
        allowCurrentImage: Bool
    ) -> [Message] {
        source.map { message in
            let isCurrent = message.id == currentUserMessageId
            let shouldKeepMedia = isCurrent && allowCurrentImage
            var sanitized = message
            if !shouldKeepMedia {
                if sanitized.hasMedia && sanitized.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    sanitized.content = "（图片）"
                }
                sanitized.mediaContents = []
            }
            return sanitized
        }
    }
}

