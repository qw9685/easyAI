//
//  ChatTableViewController.swift
//  EasyAI
//
//  创建于 2026
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import RxDataSources

final class ChatTableViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var isUserAtBottom: Bool = true
    private var currentMessages: [Message] = []
    private var currentIsLoading: Bool = false
    private var lastConversationId: String?
    private var disposeBag = DisposeBag()
    private weak var boundViewModel: ChatListViewModel?
    private var needsFlushAfterUserScroll: Bool = false
    
    private lazy var dataSource = ChatTableDataSourceFactory.make()
    private var latestSections: [ChatSection] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }
    
    func bind(viewModel: ChatListViewModel) {
        if boundViewModel === viewModel { return }
        boundViewModel = viewModel
        disposeBag = DisposeBag()
        
        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)
        
        let state = Observable.combineLatest(
            viewModel.messagesRelay.asObservable(),
            viewModel.isLoadingRelay.asObservable(),
            viewModel.currentConversationIdRelay.asObservable()
        )
        .map { [weak viewModel] messages, isLoading, conversationId in
            viewModel?.buildState(
                messages: messages,
                isLoading: isLoading,
                conversationId: conversationId
            ) ?? ChatListState(
                messages: messages,
                isLoading: isLoading,
                conversationId: conversationId,
                sections: []
            )
        }
        .observe(on: MainScheduler.instance)
        .share(replay: 1)
        
        let statePairs = state
            .scan((prev: ChatListState?.none, curr: ChatListState?.none)) { acc, new in
                (prev: acc.curr, curr: new)
            }
            .compactMap { pair -> (prev: ChatListState?, curr: ChatListState)? in
                guard let curr = pair.curr else { return nil }
                return (prev: pair.prev, curr: curr)
            }
            .share(replay: 1)

        statePairs
            .filter { [weak self] pair in
                !(self?.isStreamOnlyLastMessageUpdate(prev: pair.prev, curr: pair.curr) ?? false)
            }
            .map { $0.curr.sections }
            .do(onNext: { [weak self] sections in
                self?.latestSections = sections
            })
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        statePairs
            .subscribe(onNext: { [weak self] pair in
                guard let self else { return }
                if self.isStreamOnlyLastMessageUpdate(prev: pair.prev, curr: pair.curr) {
                    self.applyStreamingState(pair.curr)
                } else {
                    self.applyState(pair.curr)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func applyState(_ state: ChatListState) {
        let conversationChanged = state.conversationId != lastConversationId
        currentMessages = state.messages
        currentIsLoading = state.isLoading
        lastConversationId = state.conversationId
        updateEmptyState()
        boundViewModel?.updateLastMessageCache(messages: state.messages)
        
        let shouldAutoScroll = boundViewModel?.shouldAutoScroll(
            currentOffset: tableView.contentOffset.y,
            viewHeight: tableView.bounds.height,
            contentHeight: tableView.contentSize.height
        ) ?? isUserAtBottom
        let shouldScroll = conversationChanged || shouldAutoScroll
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if shouldScroll {
                self.scrollToBottom(animated: false)
            }
            self.updateUserAtBottom()
        }
    }

    private func applyStreamingState(_ state: ChatListState) {
        currentMessages = state.messages
        currentIsLoading = state.isLoading
        lastConversationId = state.conversationId
        updateEmptyState()
        boundViewModel?.updateLastMessageCache(messages: state.messages)

        guard let lastMessage = state.messages.last else { return }
        latestSections = state.sections
        dataSource.setSections(state.sections)
        let shouldAutoScroll = boundViewModel?.shouldAutoScroll(
            currentOffset: tableView.contentOffset.y,
            viewHeight: tableView.bounds.height,
            contentHeight: tableView.contentSize.height
        ) ?? isUserAtBottom

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let row = state.messages.count - 1
            guard row >= 0 else { return }
            let indexPath = IndexPath(row: row, section: 0)

            if self.tableView.isTracking || self.tableView.isDragging || self.tableView.isDecelerating {
                self.needsFlushAfterUserScroll = true
                if let cell = self.tableView.cellForRow(at: indexPath) as? ChatMessageCell {
                    cell.configure(with: lastMessage)
                }
                return
            }

            UIView.performWithoutAnimation {
                self.tableView.reloadRows(at: [indexPath], with: .none)
                self.tableView.beginUpdates()
                self.tableView.endUpdates()
                self.tableView.layoutIfNeeded()
            }

            if shouldAutoScroll {
                self.scrollToBottomByOffset()
            }
            self.updateUserAtBottom()
        }
    }
    
    private func setupTableView() {
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.bounces = false
        tableView.keyboardDismissMode = .interactive
        tableView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 24, right: 0)
        tableView.scrollIndicatorInsets = UIEdgeInsets(top: 20, left: 0, bottom: 24, right: 0)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.register(ChatMessageCell.self, forCellReuseIdentifier: ChatMessageCell.reuseIdentifier)
        tableView.register(ChatLoadingCell.self, forCellReuseIdentifier: ChatLoadingCell.reuseIdentifier)
        
        tableView.backgroundView = ChatEmptyStateView()
        updateEmptyState()

    }
    
    private func updateEmptyState() {
        let shouldShow = boundViewModel?.shouldShowEmptyState(messages: currentMessages, isLoading: currentIsLoading)
            ?? (currentMessages.isEmpty && !currentIsLoading)
        tableView.backgroundView?.isHidden = !shouldShow
    }
    
    private func scrollToBottom(animated: Bool) {
        let totalRows = currentMessages.count + (currentIsLoading ? 1 : 0)
        guard totalRows > 0 else { return }
        let lastIndex = IndexPath(row: totalRows - 1, section: 0)
        tableView.scrollToRow(at: lastIndex, at: .bottom, animated: animated)
    }

    private func updateUserAtBottom() {
        let offset = tableView.contentOffset.y
        let height = tableView.bounds.height
        let contentHeight = tableView.contentSize.height
        boundViewModel?.updateUserAtBottom(
            currentOffset: offset,
            viewHeight: height,
            contentHeight: contentHeight
        )
        isUserAtBottom = boundViewModel?.isUserAtBottom ?? isUserAtBottom
    }
}

extension ChatTableViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let item = item(at: indexPath) else { return tableView.estimatedRowHeight }
        switch item {
        case .loading:
            return 35
        case .message:
            return tableView.estimatedRowHeight
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let height = scrollView.bounds.height
        let contentHeight = scrollView.contentSize.height
        boundViewModel?.updateUserAtBottom(
            currentOffset: offsetY,
            viewHeight: height,
            contentHeight: contentHeight
        )
        isUserAtBottom = boundViewModel?.isUserAtBottom ?? isUserAtBottom
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            flushPendingStreamingLayoutIfNeeded()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        flushPendingStreamingLayoutIfNeeded()
    }
}

private extension ChatTableViewController {
    func item(at indexPath: IndexPath) -> ChatRow? {
        guard indexPath.section < latestSections.count else { return nil }
        let section = latestSections[indexPath.section]
        guard indexPath.row < section.items.count else { return nil }
        return section.items[indexPath.row]
    }

    func isStreamOnlyLastMessageUpdate(prev: ChatListState?, curr: ChatListState) -> Bool {
        guard let prev else { return false }
        if prev.conversationId != curr.conversationId { return false }
        if prev.isLoading != curr.isLoading { return false }
        if prev.messages.count != curr.messages.count { return false }
        guard curr.messages.count > 0 else { return false }

        let lastIndex = curr.messages.count - 1
        if lastIndex > 0 {
            for idx in 0..<lastIndex {
                let a = prev.messages[idx]
                let b = curr.messages[idx]
                if a.id != b.id { return false }
                if a.content != b.content { return false }
                if a.isStreaming != b.isStreaming { return false }
                if a.wasStreamed != b.wasStreamed { return false }
            }
        }

        let prevLast = prev.messages[lastIndex]
        let currLast = curr.messages[lastIndex]
        if prevLast.id != currLast.id { return false }
        return prevLast.content != currLast.content
            || prevLast.isStreaming != currLast.isStreaming
            || prevLast.wasStreamed != currLast.wasStreamed
    }

    func scrollToBottomByOffset() {
        let insets = tableView.adjustedContentInset
        let contentHeight = tableView.contentSize.height
        let viewHeight = tableView.bounds.height
        let bottomY = max(-insets.top, contentHeight - viewHeight + insets.bottom)
        tableView.setContentOffset(CGPoint(x: 0, y: bottomY), animated: false)
    }

    func flushPendingStreamingLayoutIfNeeded() {
        guard needsFlushAfterUserScroll else { return }
        needsFlushAfterUserScroll = false

        let shouldAutoScroll = boundViewModel?.shouldAutoScroll(
            currentOffset: tableView.contentOffset.y,
            viewHeight: tableView.bounds.height,
            contentHeight: tableView.contentSize.height
        ) ?? isUserAtBottom

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            UIView.performWithoutAnimation {
                self.tableView.beginUpdates()
                self.tableView.endUpdates()
                self.tableView.layoutIfNeeded()
            }
            if shouldAutoScroll {
                self.scrollToBottomByOffset()
            }
            self.updateUserAtBottom()
        }
    }
}
