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
                let records = try await RuntimeTools.AsyncExecutor.run {
                    try self.coordinator.fetchAllConversations()
                }
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    onLoaded(records)
                }
            } catch {
                guard !Task.isCancelled else { return }
                if let onError {
                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        onError(error)
                    }
                }
            }
        }
    }

    func fetchMessagesInBackground(conversationId: String) async throws -> [Message] {
        try await RuntimeTools.AsyncExecutor.run { [weak self] in
            guard let self else { return [] }
            return try self.coordinator.fetchMessages(conversationId: conversationId)
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
        ConversationMutationKit.applyRename(
            id: id,
            title: title,
            conversations: conversations
        )
    }

    func setPinned(id: String, isPinned: Bool) throws {
        try coordinator.setPinned(id: id, isPinned: isPinned)
    }

    func applyPinned(
        id: String,
        isPinned: Bool,
        conversations: [ConversationRecord]
    ) -> [ConversationRecord] {
        ConversationMutationKit.applyPinned(
            id: id,
            isPinned: isPinned,
            conversations: conversations
        )
    }

    func deleteConversation(id: String) throws {
        try coordinator.deleteConversationAndMessages(id: id)
    }

    func removeConversation(
        id: String,
        conversations: [ConversationRecord]
    ) -> [ConversationRecord] {
        ConversationMutationKit.removeConversation(
            id: id,
            conversations: conversations
        )
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
        title: String? = nil,
        conversations: [ConversationRecord]
    ) -> ConversationTouchResult {
        guard let updated = ConversationMutationKit.applyTouch(
            conversationId: conversationId,
            touchedAt: touchedAt,
            title: title,
            conversations: conversations
        ) else {
            return .needsReload
        }
        return .updated(updated)
    }
}
