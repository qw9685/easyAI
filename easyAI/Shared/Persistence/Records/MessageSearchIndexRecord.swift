//
//  MessageSearchIndexRecord.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 消息全文搜索索引虚表记录
//
//


import Foundation
import WCDBSwift

struct MessageSearchIndexRecord: TableCodable {
    var messageId: String
    var conversationId: String
    var sortTimestamp: Double
    var content: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = MessageSearchIndexRecord
        case messageId = "message_id"
        case conversationId = "conversation_id"
        case sortTimestamp = "sort_timestamp"
        case content
        nonisolated(unsafe) static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(messageId, isNotIndexed: true)
            BindColumnConstraint(conversationId, isNotIndexed: true)
            BindColumnConstraint(sortTimestamp, isNotIndexed: true)
            BindVirtualTable(withModule: .FTS5,
                             and: BuiltinTokenizer.Verbatim,
                             BuiltinTokenizer.Parameter.SkipStemming)
        }
    }

    static func fromMessageRecord(_ record: MessageRecord) -> MessageSearchIndexRecord {
        MessageSearchIndexRecord(
            messageId: record.id,
            conversationId: record.conversationId,
            sortTimestamp: record.timestamp.timeIntervalSince1970,
            content: record.content
        )
    }

    var isSearchable: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func toSearchHit() -> ConversationMessageSearchHit {
        ConversationMessageSearchHit(
            conversationId: conversationId,
            messageId: messageId,
            content: content,
            timestamp: Date(timeIntervalSince1970: sortTimestamp)
        )
    }
}
