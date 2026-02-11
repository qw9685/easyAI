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
                models = try DataTools.CodecCenter.jsonDecoder.decode([OpenRouterModelInfo].self, from: record.payload)
            } catch {
                RuntimeTools.AppDiagnostics.warn("ModelCacheRepository", "Cache payload decode failed: \(error)")
                clearCache()
                return nil
            }

            return (models: models, updatedAt: record.updatedAt)
        } catch {
            RuntimeTools.AppDiagnostics.warn("ModelCacheRepository", "Failed to read cache: \(error)")
            return nil
        }
    }

    func writeCache(models: [OpenRouterModelInfo]) {
        guard let payload = try? DataTools.CodecCenter.jsonEncoder.encode(models) else { return }
        let record = ModelCacheRecord(id: cacheId, payload: payload, updatedAt: Date())
        do {
            try database.insertOrReplace(record, intoTable: WCDBTables.modelCache)
        } catch {
            RuntimeTools.AppDiagnostics.warn("ModelCacheRepository", "Failed to write cache: \(error)")
        }
    }

    func clearCache() {
        do {
            try database.delete(fromTable: WCDBTables.modelCache,
                                where: ModelCacheRecord.Properties.id == cacheId)
        } catch {
            RuntimeTools.AppDiagnostics.warn("ModelCacheRepository", "Failed to clear cache: \(error)")
        }
    }
}
