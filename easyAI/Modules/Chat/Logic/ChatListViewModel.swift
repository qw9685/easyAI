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
    let stateRelay = BehaviorRelay<ChatListState>(
        value: ChatListState(messages: [], isLoading: false, conversationId: nil, sections: [ChatSection(items: [])])
    )
    private let snapshotRelay = BehaviorRelay<ChatListSnapshot>(value: .empty)
    private let stateBuilder: ChatListStateBuilding
    
    private var disposeBag = DisposeBag()
    private var cancellables: Set<AnyCancellable> = []
    private weak var boundContainer: ChatViewModel?
    private(set) var isUserAtBottom: Bool = true
    var autoScrollThreshold: CGFloat = 80
    var stateThrottleMilliseconds: Int = 80

    init(stateBuilder: ChatListStateBuilding = ChatListStateBuilder()) {
        self.stateBuilder = stateBuilder
    }
    
    func bind(container: ChatViewModel) {
        if boundContainer === container { return }
        boundContainer = container
        disposeBag = DisposeBag()
        cancellables.removeAll()
        
        container.$listSnapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.snapshotRelay.accept(snapshot)
            }
            .store(in: &cancellables)

        snapshotRelay
            .asObservable()
            .observe(on: MainScheduler.instance)
            .throttle(
                .milliseconds(stateThrottleMilliseconds),
                latest: true,
                scheduler: MainScheduler.instance
            )
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
        if lhs.messages.count != rhs.messages.count { return false }
        guard let left = lhs.messages.last, let right = rhs.messages.last else { return true }
        if left.id != right.id { return false }
        if left.content != right.content { return false }
        if left.isStreaming != right.isStreaming { return false }
        if left.wasStreamed != right.wasStreamed { return false }
        return true
    }

}
