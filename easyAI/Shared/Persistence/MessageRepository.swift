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

    func deleteMessages(conversationId: String) throws {
        try database.delete(fromTable: WCDBTables.message,
                            where: MessageRecord.Properties.conversationId == conversationId)
    }

    func deleteMessage(id: String) throws {
        let existing: MessageRecord? = try database.getObject(
            fromTable: WCDBTables.message,
            where: MessageRecord.Properties.id == id
        )

        if existing != nil {
            try database.delete(
                fromTable: WCDBTables.message,
                where: MessageRecord.Properties.id == id
            )
            return
        }

        try deleteLegacyMessageIfNeeded(stableFallbackID: id)
    }

    private func deleteLegacyMessageIfNeeded(stableFallbackID: String) throws {
        let records: [MessageRecord] = try database.getObjects(fromTable: WCDBTables.message)
        let legacyIDs = records.compactMap { record -> String? in
            guard UUID(uuidString: record.id) == nil else {
                return nil
            }
            let fallbackID = MessageRecord.stableFallbackUUIDString(
                rawID: record.id,
                conversationId: record.conversationId,
                role: record.role,
                timestamp: record.timestamp
            )
            if fallbackID == stableFallbackID {
                return record.id
            }
            let legacyFallbackID = MessageRecord.legacyStableFallbackUUIDString(
                rawID: record.id,
                conversationId: record.conversationId,
                role: record.role,
                timestamp: record.timestamp,
                content: record.content
            )
            return legacyFallbackID == stableFallbackID ? record.id : nil
        }

        guard !legacyIDs.isEmpty else { return }

        for rawID in legacyIDs {
            try database.delete(
                fromTable: WCDBTables.message,
                where: MessageRecord.Properties.id == rawID
            )
        }
    }

    func deleteAll() throws {
        try database.delete(fromTable: WCDBTables.message)
    }
}
