//
//  ModelCacheRecord.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 模型缓存表记录模型
//
//


import Foundation
import WCDBSwift

struct ModelCacheRecord: TableCodable {
    var id: String
    var payload: Data
    var updatedAt: Date

    enum CodingKeys: String, CodingTableKey {
        typealias Root = ModelCacheRecord
        case id
        case payload
        case updatedAt = "updated_at"
        nonisolated(unsafe) static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true)
        }
    }
}
