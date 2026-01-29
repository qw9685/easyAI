//
//  ChatListDiffModels.swift
//  EasyAI
//
//  创建于 2026
//

import Foundation
import RxDataSources

struct ChatListState {
    let messages: [Message]
    let isLoading: Bool
    let conversationId: String?
    let sections: [ChatSection]
}

enum ChatRow: IdentifiableType, Equatable {
    case messageMarkdown(Message)
    case messageSend(messageId: UUID, text: String, timestamp: Date)
    case messageMedia(messageId: UUID, role: MessageRole, mediaContents: [MediaContent])
    case loading
    
    var identity: String {
        switch self {
        case .messageMarkdown(let message):
            return "\(message.id.uuidString)|markdown"
        case .messageSend(let messageId, _, _):
            return "\(messageId.uuidString)|send"
        case .messageMedia(let messageId, _, _):
            return "\(messageId.uuidString)|media"
        case .loading:
            return "loading"
        }
    }
    
    static func == (lhs: ChatRow, rhs: ChatRow) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.messageMarkdown(let left), .messageMarkdown(let right)):
            return left.id == right.id
                && left.content == right.content
                && left.isStreaming == right.isStreaming
                && left.wasStreamed == right.wasStreamed
                && left.role == right.role
        case (.messageSend(let leftId, let leftText, let leftTime),
              .messageSend(let rightId, let rightText, let rightTime)):
            return leftId == rightId && leftText == rightText && leftTime == rightTime
        case (.messageMedia(let leftId, let leftRole, let leftMedia),
              .messageMedia(let rightId, let rightRole, let rightMedia)):
            return leftId == rightId
                && leftRole == rightRole
                && mediaSignature(leftMedia) == mediaSignature(rightMedia)
        default:
            return false
        }
    }

    private static func mediaSignature(_ media: [MediaContent]) -> [String] {
        media.map { item in
            "\(item.id.uuidString)|\(item.type.rawValue)|\(item.mimeType)|\(item.fileName ?? "")|\(item.fileSize)"
        }
    }
}

struct ChatSection: AnimatableSectionModelType {
    var identity: String = "main"
    var items: [ChatRow]
    
    init(items: [ChatRow]) {
        self.items = items
    }
    
    init(original: ChatSection, items: [ChatRow]) {
        self = original
        self.items = items
    }
}
