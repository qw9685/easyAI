import Foundation

enum ConversationOrderingKit {
    static func sort(_ conversations: [ConversationRecord]) -> [ConversationRecord] {
        conversations.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    static func applyTouch(
        conversationId: String,
        touchedAt: Date,
        conversations: [ConversationRecord]
    ) -> [ConversationRecord]? {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            return nil
        }
        var updated = conversations
        updated[index].updatedAt = touchedAt
        return sort(updated)
    }
}
