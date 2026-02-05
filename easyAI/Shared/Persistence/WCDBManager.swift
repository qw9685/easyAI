//
//  WCDBManager.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - WCDB 数据库初始化与迁移
//
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
    private let latestVersion = 2

    private init() {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("easyai.sqlite")
        database = Database(at: fileURL)
        setupSchema()
    }

    /// Schema 初始化（幂等）
    /// - v1: conversation/message 表 + 索引
    /// - v2: model_cache 表 + 索引
    private func setupSchema() {
        do {
            let currentVersion = UserDefaults.standard.integer(forKey: versionKey)
            var conversationExists = try database.isTableExists(WCDBTables.conversation)
            var messageExists = try database.isTableExists(WCDBTables.message)
            var modelCacheExists = try database.isTableExists(WCDBTables.modelCache)

            if currentVersion < 1 || !conversationExists || !messageExists {
                if !conversationExists {
                    try database.create(table: WCDBTables.conversation, of: ConversationRecord.self)
                    conversationExists = true
                }
                if !messageExists {
                    try database.create(table: WCDBTables.message, of: MessageRecord.self)
                    messageExists = true
                }

                if messageExists {
                    try database.create(index: "idx_message_conversation_time",
                                        with: [
                                            MessageRecord.Properties.conversationId.asIndex(),
                                            MessageRecord.Properties.timestamp.asIndex()
                                        ],
                                        forTable: WCDBTables.message)
                }
                if conversationExists {
                    try database.create(index: "idx_conversation_updated",
                                        with: [
                                            ConversationRecord.Properties.isPinned.asIndex(),
                                            ConversationRecord.Properties.updatedAt.asIndex()
                                        ],
                                        forTable: WCDBTables.conversation)
                }
            }

            if currentVersion < 2 || !modelCacheExists {
                if !modelCacheExists {
                    try database.create(table: WCDBTables.modelCache, of: ModelCacheRecord.self)
                    modelCacheExists = true
                }
                if modelCacheExists {
                    try database.create(index: "idx_model_cache_updated",
                                        with: [ModelCacheRecord.Properties.updatedAt.asIndex()],
                                        forTable: WCDBTables.modelCache)
                }
            }

            if currentVersion != latestVersion {
                UserDefaults.standard.set(latestVersion, forKey: versionKey)
            }
        } catch {
            print("[WCDBManager] ⚠️ Failed to setup schema: \(error)")
        }
    }
}
