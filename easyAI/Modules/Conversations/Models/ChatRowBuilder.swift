//
//  ChatRowBuilder.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 将消息与加载状态构建为行模型
//
//

import Foundation

enum ChatRowBuilder {
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func build(
        messages: [Message],
        isLoading: Bool,
        stopNotices: [ChatStopNotice]
    ) -> [ChatRow] {
        var items: [ChatRow] = []
        items.reserveCapacity(messages.count * 2)

        var noticeAttachedToMessage = Set<UUID>()
        let noticeMap: [UUID: ChatStopNotice] = Dictionary(
            uniqueKeysWithValues: stopNotices.compactMap { notice in
                guard let messageId = notice.messageId else { return nil }
                return (messageId, notice)
            }
        )

        for message in messages {
            if !message.mediaContents.isEmpty {
                items.append(.messageMedia(message))
                continue
            }

            if message.role == .user {
                let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    items.append(.messageSend(message))
                }
            } else if !message.content.isEmpty {
                // Normal assistant message: render markdown bubble, optionally with a stop status.
                let statusText = composeStatusText(
                    message: message,
                    noticeText: noticeMap[message.id]?.text
                )
                items.append(.messageMarkdown(message, statusText: statusText))
                if statusText != nil {
                    noticeAttachedToMessage.insert(message.id)
                }
            } else if let notice = noticeMap[message.id] {
                // Stop happened before any text was produced: render a compact status row instead of a tall empty bubble row.
                items.append(.stopNotice(notice))
                noticeAttachedToMessage.insert(message.id)
            }
        }

        for notice in stopNotices where notice.messageId == nil {
            items.append(.stopNotice(notice))
        }

        for notice in stopNotices where notice.messageId != nil {
            guard let messageId = notice.messageId else { continue }
            if !noticeAttachedToMessage.contains(messageId) {
                items.append(.stopNotice(notice))
            }
        }

        if isLoading {
            items.append(.loading)
        }

        return items
    }

    private static func composeStatusText(message: Message, noticeText: String?) -> String? {
        let metricsText = makeMetricsStatus(message.metrics)
        let runtimeText = message.runtimeStatusText?.trimmingCharacters(in: .whitespacesAndNewlines)

        let notice = noticeText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [notice, runtimeText, metricsText].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        guard !parts.isEmpty else {
            return nil
        }
        return parts.joined(separator: " · ")
    }

    private static func makeMetricsStatus(_ metrics: MessageMetrics?) -> String? {
        guard let metrics else { return nil }

        var parts: [String] = []
        if let totalTokens = metrics.totalTokens {
            parts.append("\(formatInteger(totalTokens)) tok")
        }

        if let latencyMs = metrics.latencyMs {
            parts.append(formatLatency(latencyMs))
        }

        if let cost = metrics.estimatedCostUSD {
            let prefix = metrics.isEstimated ? "≈" : ""
            parts.append("\(prefix)$\(formatCost(cost))")
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    private static func formatInteger(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func formatLatency(_ latencyMs: Int) -> String {
        if latencyMs < 1000 {
            return "\(latencyMs)ms"
        }
        let seconds = Double(latencyMs) / 1000
        return String(format: "%.2fs", seconds)
    }

    private static func formatCost(_ usd: Double) -> String {
        if usd < 0.0001 {
            return "<0.0001"
        }
        return String(format: "%.4f", usd)
    }
}
