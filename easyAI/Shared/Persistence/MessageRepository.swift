//
//  MessageRepository.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 消息表 CRUD
//
//


import Foundation
import WCDBSwift

final class MessageRepository {
    static let shared = MessageRepository()

    private let database: Database

    private init(database: Database = WCDBManager.shared.database) {
        self.database = database
    }

    func insertMessage(_ message: Message, conversationId: String) throws {
        let record = MessageRecord.fromMessage(message, conversationId: conversationId)
        try database.insert(record, intoTable: WCDBTables.message)
    }

    func updateMessage(_ message: Message, conversationId: String) throws {
        let record = MessageRecord.fromMessage(message, conversationId: conversationId)
        try database.update(
            table: WCDBTables.message,
            on: [
                MessageRecord.Properties.content,
                MessageRecord.Properties.isStreaming,
                MessageRecord.Properties.wasStreamed,
                MessageRecord.Properties.promptTokens,
                MessageRecord.Properties.completionTokens,
                MessageRecord.Properties.totalTokens,
                MessageRecord.Properties.latencyMs,
                MessageRecord.Properties.estimatedCostUsd,
                MessageRecord.Properties.metricsEstimated,
                MessageRecord.Properties.routingFromModelId,
                MessageRecord.Properties.routingToModelId,
                MessageRecord.Properties.routingReason,
                MessageRecord.Properties.routingMode,
                MessageRecord.Properties.routingBudgetMode,
                MessageRecord.Properties.routingTimestamp
            ],
            with: [
                record.content,
                record.isStreaming,
                record.wasStreamed,
                record.promptTokens,
                record.completionTokens,
                record.totalTokens,
                record.latencyMs,
                record.estimatedCostUsd,
                record.metricsEstimated,
                record.routingFromModelId,
                record.routingToModelId,
                record.routingReason,
                record.routingMode,
                record.routingBudgetMode,
                record.routingTimestamp
            ],
            where: MessageRecord.Properties.id == record.id
        )
    }

    func fetchMessages(conversationId: String, limit: Int? = nil, offset: Int? = nil) throws -> [Message] {
        let records: [MessageRecord] = try database.getObjects(
            fromTable: WCDBTables.message,
            where: MessageRecord.Properties.conversationId == conversationId,
            orderBy: [
                MessageRecord.Properties.timestamp.order(.ascending),
                MessageRecord.Properties.id.order(.ascending)
            ],
            limit: limit,
            offset: offset
        )
        return records.map { $0.toMessage() }
    }

    func fetchRecentMessages(conversationId: String, limit: Int) throws -> [Message] {
        let records: [MessageRecord] = try database.getObjects(
            fromTable: WCDBTables.message,
            where: MessageRecord.Properties.conversationId == conversationId,
            orderBy: [
                MessageRecord.Properties.timestamp.order(.descending),
                MessageRecord.Properties.id.order(.descending)
            ],
            limit: limit
        )
        return records.reversed().map { $0.toMessage() }
    }

    func searchFirstMatchingMessages(query: String, conversationIds: [String]) throws -> [ConversationMessageSearchHit] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, !conversationIds.isEmpty else {
            return []
        }

        let escapedQuery = Self.escapeLikePattern(trimmedQuery.lowercased())
        let records: [MessageRecord] = try database.getObjects(
            fromTable: WCDBTables.message,
            where: MessageRecord.Properties.conversationId.in(conversationIds)
                && MessageRecord.Properties.content.lower().like("%\(escapedQuery)%").escape("\\"),
            orderBy: [
                MessageRecord.Properties.timestamp.order(.descending),
                MessageRecord.Properties.id.order(.descending)
            ]
        )

        var hitsByConversation: [String: ConversationMessageSearchHit] = [:]
        for record in records {
            guard hitsByConversation[record.conversationId] == nil else { continue }
            hitsByConversation[record.conversationId] = ConversationMessageSearchHit(
                conversationId: record.conversationId,
                messageId: record.id,
                content: record.content,
                timestamp: record.timestamp
            )
            if hitsByConversation.count == conversationIds.count {
                break
            }
        }

        return conversationIds.compactMap { hitsByConversation[$0] }
    }

    func deleteMessages(conversationId: String) throws {
        try database.delete(fromTable: WCDBTables.message,
                            where: MessageRecord.Properties.conversationId == conversationId)
    }

    func deleteMessage(id: String) throws {
        try database.delete(
            fromTable: WCDBTables.message,
            where: MessageRecord.Properties.id == id
        )
    }

    func deleteAll() throws {
        try database.delete(fromTable: WCDBTables.message)
    }

    private static func escapeLikePattern(_ value: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(value.count)

        for character in value {
            switch character {
            case "\\", "%", "_":
                escaped.append("\\")
                escaped.append(character)
            default:
                escaped.append(character)
            }
        }

        return escaped
    }
}
