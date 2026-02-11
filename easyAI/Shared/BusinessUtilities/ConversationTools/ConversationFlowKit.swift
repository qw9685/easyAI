import Foundation

enum ConversationFlowKit {
    enum EnsureConversationDecision {
        case blocked(errorMessage: String)
        case ready
        case createNew
    }

    struct SessionTransition {
        let currentConversationId: String?
        let messages: [Message]
        let conversationId: UUID
        let currentTurnId: UUID?
        let shouldClearPendingMessageUpdates: Bool
        let shouldClearStopNotices: Bool
    }

    enum ConversationTouchDecision {
        case update([ConversationRecord])
        case reload(debounceMs: Int)
    }

    static func decideEnsureConversation(
        isResettingPersistence: Bool,
        currentConversationId: String?
    ) -> EnsureConversationDecision {
        if isResettingPersistence {
            return .blocked(errorMessage: "正在清空数据，请稍后重试。")
        }
        if currentConversationId != nil {
            return .ready
        }
        return .createNew
    }

    static func makeTransition(from snapshot: ChatSessionSnapshot) -> SessionTransition {
        SessionTransition(
            currentConversationId: snapshot.currentConversationId,
            messages: snapshot.messages,
            conversationId: snapshot.conversationId,
            currentTurnId: snapshot.currentTurnId,
            shouldClearPendingMessageUpdates: true,
            shouldClearStopNotices: true
        )
    }

    static func makeTransitionForCreatedConversation(conversationId: String) -> SessionTransition {
        SessionTransition(
            currentConversationId: conversationId,
            messages: [],
            conversationId: UUID(),
            currentTurnId: nil,
            shouldClearPendingMessageUpdates: true,
            shouldClearStopNotices: true
        )
    }

    static func decideConversationTouch(
        _ result: ConversationTouchResult,
        fallbackDebounceMs: Int = 150
    ) -> ConversationTouchDecision {
        switch result {
        case .updated(let updated):
            return .update(updated)
        case .needsReload:
            return .reload(debounceMs: fallbackDebounceMs)
        }
    }
}
