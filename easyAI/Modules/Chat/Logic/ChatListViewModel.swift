//
//  ChatListViewModel.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 将快照转为列表状态并节流
//  - 提供空态与滚动判断
//
//

import Foundation
import RxSwift
import RxCocoa

final class ChatListViewModel {
    let stateRelay = BehaviorRelay<ChatListState>(
        value: ChatListState(messages: [], isLoading: false, conversationId: nil, stopNotices: [], sections: [ChatSection(items: [])])
    )
    private let snapshotRelay = BehaviorRelay<ChatListSnapshot>(value: .empty)
    private let stateBuilder: ChatListStateBuilding
    
    private var disposeBag = DisposeBag()
    private weak var boundContainer: ChatViewModel?
    private var lastConversationId: String?
    private(set) var isUserAtBottom: Bool = true
    var autoScrollThreshold: CGFloat = 80

    init(stateBuilder: ChatListStateBuilding = ChatListStateBuilder()) {
        self.stateBuilder = stateBuilder
    }
    
    func bind(container: ChatViewModel) {
        if boundContainer === container { return }
        boundContainer = container
        disposeBag = DisposeBag()
        
        container.listSnapshotObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] snapshot in
                guard let self else { return }
                if self.lastConversationId != snapshot.conversationId {
                    self.lastConversationId = snapshot.conversationId
                    // 会话切换：同步下发到 stateRelay，避免 Rx 节流/调度导致 dismiss 时短暂露出旧列表
                    self.stateRelay.accept(self.stateBuilder.build(from: snapshot))
                    return
                }
                self.snapshotRelay.accept(snapshot)
            })
            .disposed(by: disposeBag)

        snapshotRelay
            .asObservable()
            .observe(on: MainScheduler.instance)
            .scan((prev: ChatListSnapshot?.none, curr: ChatListSnapshot?.none)) { acc, new in
                (prev: acc.curr, curr: new)
            }
            .compactMap { pair -> ChatListSnapshot? in
                pair.curr
            }
            .distinctUntilChanged { [weak self] lhs, rhs in
                self?.isSnapshotEqual(lhs, rhs) ?? false
            }
            .map { [stateBuilder] snapshot in
                stateBuilder.build(from: snapshot)
            }
            .bind(to: stateRelay)
            .disposed(by: disposeBag)
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

    private func isSnapshotEqual(_ lhs: ChatListSnapshot, _ rhs: ChatListSnapshot) -> Bool {
        if lhs.conversationId != rhs.conversationId { return false }
        if lhs.isLoading != rhs.isLoading { return false }
        if lhs.stopNotices != rhs.stopNotices { return false }
        if lhs.messages.count != rhs.messages.count { return false }
        guard let left = lhs.messages.last, let right = rhs.messages.last else { return true }
        if left.id != right.id { return false }
        if left.content != right.content { return false }
        if left.isStreaming != right.isStreaming { return false }
        if left.wasStreamed != right.wasStreamed { return false }
        return true
    }

}
