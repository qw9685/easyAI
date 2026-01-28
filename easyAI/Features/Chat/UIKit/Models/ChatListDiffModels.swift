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
    case message(Message)
    case loading
    
    var identity: String {
        switch self {
        case .message(let message):
            return message.id.uuidString
        case .loading:
            return "loading"
        }
    }
    
    static func == (lhs: ChatRow, rhs: ChatRow) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.message(let left), .message(let right)):
            return left.id == right.id
                && left.content == right.content
                && left.isStreaming == right.isStreaming
                && left.wasStreamed == right.wasStreamed
        default:
            return false
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
