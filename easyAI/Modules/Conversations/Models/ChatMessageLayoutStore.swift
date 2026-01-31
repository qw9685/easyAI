//
//  ChatMessageLayoutStore.swift
//  EasyAI
//
//  创建于 2026
//

import UIKit

final class ChatMessageLayoutStore {
    static let shared = ChatMessageLayoutStore()

    struct State {
        var streamingMaxPreferredWidth: CGFloat
        var pinnedToMaxWidth: Bool
    }

    private struct Key: Hashable {
        let messageId: UUID
        let contentSizeCategory: String
    }

    private var states: [Key: State] = [:]
    private let lock = NSLock()

    private init() {}

    func state(messageId: UUID, contentSizeCategory: UIContentSizeCategory) -> State? {
        lock.lock()
        defer { lock.unlock() }
        return states[Key(messageId: messageId, contentSizeCategory: contentSizeCategory.rawValue)]
    }

    func upsertStreamingMaxPreferredWidth(
        messageId: UUID,
        contentSizeCategory: UIContentSizeCategory,
        value: CGFloat
    ) -> CGFloat {
        lock.lock()
        defer { lock.unlock() }

        let key = Key(messageId: messageId, contentSizeCategory: contentSizeCategory.rawValue)
        let current = states[key]?.streamingMaxPreferredWidth ?? 0
        let next = max(current, value)
        let pinned = states[key]?.pinnedToMaxWidth ?? false
        states[key] = State(streamingMaxPreferredWidth: next, pinnedToMaxWidth: pinned)
        return next
    }

    func setPinnedToMaxWidth(
        messageId: UUID,
        contentSizeCategory: UIContentSizeCategory,
        pinned: Bool
    ) {
        lock.lock()
        defer { lock.unlock() }

        let key = Key(messageId: messageId, contentSizeCategory: contentSizeCategory.rawValue)
        if var existing = states[key] {
            existing.pinnedToMaxWidth = pinned
            states[key] = existing
        } else if pinned {
            states[key] = State(streamingMaxPreferredWidth: 0, pinnedToMaxWidth: true)
        }
    }

    func clear(messageId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        states = states.filter { $0.key.messageId != messageId }
    }
}

