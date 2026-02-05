//
//  ChatTableUpdatePlanner.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 选择全量 diff 或流式局部刷新
//
//

import Foundation

enum ChatTableUpdateAction: Equatable {
    case bindSections
    case streamingReloadLastMarkdownRow
}

enum ChatTableUpdatePlanner {
    static func plan(prev: ChatListState?, curr: ChatListState) -> ChatTableUpdateAction {
        guard let prev else { return .bindSections }
        if prev.conversationId != curr.conversationId { return .bindSections }
        if prev.isLoading != curr.isLoading { return .bindSections }
        if prev.stopNotices != curr.stopNotices { return .bindSections }
        if prev.messages.count != curr.messages.count { return .bindSections }
        guard curr.messages.count > 0 else { return .bindSections }

        let lastIndex = curr.messages.count - 1
        let prevLast = prev.messages[lastIndex]
        let currLast = curr.messages[lastIndex]
        if prevLast.id != currLast.id { return .bindSections }

        if currLast.isStreaming,
           prevLast.content.isEmpty,
           !currLast.content.isEmpty {
            return .bindSections
        }

        // 只要最后一条仍在 streaming（isStreaming=true）且只是 content 变化，就可以走 streaming-only reload。
        if currLast.isStreaming,
           prevLast.isStreaming == currLast.isStreaming,
           prevLast.wasStreamed == currLast.wasStreamed,
           prevLast.content != currLast.content {
            return .streamingReloadLastMarkdownRow
        }

        return .bindSections
    }
}
