//
//  WCDBManager.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - WCDB 数据库初始化与迁移
//


import Foundation
import WCDBSwift

enum WCDBTables {
    static let conversation = "conversation"
    static let message = "message"
    static let modelCache = "model_cache"
}

/// WCDB 入口（创建 DB + 初始化表结构/索引）
final class WCDBManager {
    static let shared = WCDBManager()

    let database: Database
    private let versionKey = "WCDB.schema.version"
    private let latestVersion = 4

    private init() {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("easyai.sqlite")
        database = Database(at: fileURL)
        setupSchema()
    }

    /// Schema 初始化（幂等）
    /// - v1: conversation/message 表 + 索引
    /// - v2: model_cache 表 + 索引
    /// - v3: message 指标列（token/耗时/费用）
    /// - v4: message 路由元数据列（smart routing）
    private func setupSchema() {
        do {
            var conversationExists = try database.isTableExists(WCDBTables.conversation)
            var messageExists = try database.isTableExists(WCDBTables.message)
            var modelCacheExists = try database.isTableExists(WCDBTables.modelCache)

            if !conversationExists {
                try database.create(table: WCDBTables.conversation, of: ConversationRecord.self)
                conversationExists = true
            }

            if !messageExists {
                try database.create(table: WCDBTables.message, of: MessageRecord.self)
                messageExists = true
            }

            if !modelCacheExists {
                try database.create(table: WCDBTables.modelCache, of: ModelCacheRecord.self)
                modelCacheExists = true
            }

            if messageExists {
                try createMessageConversationTimeIndexIfNeeded()
                try addMessageMetricsColumnsIfNeeded()
                try addMessageRoutingColumnsIfNeeded()
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
            print("[WCDBManager] ⚠️ Failed to setup schema: \(error)")
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

        for column in columns {
            do {
                try database.addColumn(with: column.def, forTable: WCDBTables.message)
            } catch {
                if isSchemaAlreadyExistsError(error) {
                    continue
                }
                print("[WCDBManager] ⚠️ Failed to add column \(column.name): \(error)")
            }
        }
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

        for column in columns {
            do {
                try database.addColumn(with: column.def, forTable: WCDBTables.message)
            } catch {
                if isSchemaAlreadyExistsError(error) {
                    continue
                }
                print("[WCDBManager] ⚠️ Failed to add column \(column.name): \(error)")
            }
        }
    }

    private func isSchemaAlreadyExistsError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("already exists") || message.contains("duplicate column")
    }
}
