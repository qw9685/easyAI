//
//  ConversationRecord.swift
//  EasyAI
//
//  创建于 2026
//


import Foundation
import WCDBSwift

struct ConversationRecord: TableCodable {
    var id: String
    var title: String
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingTableKey {
        typealias Root = ConversationRecord
        case id
        case title
        case isPinned = "is_pinned"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        nonisolated(unsafe) static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true)
        }
    }
}
