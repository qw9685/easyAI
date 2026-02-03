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
                MessageRecord.Properties.wasStreamed
            ],
            with: [
                record.content,
                record.isStreaming,
                record.wasStreamed
            ],
            where: MessageRecord.Properties.id == record.id
        )
    }

    func fetchMessages(conversationId: String, limit: Int? = nil, offset: Int? = nil) throws -> [Message] {
        let records: [MessageRecord] = try database.getObjects(
            fromTable: WCDBTables.message,
            where: MessageRecord.Properties.conversationId == conversationId,
            orderBy: [MessageRecord.Properties.timestamp.order(.ascending)],
            limit: limit,
            offset: offset
        )
        return records.map { $0.toMessage() }
    }

    func deleteMessages(conversationId: String) throws {
        try database.delete(fromTable: WCDBTables.message,
                            where: MessageRecord.Properties.conversationId == conversationId)
    }

    func deleteAll() throws {
        try database.delete(fromTable: WCDBTables.message)
    }
}
