//
//  ConversationListUseCase.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 会话列表加载与排序
//  - 会话增删改与消息读取
//

import Foundation

enum ConversationTouchResult {
    case updated([ConversationRecord])
    case needsReload
}

final class ConversationListUseCase {
    private let coordinator: ConversationCoordinator
    private var loadTask: Task<Void, Never>?

    init(coordinator: ConversationCoordinator) {
        self.coordinator = coordinator
    }

    func loadConversations(
        debounceMs: Int = 150,
        onLoaded: @MainActor @escaping ([ConversationRecord]) -> Void,
        onError: ((Error) -> Void)? = nil
    ) {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            if debounceMs > 0 {
                try? await Task.sleep(nanoseconds: UInt64(debounceMs) * 1_000_000)
            }
            guard !Task.isCancelled else { return }
            do {
                let records = try self.coordinator.fetchAllConversations()
                await MainActor.run {
                    onLoaded(records)
                }
            } catch {
                onError?(error)
            }
        }
    }

    func fetchMessagesInBackground(conversationId: String) async throws -> [Message] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else {
                    continuation.resume(returning: [])
                    return
                }
                do {
                    let messages = try self.coordinator.fetchMessages(conversationId: conversationId)
                    continuation.resume(returning: messages)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func renameConversation(id: String, title: String) throws {
        try coordinator.renameConversation(id: id, title: title)
    }

    func applyRename(
        id: String,
        title: String,
        conversations: [ConversationRecord]
    ) -> [ConversationRecord] {
        var updated = conversations
        if let index = updated.firstIndex(where: { $0.id == id }) {
            updated[index].title = title
            updated[index].updatedAt = Date()
        }
        return sortConversations(updated)
    }

    func setPinned(id: String, isPinned: Bool) throws {
        try coordinator.setPinned(id: id, isPinned: isPinned)
    }

    func applyPinned(
        id: String,
        isPinned: Bool,
        conversations: [ConversationRecord]
    ) -> [ConversationRecord] {
        var updated = conversations
        if let index = updated.firstIndex(where: { $0.id == id }) {
            updated[index].isPinned = isPinned
            updated[index].updatedAt = Date()
        }
        return sortConversations(updated)
    }

    func deleteConversation(id: String) throws {
        try coordinator.deleteConversationAndMessages(id: id)
    }

    func removeConversation(
        id: String,
        conversations: [ConversationRecord]
    ) -> [ConversationRecord] {
        conversations.filter { $0.id != id }
    }

    func createConversation(title: String = "新对话") throws -> ConversationRecord {
        try coordinator.createConversation(title: title)
    }

    func deleteMessage(id: String) throws {
        try coordinator.deleteMessage(id: id)
    }

    func applyConversationTouch(
        conversationId: String,
        touchedAt: Date,
        conversations: [ConversationRecord]
    ) -> ConversationTouchResult {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            return .needsReload
        }
        var updated = conversations
        updated[index].updatedAt = touchedAt
        return .updated(sortConversations(updated))
    }

    private func sortConversations(_ conversations: [ConversationRecord]) -> [ConversationRecord] {
        conversations.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }
}
