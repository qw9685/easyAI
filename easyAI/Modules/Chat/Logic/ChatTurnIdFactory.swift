//
//  ChatTurnIdFactory.swift
//  EasyAI
//
//  创建于 2026
//

import Foundation

final class ChatTurnIdFactory {
    var conversationId: UUID

    init(conversationId: UUID = UUID()) {
        self.conversationId = conversationId
    }

    func makeBaseId(turnId: UUID) -> String {
        "c:\(conversationId.uuidString)|t:\(turnId.uuidString)"
    }

    func makeItemId(baseId: String, kind: String, part: String) -> String {
        "\(baseId)|k:\(kind)|p:\(part)"
    }
}

