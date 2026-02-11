//
//  Message.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 聊天消息领域模型
//
//


import Foundation
import UIKit

struct MessageMetrics: Codable, Hashable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
    let latencyMs: Int?
    let estimatedCostUSD: Double?
    let isEstimated: Bool

    init(
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        totalTokens: Int? = nil,
        latencyMs: Int? = nil,
        estimatedCostUSD: Double? = nil,
        isEstimated: Bool = true
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.latencyMs = latencyMs
        self.estimatedCostUSD = estimatedCostUSD
        self.isEstimated = isEstimated
    }
}



struct MessageRoutingMetadata: Codable, Hashable {
    let fromModelId: String?
    let toModelId: String
    let reason: String
    let mode: RoutingMode
    let budgetMode: BudgetMode
    let timestamp: Date

    init(
        fromModelId: String?,
        toModelId: String,
        reason: String,
        mode: RoutingMode,
        budgetMode: BudgetMode,
        timestamp: Date = Date()
    ) {
        self.fromModelId = fromModelId
        self.toModelId = toModelId
        self.reason = reason
        self.mode = mode
        self.budgetMode = budgetMode
        self.timestamp = timestamp
    }
}

struct Message: Identifiable, Codable {
    let id: UUID
    /// 内容需要在打字机效果中逐步更新，因此使用 `var`
    var content: String
    let role: MessageRole
    let timestamp: Date
    /// 是否为流式消息（stream 模式下，直接显示文本，不使用打字机效果）
    var isStreaming: Bool
    /// 是否曾经是流式消息（用于标记该消息应该始终直接显示，不使用打字机效果）
    var wasStreamed: Bool
    /// 媒体内容列表（图片、视频、音频、PDF等）
    var mediaContents: [MediaContent]
    /// phase: 一轮对话的 turnId（用于稳定 identity 与日志关联）
    let turnId: UUID?
    /// phase: 稳定的 baseId（推荐：c:<conversationId>|t:<turnId>）
    let baseId: String?
    /// phase: 稳定的 itemId（推荐：<baseId>|k:<kind>|p:<part>）
    let itemId: String?
    /// 回复指标（token/耗时/费用）
    var metrics: MessageMetrics?
    /// 运行态状态提示（如 fallback 路径），用于 UI 展示
    var runtimeStatusText: String?
    /// 路由元数据（智能路由命中信息）
    var routingMetadata: MessageRoutingMetadata?

    init(
        id: UUID = UUID(),
        content: String,
        role: MessageRole,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        wasStreamed: Bool = false,
        mediaContents: [MediaContent] = [],
        turnId: UUID? = nil,
        baseId: String? = nil,
        itemId: String? = nil,
        metrics: MessageMetrics? = nil,
        runtimeStatusText: String? = nil,
        routingMetadata: MessageRoutingMetadata? = nil
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.wasStreamed = wasStreamed
        self.mediaContents = mediaContents
        self.turnId = turnId
        self.baseId = baseId
        self.itemId = itemId
        self.metrics = metrics
        self.runtimeStatusText = runtimeStatusText
        self.routingMetadata = routingMetadata
    }

    // MARK: - Convenience
    var hasMedia: Bool {
        !mediaContents.isEmpty
    }

    var hasImage: Bool {
        mediaContents.contains(where: { $0.type == .image })
    }

    func getImageDataURL() -> String? {
        mediaContents.first(where: { $0.type == .image })?.getDataURL()
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}
