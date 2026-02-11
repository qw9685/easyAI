//
//  ModelCacheRepository.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 模型缓存读写
//
//


import Foundation
import WCDBSwift

final class ModelCacheRepository {
    static let shared = ModelCacheRepository()

    private let database: Database
    private let cacheId = "openrouter_models"

    private init(database: Database = WCDBManager.shared.database) {
        self.database = database
    }

    func readCache() -> (models: [OpenRouterModelInfo], updatedAt: Date)? {
        do {
            let record: ModelCacheRecord? = try database.getObject(
                fromTable: WCDBTables.modelCache,
                where: ModelCacheRecord.Properties.id == cacheId
            )
            guard let record else { return nil }

            let models: [OpenRouterModelInfo]
            do {
                models = try JSONDecoder().decode([OpenRouterModelInfo].self, from: record.payload)
            } catch {
                print("[ModelCacheRepository] ⚠️ Cache payload decode failed: \(error)")
                clearCache()
                return nil
            }

            return (models: models, updatedAt: record.updatedAt)
        } catch {
            print("[ModelCacheRepository] ⚠️ Failed to read cache: \(error)")
            return nil
        }
    }

    func writeCache(models: [OpenRouterModelInfo]) {
        guard let payload = try? JSONEncoder().encode(models) else { return }
        let record = ModelCacheRecord(id: cacheId, payload: payload, updatedAt: Date())
        do {
            try database.insertOrReplace(record, intoTable: WCDBTables.modelCache)
        } catch {
            print("[ModelCacheRepository] ⚠️ Failed to write cache: \(error)")
        }
    }

    func clearCache() {
        do {
            try database.delete(fromTable: WCDBTables.modelCache,
                                where: ModelCacheRecord.Properties.id == cacheId)
        } catch {
            print("[ModelCacheRepository] ⚠️ Failed to clear cache: \(error)")
        }
    }
}
