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
    private enum ScrollMode {
        case pinnedToBottom
        case reading
    }
    
    private var scrollMode: ScrollMode = .pinnedToBottom
    private var currentMessages: [Message] = []
    private var currentIsLoading: Bool = false
    private var lastConversationId: String?
    private var disposeBag = DisposeBag()
    private weak var boundViewModel: ChatListViewModel?
    private var needsFlushAfterUserScroll: Bool = false
    private var pendingNewMessageCount: Int = 0
    private let newMessagesButton = UIButton(type: .system)
    private var streamingFlushWorkItem: DispatchWorkItem?
    private var lastPinnedContentHeight: CGFloat = 0
    
    private lazy var dataSource = ChatTableDataSourceFactory.make()
    private var latestSections: [ChatSection] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupNewMessagesButton()
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
        streamingFlushWorkItem?.cancel()
        let conversationChanged = state.conversationId != lastConversationId
        let previousCount = currentMessages.count
        currentMessages = state.messages
        currentIsLoading = state.isLoading
        lastConversationId = state.conversationId
        updateEmptyState()
        boundViewModel?.updateLastMessageCache(messages: state.messages)
        
        let shouldScroll = conversationChanged || (scrollMode == .pinnedToBottom)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !shouldScroll && state.messages.count > previousCount {
                self.pendingNewMessageCount += (state.messages.count - previousCount)
                self.showNewMessagesButtonIfNeeded()
            } else if shouldScroll {
                self.hideNewMessagesButton()
            }
            
            if shouldScroll {
                self.scrollToBottomByOffset()
            }
            self.updateScrollModeFromCurrentPosition()
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
        let shouldAutoScroll = (scrollMode == .pinnedToBottom)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let indexPath = self.indexPathForLastMarkdownRow(in: state.sections) else { return }

            if self.tableView.isTracking || self.tableView.isDragging || self.tableView.isDecelerating {
                self.needsFlushAfterUserScroll = true
                if let cell = self.tableView.cellForRow(at: indexPath) as? ChatMessageMarkdownCell {
                    cell.configure(with: lastMessage)
                }
                self.pendingNewMessageCount += 1
                self.showNewMessagesButtonIfNeeded()
                return
            }
            self.scheduleStreamingFlush(indexPath: indexPath, shouldAutoScroll: shouldAutoScroll)
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
        tableView.register(ChatMessageMarkdownCell.self, forCellReuseIdentifier: ChatMessageMarkdownCell.reuseIdentifier)
        tableView.register(ChatMessageSendCell.self, forCellReuseIdentifier: ChatMessageSendCell.reuseIdentifier)
        tableView.register(ChatMessageMediaCell.self, forCellReuseIdentifier: ChatMessageMediaCell.reuseIdentifier)
        tableView.register(ChatLoadingCell.self, forCellReuseIdentifier: ChatLoadingCell.reuseIdentifier)
        
        tableView.backgroundView = ChatEmptyStateView()
        updateEmptyState()

        lastPinnedContentHeight = tableView.contentSize.height
    }

    private func setupNewMessagesButton() {
        newMessagesButton.isHidden = true
        newMessagesButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.95)
        newMessagesButton.setTitleColor(.white, for: .normal)
        newMessagesButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
        newMessagesButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        newMessagesButton.layer.cornerRadius = 16
        newMessagesButton.layer.masksToBounds = true
        newMessagesButton.addTarget(self, action: #selector(didTapNewMessagesButton), for: .touchUpInside)
        
        view.addSubview(newMessagesButton)
        newMessagesButton.snp.makeConstraints { make in
            make.trailing.equalTo(view.safeAreaLayoutGuide.snp.trailing).inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).inset(12)
        }
    }
    
    @objc private func didTapNewMessagesButton() {
        scrollMode = .pinnedToBottom
        hideNewMessagesButton()
        flushPendingStreamingLayoutIfNeeded()
        scrollToBottomByOffset()
        updateScrollModeFromCurrentPosition()
    }
    
    private func updateEmptyState() {
        let shouldShow = boundViewModel?.shouldShowEmptyState(messages: currentMessages, isLoading: currentIsLoading)
            ?? (currentMessages.isEmpty && !currentIsLoading)
        tableView.backgroundView?.isHidden = !shouldShow
    }
    
    private func updateScrollModeFromCurrentPosition() {
        let offset = tableView.contentOffset.y
        let height = tableView.bounds.height
        let contentHeight = tableView.contentSize.height
        let nearBottom = boundViewModel?.isNearBottom(
            currentOffset: offset,
            viewHeight: height,
            contentHeight: contentHeight
        ) ?? true
        
        if nearBottom {
            scrollMode = .pinnedToBottom
            hideNewMessagesButton()
        } else if tableView.isDragging || tableView.isDecelerating || tableView.isTracking {
            scrollMode = .reading
        }
    }
}

extension ChatTableViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let item = item(at: indexPath) else { return 0 }
        switch item {
        case .messageMarkdown(let message) where message.isStreaming && message.content.isEmpty:
            return CGFloat.leastNonzeroMagnitude
        default:
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let item = item(at: indexPath) else { return tableView.estimatedRowHeight }
        switch item {
        case .loading:
            return 35
        case .messageMedia:
            return 220
        case .messageMarkdown(let message) where message.isStreaming && message.content.isEmpty:
            return 0
        case .messageMarkdown:
            return tableView.estimatedRowHeight
        case .messageSend:
            return tableView.estimatedRowHeight
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateScrollModeFromCurrentPosition()
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollMode = .reading
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            flushPendingStreamingLayoutIfNeeded()
            updateScrollModeFromCurrentPosition()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        flushPendingStreamingLayoutIfNeeded()
        updateScrollModeFromCurrentPosition()
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

        let shouldAutoScroll = (scrollMode == .pinnedToBottom)

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
            self.updateScrollModeFromCurrentPosition()
        }
    }

    func scheduleStreamingFlush(indexPath: IndexPath, shouldAutoScroll: Bool) {
        streamingFlushWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performStreamingFlush(indexPath: indexPath, shouldAutoScroll: shouldAutoScroll)
        }
        streamingFlushWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: workItem)
    }

    func performStreamingFlush(indexPath: IndexPath, shouldAutoScroll: Bool) {
        if tableView.isTracking || tableView.isDragging || tableView.isDecelerating {
            needsFlushAfterUserScroll = true
            return
        }

        let wasPinned = (scrollMode == .pinnedToBottom)
        let beforeHeight = tableView.contentSize.height

        UIView.performWithoutAnimation {
            tableView.reloadRows(at: [indexPath], with: .none)
            tableView.beginUpdates()
            tableView.endUpdates()
            tableView.layoutIfNeeded()
        }

        if shouldAutoScroll && wasPinned {
            let afterHeight = tableView.contentSize.height
            let delta = afterHeight - max(lastPinnedContentHeight, beforeHeight)
            if abs(delta) > 0.5 {
                tableView.contentOffset.y += delta
            }
            scrollToBottomByOffset()
            lastPinnedContentHeight = tableView.contentSize.height
            hideNewMessagesButton()
        } else {
            pendingNewMessageCount += 1
            showNewMessagesButtonIfNeeded()
        }
        updateScrollModeFromCurrentPosition()
    }

    func indexPathForLastMarkdownRow(in sections: [ChatSection]) -> IndexPath? {
        guard let first = sections.first else { return nil }
        for (idx, item) in first.items.enumerated().reversed() {
            if case .messageMarkdown = item {
                return IndexPath(row: idx, section: 0)
            }
        }
        return nil
    }

    func showNewMessagesButtonIfNeeded() {
        guard scrollMode == .reading, pendingNewMessageCount > 0 else { return }
        let title = pendingNewMessageCount > 99 ? "99+ 新消息" : "\(pendingNewMessageCount) 新消息"
        newMessagesButton.setTitle(title, for: .normal)
        newMessagesButton.isHidden = false
    }
    
    func hideNewMessagesButton() {
        pendingNewMessageCount = 0
        newMessagesButton.isHidden = true
    }
}
