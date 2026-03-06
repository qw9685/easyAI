//
//  WCDBManager.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - WCDB 数据库初始化与迁移
//


import Foundation
import SQLite3
import WCDBSwift

enum WCDBTables {
    static let conversation = "conversation"
    static let message = "message"
    static let messageSearchIndex = "message_search_index"
    static let modelCache = "model_cache"
}

protocol WCDBTransactionRunning {
    func runTransaction<T>(_ work: () throws -> T) throws -> T
}

/// WCDB 入口（创建 DB + 初始化表结构/索引）
final class WCDBManager: WCDBTransactionRunning {
    static let shared = WCDBManager()

    let database: Database
    private let databasePath: String
    private let versionKey = "WCDB.schema.version"
    private let latestVersion = 7

    private init() {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("easyai.sqlite")
        databasePath = fileURL.path
        database = Database(at: fileURL)
        database.add(tokenizer: BuiltinTokenizer.Verbatim)
        database.setAutoMergeFTS5Index(enable: true)
        setupSchema()
    }

    /// Schema 初始化（幂等）
    /// - v1: conversation/message 表 + 索引
    /// - v2: model_cache 表 + 索引
    /// - v3: message 指标列（token/耗时/费用）
    /// - v4: message 路由元数据列（smart routing）
    /// - v5: 旧消息主键迁移为稳定 UUID
    /// - v6: message FTS5 全文索引虚表
    /// - v7: message FTS5 增加拼音字段并重建索引
    private func setupSchema() {
        do {
            let storedVersion = UserDefaults.standard.integer(forKey: versionKey)
            var conversationExists = try database.isTableExists(WCDBTables.conversation)
            var messageExists = try database.isTableExists(WCDBTables.message)
            var messageSearchIndexExists = try database.isTableExists(WCDBTables.messageSearchIndex)
            var modelCacheExists = try database.isTableExists(WCDBTables.modelCache)
            var createdMessageSearchIndex = false

            if !conversationExists {
                try database.create(table: WCDBTables.conversation, of: ConversationRecord.self)
                conversationExists = true
            }

            if !messageExists {
                try database.create(table: WCDBTables.message, of: MessageRecord.self)
                messageExists = true
            }

            if messageSearchIndexExists && storedVersion < 7 {
                try database.drop(table: WCDBTables.messageSearchIndex)
                messageSearchIndexExists = false
            }

            if !messageSearchIndexExists {
                try createMessageSearchIndexTableIfNeeded()
                messageSearchIndexExists = true
                createdMessageSearchIndex = true
            }

            if !modelCacheExists {
                try database.create(table: WCDBTables.modelCache, of: ModelCacheRecord.self)
                modelCacheExists = true
            }

            if messageExists {
                try createMessageConversationTimeIndexIfNeeded()
                try addMessageMetricsColumnsIfNeeded()
                try addMessageRoutingColumnsIfNeeded()
                if storedVersion < 5 {
                    try migrateLegacyMessageIDsIfNeeded()
                }
                if messageSearchIndexExists, (storedVersion < 7 || createdMessageSearchIndex) {
                    try rebuildMessageSearchIndex()
                }
            }

            if conversationExists {
                try createConversationUpdatedIndexIfNeeded()
            }

            if modelCacheExists {
                try createModelCacheUpdatedIndexIfNeeded()
            }

            if UserDefaults.standard.integer(forKey: versionKey) != latestVersion {
                UserDefaults.standard.set(latestVersion, forKey: versionKey)
            }
        } catch {
            RuntimeTools.AppDiagnostics.warn("WCDBManager", "Failed to setup schema: \(error)")
        }
    }

    func runTransaction<T>(_ work: () throws -> T) throws -> T {
        if database.isInTransaction {
            return try work()
        }

        try database.begin()
        do {
            let result = try work()
            try database.commit()
            return result
        } catch {
            try? database.rollback()
            throw error
        }
    }

    private func createMessageConversationTimeIndexIfNeeded() throws {
        do {
            try database.create(index: "idx_message_conversation_time",
                                with: [
                                    MessageRecord.Properties.conversationId.asIndex(),
                                    MessageRecord.Properties.timestamp.asIndex()
                                ],
                                forTable: WCDBTables.message)
        } catch {
            if !isSchemaAlreadyExistsError(error) {
                throw error
            }
        }
    }

    private func createMessageSearchIndexTableIfNeeded() throws {
        do {
            try database.create(virtualTable: WCDBTables.messageSearchIndex, of: MessageSearchIndexRecord.self)
        } catch {
            if !isSchemaAlreadyExistsError(error) {
                throw error
            }
        }
    }

    private func createConversationUpdatedIndexIfNeeded() throws {
        do {
            try database.create(index: "idx_conversation_updated",
                                with: [
                                    ConversationRecord.Properties.isPinned.asIndex(),
                                    ConversationRecord.Properties.updatedAt.asIndex()
                                ],
                                forTable: WCDBTables.conversation)
        } catch {
            if !isSchemaAlreadyExistsError(error) {
                throw error
            }
        }
    }

    private func createModelCacheUpdatedIndexIfNeeded() throws {
        do {
            try database.create(index: "idx_model_cache_updated",
                                with: [ModelCacheRecord.Properties.updatedAt.asIndex()],
                                forTable: WCDBTables.modelCache)
        } catch {
            if !isSchemaAlreadyExistsError(error) {
                throw error
            }
        }
    }

    private func addMessageMetricsColumnsIfNeeded() throws {
        let columns: [(name: String, def: ColumnDef)] = [
            ("prompt_tokens", MessageRecord.Properties.promptTokens.asDef(with: .integer32)),
            ("completion_tokens", MessageRecord.Properties.completionTokens.asDef(with: .integer32)),
            ("total_tokens", MessageRecord.Properties.totalTokens.asDef(with: .integer32)),
            ("latency_ms", MessageRecord.Properties.latencyMs.asDef(with: .integer32)),
            ("estimated_cost_usd", MessageRecord.Properties.estimatedCostUsd.asDef(with: .float)),
            ("metrics_estimated", MessageRecord.Properties.metricsEstimated.asDef(with: .integer32))
        ]

        try addColumnsIfMissing(columns, to: WCDBTables.message)
    }

    private func addMessageRoutingColumnsIfNeeded() throws {
        let columns: [(name: String, def: ColumnDef)] = [
            ("routing_from_model_id", MessageRecord.Properties.routingFromModelId.asDef(with: .text)),
            ("routing_to_model_id", MessageRecord.Properties.routingToModelId.asDef(with: .text)),
            ("routing_reason", MessageRecord.Properties.routingReason.asDef(with: .text)),
            ("routing_mode", MessageRecord.Properties.routingMode.asDef(with: .text)),
            ("routing_budget_mode", MessageRecord.Properties.routingBudgetMode.asDef(with: .text)),
            ("routing_timestamp", MessageRecord.Properties.routingTimestamp.asDef(with: .text))
        ]

        try addColumnsIfMissing(columns, to: WCDBTables.message)
    }

    private func addColumnsIfMissing(
        _ columns: [(name: String, def: ColumnDef)],
        to table: String
    ) throws {
        var existingColumns = try existingColumnNames(in: table)

        for column in columns {
            guard !existingColumns.contains(column.name) else {
                continue
            }

            do {
                try database.addColumn(with: column.def, forTable: table)
                existingColumns.insert(column.name)
            } catch {
                if isSchemaAlreadyExistsError(error) {
                    existingColumns.insert(column.name)
                    continue
                }
                RuntimeTools.AppDiagnostics.warn("WCDBManager", "Failed to add column \(column.name): \(error)")
            }
        }
    }

    private func existingColumnNames(in table: String) throws -> Set<String> {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(databasePath, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let handle else {
            let message = handle.flatMap { sqlite3_errmsg($0).map { String(cString: $0) } } ?? "unknown"
            sqlite3_close(handle)
            throw NSError(domain: "WCDBManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open database for schema inspection: \(message)"])
        }
        defer { sqlite3_close(handle) }

        let escapedTable = table.replacingOccurrences(of: "'", with: "''")
        let sql = "PRAGMA table_info('\(escapedTable)');"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            let message = sqlite3_errmsg(handle).map { String(cString: $0) } ?? "unknown"
            throw NSError(domain: "WCDBManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to inspect table schema: \(message)"])
        }
        defer { sqlite3_finalize(statement) }

        var columns = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            if let pointer = sqlite3_column_text(statement, 1) {
                columns.insert(String(cString: pointer).lowercased())
            }
        }
        return columns
    }

    private func migrateLegacyMessageIDsIfNeeded() throws {
        let records: [MessageRecord] = try database.getObjects(fromTable: WCDBTables.message)
        let legacyRecords = records.filter { UUID(uuidString: $0.id) == nil }
        guard !legacyRecords.isEmpty else { return }

        try runTransaction {
            var occupiedIDs = Set(records.compactMap { record in
                UUID(uuidString: record.id) == nil ? nil : record.id
            })

            for record in legacyRecords {
                guard let migratedID = resolvedMigratedMessageID(for: record, occupiedIDs: &occupiedIDs) else {
                    RuntimeTools.AppDiagnostics.warn(
                        "WCDBManager",
                        "Skipped legacy message id migration for rawID=\(record.id)"
                    )
                    continue
                }

                try database.update(
                    table: WCDBTables.message,
                    on: [MessageRecord.Properties.id],
                    with: [migratedID],
                    where: MessageRecord.Properties.id == record.id
                )
            }
        }
    }

    private func rebuildMessageSearchIndex() throws {
        let messageRecords: [MessageRecord] = try database.getObjects(fromTable: WCDBTables.message)
        let searchIndexRecords = messageRecords
            .map(MessageSearchIndexRecord.fromMessageRecord)
            .filter(\.isSearchable)

        try runTransaction {
            try database.delete(fromTable: WCDBTables.messageSearchIndex)
            guard !searchIndexRecords.isEmpty else { return }
            try database.insert(searchIndexRecords, intoTable: WCDBTables.messageSearchIndex)
        }
    }

    private func resolvedMigratedMessageID(
        for record: MessageRecord,
        occupiedIDs: inout Set<String>
    ) -> String? {
        let preferredID = MessageRecord.stableFallbackUUIDString(
            rawID: record.id,
            conversationId: record.conversationId,
            role: record.role,
            timestamp: record.timestamp
        )
        if !occupiedIDs.contains(preferredID) {
            occupiedIDs.insert(preferredID)
            return preferredID
        }

        let fallbackID = MessageRecord.legacyStableFallbackUUIDString(
            rawID: record.id,
            conversationId: record.conversationId,
            role: record.role,
            timestamp: record.timestamp,
            content: record.content
        )
        if !occupiedIDs.contains(fallbackID) {
            occupiedIDs.insert(fallbackID)
            return fallbackID
        }

        return nil
    }

    private func isSchemaAlreadyExistsError(_ error: Error) -> Bool {
        let message = [
            error.localizedDescription,
            String(describing: error),
            String(reflecting: error)
        ]
        .joined(separator: "\n")
        .lowercased()

        return message.contains("already exists")
            || message.contains("duplicate column")
            || message.contains("duplicate column name")
    }
}
