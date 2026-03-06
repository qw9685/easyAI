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
        try upsertMessageSearchIndex(record)
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
        try upsertMessageSearchIndex(record)
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

        var hitsByConversation: [String: ConversationMessageSearchHit] = [:]

        do {
            try appendIndexedHits(
                to: &hitsByConversation,
                query: trimmedQuery,
                conversationIds: conversationIds
            )
        } catch {
            RuntimeTools.AppDiagnostics.warn(
                "MessageRepository",
                "FTS search failed, fallback to LIKE: \(error)"
            )
        }

        let remainingConversationIds = conversationIds.filter { hitsByConversation[$0] == nil }
        if !remainingConversationIds.isEmpty {
            try appendFallbackHits(
                to: &hitsByConversation,
                query: trimmedQuery,
                conversationIds: remainingConversationIds,
                expectedConversationCount: conversationIds.count
            )
        }

        return conversationIds.compactMap { hitsByConversation[$0] }
    }

    func deleteMessages(conversationId: String) throws {
        try database.delete(
            fromTable: WCDBTables.messageSearchIndex,
            where: MessageSearchIndexRecord.Properties.conversationId == conversationId
        )
        try database.delete(
            fromTable: WCDBTables.message,
            where: MessageRecord.Properties.conversationId == conversationId
        )
    }

    func deleteMessage(id: String) throws {
        try deleteMessageSearchIndex(messageId: id)
        try database.delete(
            fromTable: WCDBTables.message,
            where: MessageRecord.Properties.id == id
        )
    }

    func deleteAll() throws {
        try database.delete(fromTable: WCDBTables.messageSearchIndex)
        try database.delete(fromTable: WCDBTables.message)
    }

    private func appendIndexedHits(
        to hitsByConversation: inout [String: ConversationMessageSearchHit],
        query: String,
        conversationIds: [String]
    ) throws {
        guard let ftsQuery = Self.makeFTSMatchQuery(query) else {
            return
        }

        let records: [MessageSearchIndexRecord] = try database.getObjects(
            fromTable: WCDBTables.messageSearchIndex,
            where: MessageSearchIndexRecord.Properties.conversationId.in(conversationIds)
                && MessageSearchIndexRecord.Properties.content.match(ftsQuery),
            orderBy: [
                MessageSearchIndexRecord.Properties.sortTimestamp.order(.descending),
                MessageSearchIndexRecord.Properties.messageId.order(.descending)
            ]
        )

        appendIndexedRecords(records, to: &hitsByConversation, expectedConversationCount: conversationIds.count)
    }

    private func appendFallbackHits(
        to hitsByConversation: inout [String: ConversationMessageSearchHit],
        query: String,
        conversationIds: [String],
        expectedConversationCount: Int
    ) throws {
        let escapedQuery = Self.escapeLikePattern(query.lowercased())
        let records: [MessageRecord] = try database.getObjects(
            fromTable: WCDBTables.message,
            where: MessageRecord.Properties.conversationId.in(conversationIds)
                && MessageRecord.Properties.content.lower().like("%\(escapedQuery)%").escape("\\"),
            orderBy: [
                MessageRecord.Properties.timestamp.order(.descending),
                MessageRecord.Properties.id.order(.descending)
            ]
        )

        for record in records {
            guard hitsByConversation[record.conversationId] == nil else { continue }
            hitsByConversation[record.conversationId] = ConversationMessageSearchHit(
                conversationId: record.conversationId,
                messageId: record.id,
                content: record.content,
                timestamp: record.timestamp
            )
            if hitsByConversation.count == expectedConversationCount {
                break
            }
        }
    }

    private func appendIndexedRecords(
        _ records: [MessageSearchIndexRecord],
        to hitsByConversation: inout [String: ConversationMessageSearchHit],
        expectedConversationCount: Int
    ) {
        for record in records {
            guard hitsByConversation[record.conversationId] == nil else { continue }
            hitsByConversation[record.conversationId] = record.toSearchHit()
            if hitsByConversation.count == expectedConversationCount {
                break
            }
        }
    }

    private func upsertMessageSearchIndex(_ record: MessageRecord) throws {
        try deleteMessageSearchIndex(messageId: record.id)

        let searchIndexRecord = MessageSearchIndexRecord.fromMessageRecord(record)
        guard searchIndexRecord.isSearchable else { return }
        try database.insert(searchIndexRecord, intoTable: WCDBTables.messageSearchIndex)
    }

    private func deleteMessageSearchIndex(messageId: String) throws {
        try database.delete(
            fromTable: WCDBTables.messageSearchIndex,
            where: MessageSearchIndexRecord.Properties.messageId == messageId
        )
    }

    private static func makeFTSMatchQuery(_ value: String) -> String? {
        let tokens = tokenizeFTSQuery(value)
        guard tokens.count == 1, let token = tokens.first else {
            return nil
        }
        return "\(token)*"
    }

    private static func tokenizeFTSQuery(_ value: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for scalar in value.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                tokens.append(current)
                current.removeAll(keepingCapacity: true)
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
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
