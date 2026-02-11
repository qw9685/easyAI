//
//  MessageRecord.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 消息表记录模型与编解码
//
//


import Foundation
import CryptoKit
import WCDBSwift

struct MessageRecord: TableCodable {
    var id: String
    var conversationId: String
    var role: String
    var content: String
    var timestamp: Date
    var isStreaming: Bool
    var wasStreamed: Bool
    var mediaPayload: Data?
    var turnId: String?
    var baseId: String?
    var itemId: String?
    var promptTokens: Int?
    var completionTokens: Int?
    var totalTokens: Int?
    var latencyMs: Int?
    var estimatedCostUsd: Double?
    var metricsEstimated: Bool?
    var routingFromModelId: String?
    var routingToModelId: String?
    var routingReason: String?
    var routingMode: String?
    var routingBudgetMode: String?
    var routingTimestamp: Date?

    enum CodingKeys: String, CodingTableKey {
        typealias Root = MessageRecord
        case id
        case conversationId = "conversation_id"
        case role
        case content
        case timestamp
        case isStreaming = "is_streaming"
        case wasStreamed = "was_streamed"
        case mediaPayload = "media_payload"
        case turnId = "turn_id"
        case baseId = "base_id"
        case itemId = "item_id"
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case latencyMs = "latency_ms"
        case estimatedCostUsd = "estimated_cost_usd"
        case metricsEstimated = "metrics_estimated"
        case routingFromModelId = "routing_from_model_id"
        case routingToModelId = "routing_to_model_id"
        case routingReason = "routing_reason"
        case routingMode = "routing_mode"
        case routingBudgetMode = "routing_budget_mode"
        case routingTimestamp = "routing_timestamp"
        nonisolated(unsafe) static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true)
        }
    }

    static func fromMessage(_ message: Message, conversationId: String) -> MessageRecord {
        return MessageRecord(
            id: message.id.uuidString,
            conversationId: conversationId,
            role: message.role.rawValue,
            content: message.content,
            timestamp: message.timestamp,
            isStreaming: message.isStreaming,
            wasStreamed: message.wasStreamed,
            mediaPayload: encodeMedia(message.mediaContents),
            turnId: message.turnId?.uuidString,
            baseId: message.baseId,
            itemId: message.itemId,
            promptTokens: message.metrics?.promptTokens,
            completionTokens: message.metrics?.completionTokens,
            totalTokens: message.metrics?.totalTokens,
            latencyMs: message.metrics?.latencyMs,
            estimatedCostUsd: message.metrics?.estimatedCostUSD,
            metricsEstimated: message.metrics?.isEstimated,
            routingFromModelId: message.routingMetadata?.fromModelId,
            routingToModelId: message.routingMetadata?.toModelId,
            routingReason: message.routingMetadata?.reason,
            routingMode: message.routingMetadata?.mode.rawValue,
            routingBudgetMode: message.routingMetadata?.budgetMode.rawValue,
            routingTimestamp: message.routingMetadata?.timestamp
        )
    }

    func toMessage() -> Message {
        return Message(
            id: resolvedMessageID(),
            content: content,
            role: MessageRole(rawValue: role) ?? .assistant,
            timestamp: timestamp,
            isStreaming: isStreaming,
            wasStreamed: wasStreamed,
            mediaContents: decodeMedia(mediaPayload),
            turnId: turnId.flatMap { UUID(uuidString: $0) },
            baseId: baseId,
            itemId: itemId,
            metrics: makeMetrics(),
            routingMetadata: makeRoutingMetadata()
        )
    }


    private func makeRoutingMetadata() -> MessageRoutingMetadata? {
        guard let toModelId = routingToModelId,
              let reason = routingReason,
              let modeRaw = routingMode,
              let budgetRaw = routingBudgetMode,
              let mode = RoutingMode(rawValue: modeRaw),
              let budgetMode = BudgetMode(rawValue: budgetRaw) else {
            return nil
        }

        return MessageRoutingMetadata(
            fromModelId: routingFromModelId,
            toModelId: toModelId,
            reason: reason,
            mode: mode,
            budgetMode: budgetMode,
            timestamp: routingTimestamp ?? timestamp
        )
    }

    private func makeMetrics() -> MessageMetrics? {
        if promptTokens == nil,
           completionTokens == nil,
           totalTokens == nil,
           latencyMs == nil,
           estimatedCostUsd == nil {
            return nil
        }

        return MessageMetrics(
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens,
            latencyMs: latencyMs,
            estimatedCostUSD: estimatedCostUsd,
            isEstimated: metricsEstimated ?? true
        )
    }

    private func resolvedMessageID() -> UUID {
        if let uuid = UUID(uuidString: id) {
            return uuid
        }

        return Self.stableFallbackUUID(
            rawID: id,
            conversationId: conversationId,
            role: role,
            timestamp: timestamp
        )
    }

    static func stableFallbackUUIDString(
        rawID: String,
        conversationId: String,
        role: String,
        timestamp: Date
    ) -> String {
        stableFallbackUUID(
            rawID: rawID,
            conversationId: conversationId,
            role: role,
            timestamp: timestamp
        ).uuidString
    }

    static func legacyStableFallbackUUIDString(
        rawID: String,
        conversationId: String,
        role: String,
        timestamp: Date,
        content: String
    ) -> String {
        legacyStableFallbackUUID(
            rawID: rawID,
            conversationId: conversationId,
            role: role,
            timestamp: timestamp,
            content: content
        ).uuidString
    }

    private static func stableFallbackUUID(
        rawID: String,
        conversationId: String,
        role: String,
        timestamp: Date
    ) -> UUID {
        let fallbackSeed = [
            rawID,
            conversationId,
            role,
            String(timestamp.timeIntervalSince1970)
        ].joined(separator: "|")

        var bytes = Array(SHA256.hash(data: Data(fallbackSeed.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        let uuidBytes: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuidBytes)
    }

    private static func legacyStableFallbackUUID(
        rawID: String,
        conversationId: String,
        role: String,
        timestamp: Date,
        content: String
    ) -> UUID {
        let fallbackSeed = [
            rawID,
            conversationId,
            role,
            String(timestamp.timeIntervalSince1970),
            String(content.prefix(64))
        ].joined(separator: "|")

        var bytes = Array(SHA256.hash(data: Data(fallbackSeed.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        let uuidBytes: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuidBytes)
    }

    private static func encodeMedia(_ media: [MediaContent]) -> Data? {
        guard !media.isEmpty else { return nil }
        return try? JSONEncoder().encode(media)
    }

    private func decodeMedia(_ data: Data?) -> [MediaContent] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([MediaContent].self, from: data)) ?? []
    }
}
