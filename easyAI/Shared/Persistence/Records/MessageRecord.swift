//
//  MessageRecord.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 消息表记录模型与编解码
//
//


import Foundation
import WCDBSwift

struct MessageRecord: TableCodable {
    var id: String
    var conversationId: String
    var role: String
    var content: String
    var timestamp: Date
    var isStreaming: Bool
    var wasStreamed: Bool
    var mediaPayload: Data?
    var turnId: String?
    var baseId: String?
    var itemId: String?

    enum CodingKeys: String, CodingTableKey {
        typealias Root = MessageRecord
        case id
        case conversationId = "conversation_id"
        case role
        case content
        case timestamp
        case isStreaming = "is_streaming"
        case wasStreamed = "was_streamed"
        case mediaPayload = "media_payload"
        case turnId = "turn_id"
        case baseId = "base_id"
        case itemId = "item_id"
        nonisolated(unsafe) static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true)
        }
    }

    static func fromMessage(_ message: Message, conversationId: String) -> MessageRecord {
        return MessageRecord(
            id: message.id.uuidString,
            conversationId: conversationId,
            role: message.role.rawValue,
            content: message.content,
            timestamp: message.timestamp,
            isStreaming: message.isStreaming,
            wasStreamed: message.wasStreamed,
            mediaPayload: encodeMedia(message.mediaContents),
            turnId: message.turnId?.uuidString,
            baseId: message.baseId,
            itemId: message.itemId
        )
    }

    func toMessage() -> Message {
        return Message(
            id: UUID(uuidString: id) ?? UUID(),
            content: content,
            role: MessageRole(rawValue: role) ?? .assistant,
            timestamp: timestamp,
            isStreaming: isStreaming,
            wasStreamed: wasStreamed,
            mediaContents: decodeMedia(mediaPayload),
            turnId: turnId.flatMap { UUID(uuidString: $0) },
            baseId: baseId,
            itemId: itemId
        )
    }

    private static func encodeMedia(_ media: [MediaContent]) -> Data? {
        guard !media.isEmpty else { return nil }
        return try? JSONEncoder().encode(media)
    }

    private func decodeMedia(_ data: Data?) -> [MediaContent] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([MediaContent].self, from: data)) ?? []
    }
}
