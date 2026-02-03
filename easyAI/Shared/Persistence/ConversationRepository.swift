//
//  ConversationRepository.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 会话表 CRUD
//
//


import Foundation
import WCDBSwift

final class ConversationRepository {
    static let shared = ConversationRepository()

    private let database: Database

    private init(database: Database = WCDBManager.shared.database) {
        self.database = database
    }

    func createConversation(title: String = "新对话") throws -> ConversationRecord {
        let now = Date()
        let record = ConversationRecord(
            id: UUID().uuidString,
            title: title,
            isPinned: false,
            createdAt: now,
            updatedAt: now
        )
        try database.insert(record, intoTable: WCDBTables.conversation)
        return record
    }

    func fetchConversation(id: String) throws -> ConversationRecord? {
        try database.getObject(
            fromTable: WCDBTables.conversation,
            where: ConversationRecord.Properties.id == id
        )
    }

    func fetchAll() throws -> [ConversationRecord] {
        try database.getObjects(
            fromTable: WCDBTables.conversation,
            orderBy: [
                ConversationRecord.Properties.isPinned.order(.descending),
                ConversationRecord.Properties.updatedAt.order(.descending)
            ]
        )
    }

    func fetchLatest() throws -> ConversationRecord? {
        try database.getObject(
            fromTable: WCDBTables.conversation,
            orderBy: [ConversationRecord.Properties.updatedAt.order(.descending)]
        )
    }

    func renameConversation(id: String, title: String) throws {
        try database.update(
            table: WCDBTables.conversation,
            on: [ConversationRecord.Properties.title, ConversationRecord.Properties.updatedAt],
            with: [title, Date()],
            where: ConversationRecord.Properties.id == id
        )
    }

    func setPinned(id: String, isPinned: Bool) throws {
        try database.update(
            table: WCDBTables.conversation,
            on: [ConversationRecord.Properties.isPinned, ConversationRecord.Properties.updatedAt],
            with: [isPinned, Date()],
            where: ConversationRecord.Properties.id == id
        )
    }

    func touch(id: String) throws {
        try database.update(
            table: WCDBTables.conversation,
            on: [ConversationRecord.Properties.updatedAt],
            with: [Date()],
            where: ConversationRecord.Properties.id == id
        )
    }

    func deleteConversation(id: String) throws {
        try database.delete(fromTable: WCDBTables.conversation,
                            where: ConversationRecord.Properties.id == id)
    }

    func deleteAll() throws {
        try database.delete(fromTable: WCDBTables.conversation)
    }
}
