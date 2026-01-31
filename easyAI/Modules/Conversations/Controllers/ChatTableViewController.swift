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
    private var currentMessages: [Message] = []
    private var currentIsLoading: Bool = false
    private var lastConversationId: String?
    private var disposeBag = DisposeBag()
    private weak var boundViewModel: ChatListViewModel?
    private var streamingFlushWorkItem: DispatchWorkItem?
    private let autoScroll = ChatAutoScrollController()
    
    private lazy var dataSource = ChatTableDataSourceFactory.make()
    private var latestSections: [ChatSection] = []
    private let sectionsRelay = BehaviorRelay<[ChatSection]>(value: [])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }

    /// 键盘/输入栏导致布局变化时，如果当前处于“黏底”状态，则保持滚动在最底部。
    /// 由外层（ChatViewController）在键盘动画 block 内/结束后调用。
    func keepBottomPinnedForLayoutChange(animated: Bool) {
        let userIsInteracting = tableView.isTracking || tableView.isDragging || tableView.isDecelerating
        guard !userIsInteracting, autoScroll.shouldAutoScrollForStreaming() else { return }

        if animated {
            layoutAndScrollToBottom(animated: true)
        } else {
            scrollToBottomAfterLayout()
        }
    }
    
    func bind(viewModel: ChatListViewModel) {
        if boundViewModel === viewModel { return }
        boundViewModel = viewModel
        disposeBag = DisposeBag()
        
        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)

        let state = viewModel.stateRelay
            .asObservable()
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

        // 1) 用 RxDataSources 负责 sections 的 diff 更新（避免 reloadData）
        sectionsRelay
            .asObservable()
            .do(onNext: { [weak self] sections in
                self?.latestSections = sections
            })
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        // 2) planner 决定每次 state 应该走 diff（sectionsRelay.accept）还是 streaming-only 局部刷新
        statePairs
            .subscribe(onNext: { [weak self] pair in
                guard let self else { return }
                switch ChatTableUpdatePlanner.plan(prev: pair.prev, curr: pair.curr) {
                case .bindSections:
                    self.applyState(pair.curr)
                case .streamingReloadLastMarkdownRow:
                    self.applyStreamingState(pair.curr)
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
        if conversationChanged {
            latestSections = state.sections
            dataSource.setSections(state.sections)
            UIView.performWithoutAnimation {
                tableView.reloadData()
                tableView.layoutIfNeeded()
            }
            autoScroll.recordPinnedContentHeight(tableView.contentSize.height)
        } else {
            sectionsRelay.accept(state.sections)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let userIsInteracting = self.tableView.isTracking || self.tableView.isDragging || self.tableView.isDecelerating
            let messageCountIncreased = state.messages.count > previousCount
            let forceScroll = conversationChanged || (messageCountIncreased && state.messages.last?.role == .user)

            if conversationChanged {
                self.autoScroll.onConversationChanged()
            }
            if forceScroll {
                self.autoScroll.onForceScrollRequested()
            }

            if self.autoScroll.shouldAutoScrollAfterStateApply(
                userIsInteracting: userIsInteracting,
                forceScroll: forceScroll,
                isNearBottom: self.isNearBottom()
            ) {
                self.scrollToBottomAfterLayout()
            }
        }
    }

    private func applyStreamingState(_ state: ChatListState) {
        currentMessages = state.messages
        currentIsLoading = state.isLoading
        lastConversationId = state.conversationId
        updateEmptyState()

        guard let lastMessage = state.messages.last else { return }
        latestSections = state.sections
        // 只更新 dataSource 内部 sections，保证后续 cellForRow/identity 与 reloadRows 对齐
        dataSource.setSections(state.sections)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let indexPath = self.indexPathForLastMarkdownRow(in: state.sections) else { return }

            if self.tableView.isTracking || self.tableView.isDragging || self.tableView.isDecelerating {
                self.autoScroll.markNeedsFlushAfterUserScroll()
                if let cell = self.tableView.cellForRow(at: indexPath) as? ChatMessageMarkdownCell {
                    let maxBubbleWidth = max(0, self.tableView.bounds.width - 32)
                    cell.applyStreamingText(lastMessage.content, maxBubbleWidth: maxBubbleWidth)
                }
                return
            }
            self.scheduleStreamingFlush(indexPath: indexPath, shouldAutoScroll: self.autoScroll.shouldAutoScrollForStreaming())
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

        autoScroll.recordPinnedContentHeight(tableView.contentSize.height)
    }
    
    private func updateEmptyState() {
        let shouldShow = boundViewModel?.shouldShowEmptyState(messages: currentMessages, isLoading: currentIsLoading)
            ?? (currentMessages.isEmpty && !currentIsLoading)
        tableView.backgroundView?.isHidden = !shouldShow
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
            return 170
        case .messageMarkdown(let message) where message.isStreaming && message.content.isEmpty:
            return 0
        case .messageMarkdown:
            return tableView.estimatedRowHeight
        case .messageSend:
            return tableView.estimatedRowHeight
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let userIsInteracting = tableView.isTracking || tableView.isDragging || tableView.isDecelerating
        if userIsInteracting {
            autoScroll.onUserScroll(isNearBottom: isNearBottom())
        }
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

    func scrollToBottomByOffset() {
        let insets = tableView.adjustedContentInset
        let contentHeight = tableView.contentSize.height
        let viewHeight = tableView.bounds.height
        let bottomY = max(-insets.top, contentHeight - viewHeight + insets.bottom)
        tableView.setContentOffset(CGPoint(x: 0, y: bottomY), animated: false)
    }

    func layoutAndScrollToBottom(animated: Bool) {
        tableView.layoutIfNeeded()

        let insets = tableView.adjustedContentInset
        let contentHeight = tableView.contentSize.height
        let viewHeight = tableView.bounds.height
        let bottomY = max(-insets.top, contentHeight - viewHeight + insets.bottom)

        if animated {
            tableView.contentOffset = CGPoint(x: 0, y: bottomY)
        } else {
            tableView.setContentOffset(CGPoint(x: 0, y: bottomY), animated: false)
        }
        autoScroll.recordPinnedContentHeight(tableView.contentSize.height)
    }

    func scrollToBottomAfterLayout(maxPasses: Int = 2) {
        guard maxPasses > 0 else { return }
        let beforeHeight = tableView.contentSize.height

        UIView.performWithoutAnimation {
            tableView.layoutIfNeeded()
        }
        scrollToBottomByOffset()
        autoScroll.recordPinnedContentHeight(tableView.contentSize.height)

        let afterHeight = tableView.contentSize.height
        if afterHeight != beforeHeight {
            DispatchQueue.main.async { [weak self] in
                self?.scrollToBottomAfterLayout(maxPasses: maxPasses - 1)
            }
        }
    }

    func flushPendingStreamingLayoutIfNeeded() {
        guard autoScroll.consumeNeedsFlushAfterUserScroll() else { return }
        let shouldAutoScroll = autoScroll.shouldAutoScrollForStreaming()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            UIView.performWithoutAnimation {
                self.tableView.beginUpdates()
                self.tableView.endUpdates()
                self.tableView.layoutIfNeeded()
            }
            if shouldAutoScroll {
                self.scrollToBottomByOffset()
                self.autoScroll.recordPinnedContentHeight(self.tableView.contentSize.height)
            }
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
        guard let message = currentMessages.last, message.isStreaming else { return }
        if tableView.isTracking || tableView.isDragging || tableView.isDecelerating {
            autoScroll.markNeedsFlushAfterUserScroll()
            return
        }

        let beforeHeight = tableView.contentSize.height

        UIView.performWithoutAnimation {
            if let cell = tableView.cellForRow(at: indexPath) as? ChatMessageMarkdownCell {
                let maxBubbleWidth = max(0, tableView.bounds.width - 32)
                cell.applyStreamingText(message.content, maxBubbleWidth: maxBubbleWidth)
                cell.contentView.layoutIfNeeded()
            } else {
                tableView.reloadRows(at: [indexPath], with: .none)
            }
            tableView.beginUpdates()
            tableView.endUpdates()
            tableView.layoutIfNeeded()
        }

        if shouldAutoScroll {
            let afterHeight = tableView.contentSize.height
            let delta = autoScroll.computePinnedDelta(beforeHeight: beforeHeight, afterHeight: afterHeight)
            if abs(delta) > 0.5 {
                tableView.contentOffset.y += delta
            }
            scrollToBottomByOffset()
            autoScroll.recordPinnedContentHeight(tableView.contentSize.height)
        }
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

    func isNearBottom() -> Bool {
        boundViewModel?.isNearBottom(
            currentOffset: tableView.contentOffset.y,
            viewHeight: tableView.bounds.height,
            contentHeight: tableView.contentSize.height
        ) ?? true
    }
}
