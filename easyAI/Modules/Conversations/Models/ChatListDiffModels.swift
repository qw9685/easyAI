//
//  ChatListDiffModels.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 列表 diff 使用的行/分区模型
//
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
    case messageSend(Message)
    case messageMedia(Message)
    case loading
    
    var identity: String {
        switch self {
        case .messageMarkdown(let message):
            return "\(message.id.uuidString)|markdown"
        case .messageSend(let message):
            return "\(message.id.uuidString)|send"
        case .messageMedia(let message):
            return "\(message.id.uuidString)|media"
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
        case (.messageSend(let left), .messageSend(let right)):
            return left.id == right.id
                && left.content == right.content
                && left.timestamp == right.timestamp
                && left.role == right.role
        case (.messageMedia(let left), .messageMedia(let right)):
            return left.id == right.id
                && left.role == right.role
                && left.timestamp == right.timestamp
                && left.isStreaming == right.isStreaming
                && mediaSignature(left.mediaContents) == mediaSignature(right.mediaContents)
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
