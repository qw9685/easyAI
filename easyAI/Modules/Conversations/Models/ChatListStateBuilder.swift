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
        let items = ChatRenderPolicyKit.buildRows(
            messages: snapshot.messages,
            isLoading: snapshot.isLoading,
            stopNotices: snapshot.stopNotices
        )
        return ChatListState(
            messages: snapshot.messages,
            isLoading: snapshot.isLoading,
            conversationId: snapshot.conversationId,
            stopNotices: snapshot.stopNotices,
            sections: [ChatSection(items: items)]
        )
    }
}
