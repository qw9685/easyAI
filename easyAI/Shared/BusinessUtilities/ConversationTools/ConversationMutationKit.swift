import Foundation

enum ConversationMutationKit {
    static func applyRename(
        id: String,
        title: String,
        touchedAt: Date = Date(),
        conversations: [ConversationRecord]
    ) -> [ConversationRecord] {
        mutate(conversations: conversations, id: id, touchedAt: touchedAt) { record in
            record.title = title
        }
    }

    static func applyPinned(
        id: String,
        isPinned: Bool,
        touchedAt: Date = Date(),
        conversations: [ConversationRecord]
    ) -> [ConversationRecord] {
        mutate(conversations: conversations, id: id, touchedAt: touchedAt) { record in
            record.isPinned = isPinned
        }
    }

    static func removeConversation(
        id: String,
        conversations: [ConversationRecord]
    ) -> [ConversationRecord] {
        conversations.filter { $0.id != id }
    }

    static func applyTouch(
        conversationId: String,
        touchedAt: Date,
        title: String? = nil,
        conversations: [ConversationRecord]
    ) -> [ConversationRecord]? {
        var updated = conversations
        guard let index = updated.firstIndex(where: { $0.id == conversationId }) else {
            return nil
        }
        if let title {
            updated[index].title = title
        }
        updated[index].updatedAt = touchedAt
        return ConversationOrderingKit.sort(updated)
    }

    private static func mutate(
        conversations: [ConversationRecord],
        id: String,
        touchedAt: Date,
        operation: (inout ConversationRecord) -> Void
    ) -> [ConversationRecord] {
        var updated = conversations
        if let index = updated.firstIndex(where: { $0.id == id }) {
            operation(&updated[index])
            updated[index].updatedAt = touchedAt
        }
        return ConversationOrderingKit.sort(updated)
    }
}
