//
//  ChatListStateBuilder.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 从快照生成列表状态与分区
//
//

import Foundation

protocol ChatListStateBuilding {
    func build(from snapshot: ChatListSnapshot) -> ChatListState
}

struct ChatListStateBuilder: ChatListStateBuilding {
    func build(from snapshot: ChatListSnapshot) -> ChatListState {
        let items = ChatRowBuilder.build(messages: snapshot.messages, isLoading: snapshot.isLoading)
        return ChatListState(
            messages: snapshot.messages,
            isLoading: snapshot.isLoading,
            conversationId: snapshot.conversationId,
            sections: [ChatSection(items: items)]
        )
    }
}

