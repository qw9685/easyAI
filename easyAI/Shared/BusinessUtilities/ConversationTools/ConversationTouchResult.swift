import Foundation

enum ConversationTouchResult {
    case updated([ConversationRecord])
    case needsReload
}
