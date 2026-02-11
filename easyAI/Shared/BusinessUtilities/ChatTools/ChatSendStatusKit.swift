import Foundation

enum ChatSendStatusKit {
    static func fallbackStatusText(modelName: String, attempt: Int) -> String {
        "已切换到 \(modelName)（重试 \(attempt) 次）"
    }

    static func mergedStatus(fallbackStatusText: String?, routingStatusText: String?) -> String? {
        let parts = [routingStatusText, fallbackStatusText].compactMap { text -> String? in
            guard let text, !text.isEmpty else { return nil }
            return text
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    static func errorMergedStatus(
        fallbackStatusText: String?,
        classifiedStatus: String
    ) -> String {
        guard let fallbackStatusText, !fallbackStatusText.isEmpty else {
            return classifiedStatus
        }
        return "\(fallbackStatusText) · \(classifiedStatus)"
    }
}
