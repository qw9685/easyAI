import Foundation

enum ConversationIdentityKit {
    static func makeBaseId(conversationId: UUID, turnId: UUID) -> String {
        "c:\(conversationId.uuidString)|t:\(turnId.uuidString)"
    }

    static func makeItemId(baseId: String, kind: String, part: String) -> String {
        "\(baseId)|k:\(kind)|p:\(part)"
    }
}
