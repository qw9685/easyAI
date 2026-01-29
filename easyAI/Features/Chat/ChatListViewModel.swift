//
//  ChatListViewModel.swift
//  EasyAI
//
//  创建于 2026
//

import Foundation
import Combine
import RxSwift
import RxCocoa

final class ChatListViewModel: ObservableObject {
    let messagesRelay = BehaviorRelay<[Message]>(value: [])
    let isLoadingRelay = BehaviorRelay<Bool>(value: false)
    let currentConversationIdRelay = BehaviorRelay<String?>(value: nil)
    
    private var disposeBag = DisposeBag()
    private weak var boundContainer: ChatViewModel?
    private var lastMessageId: UUID?
    private var lastMessageContent: String?
    private var lastMessageIsStreaming: Bool?
    private var lastMessageWasStreamed: Bool?
    private(set) var isUserAtBottom: Bool = true
    var autoScrollThreshold: CGFloat = 80
    var messagesThrottleMilliseconds: Int = 80
    
    func bind(container: ChatViewModel) {
        if boundContainer === container { return }
        boundContainer = container
        disposeBag = DisposeBag()
        
        container.messagesRelay
            .observe(on: MainScheduler.instance)
            .throttle(
                .milliseconds(messagesThrottleMilliseconds),
                latest: true,
                scheduler: MainScheduler.instance
            )
            .distinctUntilChanged { [weak self] lhs, rhs in
                self?.isMessageSnapshotEqual(lhs, rhs) ?? false
            }
            .bind(to: messagesRelay)
            .disposed(by: disposeBag)
        
        container.isLoadingRelay
            .observe(on: MainScheduler.instance)
            .distinctUntilChanged()
            .bind(to: isLoadingRelay)
            .disposed(by: disposeBag)
        
        container.currentConversationIdRelay
            .observe(on: MainScheduler.instance)
            .distinctUntilChanged()
            .bind(to: currentConversationIdRelay)
            .disposed(by: disposeBag)
    }
    
    func shouldReloadLastMessage(messages: [Message]) -> Bool {
        guard let lastMessage = messages.last else { return false }
        guard lastMessageId == lastMessage.id else { return true }
        if lastMessageContent != lastMessage.content { return true }
        if lastMessageIsStreaming != lastMessage.isStreaming { return true }
        if lastMessageWasStreamed != lastMessage.wasStreamed { return true }
        return false
    }
    
    func updateLastMessageCache(messages: [Message]) {
        lastMessageId = messages.last?.id
        lastMessageContent = messages.last?.content
        lastMessageIsStreaming = messages.last?.isStreaming
        lastMessageWasStreamed = messages.last?.wasStreamed
    }
    
    func shouldShowEmptyState(messages: [Message], isLoading: Bool) -> Bool {
        messages.isEmpty && !isLoading
    }
    
    func shouldAutoScroll(currentOffset: CGFloat, viewHeight: CGFloat, contentHeight: CGFloat) -> Bool {
        isUserAtBottom || isNearBottom(currentOffset: currentOffset, viewHeight: viewHeight, contentHeight: contentHeight)
    }
    
    func updateUserAtBottom(currentOffset: CGFloat, viewHeight: CGFloat, contentHeight: CGFloat) {
        isUserAtBottom = isNearBottom(currentOffset: currentOffset, viewHeight: viewHeight, contentHeight: contentHeight)
    }
    
    func isNearBottom(currentOffset: CGFloat, viewHeight: CGFloat, contentHeight: CGFloat) -> Bool {
        if contentHeight <= viewHeight { return true }
        let distanceToBottom = contentHeight - (currentOffset + viewHeight)
        return distanceToBottom <= autoScrollThreshold
    }

    func buildState(
        messages: [Message],
        isLoading: Bool,
        conversationId: String?
    ) -> ChatListState {
        var items: [ChatRow] = []
        items.reserveCapacity(messages.count * 2)
        for message in messages {
            if !message.mediaContents.isEmpty {
                items.append(.messageMedia(messageId: message.id, role: message.role, mediaContents: message.mediaContents))
            }
            if message.role == .user {
                items.append(.messageSend(messageId: message.id, text: message.content, timestamp: message.timestamp))
            } else if !message.content.isEmpty || message.isStreaming {
                items.append(.messageMarkdown(message))
            }
        }
        if isLoading {
            items.append(.loading)
        }
        return ChatListState(
            messages: messages,
            isLoading: isLoading,
            conversationId: conversationId,
            sections: [ChatSection(items: items)]
        )
    }
    
    private func isMessageSnapshotEqual(_ lhs: [Message], _ rhs: [Message]) -> Bool {
        if lhs.count != rhs.count { return false }
        guard let left = lhs.last, let right = rhs.last else { return true }
        if left.id != right.id { return false }
        if left.content != right.content { return false }
        if left.isStreaming != right.isStreaming { return false }
        if left.wasStreamed != right.wasStreamed { return false }
        return true
    }

}
