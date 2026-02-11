import Foundation

enum ChatTableUpdateAction: Equatable {
    case bindSections
    case streamingReloadLastMarkdownRow
}

enum ChatRenderPolicyKit {
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func buildRows(
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
                let statusText = composeStatusText(message: message, noticeText: noticeMap[message.id]?.text)
                items.append(.messageMarkdown(message, statusText: statusText))
                if statusText != nil {
                    noticeAttachedToMessage.insert(message.id)
                }
            } else if let notice = noticeMap[message.id] {
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

    static func planTableUpdate(prev: ChatListState?, curr: ChatListState) -> ChatTableUpdateAction {
        guard let prev else { return .bindSections }
        if prev.conversationId != curr.conversationId { return .bindSections }
        if prev.isLoading != curr.isLoading { return .bindSections }
        if prev.stopNotices != curr.stopNotices { return .bindSections }
        if prev.messages.count != curr.messages.count { return .bindSections }
        guard curr.messages.count > 0 else { return .bindSections }

        let lastIndex = curr.messages.count - 1
        let prevLast = prev.messages[lastIndex]
        let currLast = curr.messages[lastIndex]
        if prevLast.id != currLast.id { return .bindSections }

        if currLast.isStreaming,
           prevLast.content.isEmpty,
           !currLast.content.isEmpty {
            return .bindSections
        }

        if currLast.isStreaming,
           prevLast.isStreaming == currLast.isStreaming,
           prevLast.wasStreamed == currLast.wasStreamed,
           prevLast.content != currLast.content {
            return .streamingReloadLastMarkdownRow
        }

        return .bindSections
    }

    private static func composeStatusText(message: Message, noticeText: String?) -> String? {
        let metricsText = makeMetricsStatus(message.metrics)
        let runtimeText = message.runtimeStatusText?.trimmingCharacters(in: .whitespacesAndNewlines)

        let notice = noticeText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [notice, runtimeText, metricsText].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        guard !parts.isEmpty else { return nil }
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
