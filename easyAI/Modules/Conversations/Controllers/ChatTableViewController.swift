//
//  ChatTableViewController.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 聊天列表渲染与 diff 更新
//  - 处理流式局部刷新与自动滚动
//
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
    var onDeleteMessage: ((Message) -> Void)?
    var onSelectText: ((Message) -> Void)?
    var onWillBeginDragging: (() -> Void)?
    private var streamingDisplayLink: CADisplayLink?
    private var pendingStreamingIndexPath: IndexPath?
    private var lastStreamingFlushTime: CFTimeInterval = 0
    private var lastStreamingRefreshRate: Double = 0
    private var lastFlushedStreamingSignature: (id: UUID, length: Int, hash: Int)?
    private var streamingFlushSampleCount: Int = 0
    private let autoScroll = ChatAutoScrollController()
    private var isScrollToBottomButtonVisible = false
    private var scrollToBottomButtonAnimator: UIViewPropertyAnimator?

    private lazy var scrollToBottomButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        button.alpha = 0
        button.isHidden = true
        button.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        button.addTarget(self, action: #selector(handleScrollToBottomTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var dataSource = ChatTableDataSourceFactory.make()
    private var latestSections: [ChatSection] = []
    private let sectionsRelay = BehaviorRelay<[ChatSection]>(value: [])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopStreamingDisplayLink()
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
            .subscribe(onNext: { [weak self] (pair: (prev: ChatListState?, curr: ChatListState)) in
                guard let self else { return }
                switch ChatRenderPolicyKit.planTableUpdate(prev: pair.prev, curr: pair.curr) {
                case .bindSections:
                    self.applyState(pair.curr)
                case .streamingReloadLastMarkdownRow:
                    self.applyStreamingState(pair.curr)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func applyState(_ state: ChatListState) {
        pendingStreamingIndexPath = nil
        lastFlushedStreamingSignature = nil
        let conversationChanged = state.conversationId != lastConversationId
        let loadingChanged = state.isLoading != currentIsLoading
        let previousCount = currentMessages.count
        currentMessages = state.messages
        currentIsLoading = state.isLoading
        lastConversationId = state.conversationId
        updateEmptyState()
        updateStreamingDisplayLinkIfNeeded()
        if conversationChanged {
            latestSections = state.sections
            dataSource.setSections(state.sections)
            UIView.performWithoutAnimation {
                tableView.reloadData()
                tableView.layoutIfNeeded()
            }
            autoScroll.recordPinnedContentHeight(tableView.contentSize.height)
        } else if loadingChanged {
            latestSections = state.sections
            dataSource.setSections(state.sections)
            UIView.performWithoutAnimation {
                tableView.reloadData()
                tableView.layoutIfNeeded()
            }
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

            let nearBottom = self.isNearBottom()
            if self.autoScroll.shouldAutoScrollAfterStateApply(
                userIsInteracting: userIsInteracting,
                forceScroll: forceScroll,
                isNearBottom: nearBottom
            ) {
                self.scrollToBottomAfterLayout()
            }
            self.updateScrollToBottomButtonVisibility(isNearBottom: self.isNearBottom())
        }
    }

    private func applyStreamingState(_ state: ChatListState) {
        guard state.isLoading, state.messages.last?.isStreaming == true else {
            applyState(state)
            return
        }
        currentMessages = state.messages
        currentIsLoading = state.isLoading
        lastConversationId = state.conversationId
        updateEmptyState()
        updateStreamingDisplayLinkIfNeeded()

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
                    cell.applyStreamingText(lastMessage.content)
                }
                self.updateScrollToBottomButtonVisibility(isNearBottom: self.isNearBottom())
                return
            }
            self.scheduleStreamingFlush(indexPath: indexPath)
            self.updateScrollToBottomButtonVisibility(isNearBottom: self.isNearBottom())
        }
    }
    
    private func setupTableView() {
        view.addSubview(tableView)
        view.addSubview(scrollToBottomButton)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scrollToBottomButton.snp.makeConstraints { make in
            make.size.equalTo(CGSize(width: 36, height: 36))
            make.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(12)
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
        tableView.register(ChatStopNoticeCell.self, forCellReuseIdentifier: ChatStopNoticeCell.reuseIdentifier)
        
        tableView.backgroundView = ChatEmptyStateView()
        updateEmptyState()
        applyScrollToBottomButtonTheme()
        updateScrollToBottomButtonVisibility(isNearBottom: true, animated: false)

        autoScroll.recordPinnedContentHeight(tableView.contentSize.height)
    }

    func applyTheme() {
        let previousOffset = tableView.contentOffset
        tableView.backgroundView = ChatEmptyStateView()
        applyScrollToBottomButtonTheme()
        UIView.performWithoutAnimation {
            tableView.reloadData()
            tableView.layoutIfNeeded()
            tableView.setContentOffset(previousOffset, animated: false)
        }
    }

    private func applyScrollToBottomButtonTheme() {
        scrollToBottomButton.backgroundColor = AppTheme.surface
        scrollToBottomButton.tintColor = AppTheme.textPrimary
        scrollToBottomButton.layer.cornerRadius = 18
        scrollToBottomButton.layer.masksToBounds = false
        scrollToBottomButton.layer.borderWidth = AppTheme.borderWidth
        scrollToBottomButton.layer.borderColor = AppTheme.border.cgColor
        scrollToBottomButton.layer.shadowColor = AppTheme.shadow.cgColor
        scrollToBottomButton.layer.shadowOpacity = 0.16
        scrollToBottomButton.layer.shadowRadius = 10
        scrollToBottomButton.layer.shadowOffset = CGSize(width: 0, height: 4)
    }

    @objc private func handleScrollToBottomTapped() {
        autoScroll.onForceScrollRequested()
        scrollToBottomWithAnimation()
    }

    func updateScrollToBottomButtonVisibility(isNearBottom: Bool? = nil, animated: Bool = true) {
        let nearBottom = isNearBottom ?? self.isNearBottom()
        let shouldShow = !nearBottom && !currentMessages.isEmpty
        setScrollToBottomButtonVisible(shouldShow, animated: animated)
    }

    private func setScrollToBottomButtonVisible(_ visible: Bool, animated: Bool) {
        guard visible != isScrollToBottomButtonVisible else { return }
        isScrollToBottomButtonVisible = visible

        scrollToBottomButtonAnimator?.stopAnimation(true)

        if visible {
            scrollToBottomButton.isHidden = false
        }

        let animations = {
            self.scrollToBottomButton.alpha = visible ? 1 : 0
            self.scrollToBottomButton.transform = visible ? .identity : CGAffineTransform(scaleX: 0.92, y: 0.92)
        }

        let completion: (UIViewAnimatingPosition) -> Void = { _ in
            if !visible {
                self.scrollToBottomButton.isHidden = true
            }
        }

        guard animated else {
            animations()
            completion(.end)
            return
        }

        let animator = UIViewPropertyAnimator(duration: 0.2, dampingRatio: 0.95, animations: animations)
        animator.addCompletion(completion)
        scrollToBottomButtonAnimator = animator
        animator.startAnimation()
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
        case .messageMarkdown(let message, let statusText)
            where message.isStreaming && message.content.isEmpty && (statusText == nil || statusText?.isEmpty == true):
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
        case .messageMarkdown(let message, let statusText)
            where message.isStreaming && message.content.isEmpty && (statusText == nil || statusText?.isEmpty == true):
            return 0
        case .messageMarkdown(_, _):
            return tableView.estimatedRowHeight
        case .messageSend:
            return tableView.estimatedRowHeight
        case .stopNotice:
            return tableView.estimatedRowHeight
        }
    }

    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let row = item(at: indexPath) else { return nil }

        let message: Message
        switch row {
        case .messageMarkdown(let value, _):
            message = value
        case .messageSend(let value):
            message = value
        case .messageMedia(let value):
            message = value
        case .loading, .stopNotice:
            return nil
        }

        if message.isStreaming {
            return nil
        }

        let hasText = !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !hasText && message.role == .user {
            return nil
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else { return nil }
            let copyAction = UIAction(
                title: "复制",
                image: UIImage(systemName: "doc.on.doc"),
                attributes: hasText ? [] : [.disabled]
            ) { _ in
                UIPasteboard.general.string = message.content
            }
            let selectAction = UIAction(
                title: "选取文字",
                image: UIImage(systemName: "text.cursor"),
                attributes: hasText ? [] : [.disabled]
            ) { [weak self] _ in
                self?.onSelectText?(message)
            }

            var actions: [UIMenuElement] = [copyAction, selectAction]
            if message.role != .user {
                let deleteAction = UIAction(
                    title: "删除",
                    image: UIImage(systemName: "trash"),
                    attributes: [.destructive]
                ) { [weak self] _ in
                    self?.onDeleteMessage?(message)
                }
                actions.append(deleteAction)
            }

            return UIMenu(title: "", children: actions)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let nearBottom = isNearBottom()
        let userIsInteracting = tableView.isTracking || tableView.isDragging || tableView.isDecelerating
        if userIsInteracting {
            autoScroll.onUserScroll(isNearBottom: nearBottom)
        }
        updateScrollToBottomButtonVisibility(isNearBottom: nearBottom)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        onWillBeginDragging?()
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

    func isValidIndexPath(_ indexPath: IndexPath) -> Bool {
        guard indexPath.section < latestSections.count else { return false }
        return indexPath.row < latestSections[indexPath.section].items.count
    }

    func messageForRow(at indexPath: IndexPath) -> Message? {
        guard let row = item(at: indexPath) else { return nil }
        switch row {
        case .messageMarkdown(let message, _):
            return message
        case .messageSend(let message):
            return message
        case .messageMedia(let message):
            return message
        case .loading, .stopNotice:
            return nil
        }
    }

    func scrollToBottomByOffset(animated: Bool = false) {
        let insets = tableView.adjustedContentInset
        let contentHeight = tableView.contentSize.height
        let viewHeight = tableView.bounds.height
        let bottomY = max(-insets.top, contentHeight - viewHeight + insets.bottom)
        tableView.setContentOffset(CGPoint(x: 0, y: bottomY), animated: animated)
        updateScrollToBottomButtonVisibility(isNearBottom: true)
    }

    func layoutAndScrollToBottom(animated: Bool) {
        tableView.layoutIfNeeded()

        let insets = tableView.adjustedContentInset
        let contentHeight = tableView.contentSize.height
        let viewHeight = tableView.bounds.height
        let bottomY = max(-insets.top, contentHeight - viewHeight + insets.bottom)

        tableView.setContentOffset(CGPoint(x: 0, y: bottomY), animated: animated)
        autoScroll.recordPinnedContentHeight(tableView.contentSize.height)
    }

    func scrollToBottomAfterLayout(maxPasses: Int = 2) {
        guard maxPasses > 0 else { return }
        let beforeHeight = tableView.contentSize.height

        UIView.performWithoutAnimation {
            tableView.layoutIfNeeded()
        }
        scrollToBottomByOffset(animated: false)
        autoScroll.recordPinnedContentHeight(tableView.contentSize.height)

        let afterHeight = tableView.contentSize.height
        if afterHeight != beforeHeight {
            DispatchQueue.main.async { [weak self] in
                self?.scrollToBottomAfterLayout(maxPasses: maxPasses - 1)
            }
        }
    }

    func scrollToBottomWithAnimation() {
        UIView.performWithoutAnimation {
            tableView.layoutIfNeeded()
        }
        scrollToBottomByOffset(animated: true)
        autoScroll.recordPinnedContentHeight(tableView.contentSize.height)
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

    func scheduleStreamingFlush(indexPath: IndexPath) {
        pendingStreamingIndexPath = indexPath
        startStreamingDisplayLinkIfNeeded()
    }

    func performStreamingFlush(indexPath: IndexPath, shouldAutoScroll: Bool) {
        guard currentIsLoading, let message = currentMessages.last, message.isStreaming else { return }
        if tableView.isTracking || tableView.isDragging || tableView.isDecelerating {
            autoScroll.markNeedsFlushAfterUserScroll()
            return
        }
        guard isValidIndexPath(indexPath) else { return }

        let signature = (id: message.id, length: message.content.count, hash: message.content.hashValue)
        if let last = lastFlushedStreamingSignature,
           last.id == signature.id,
           last.length == signature.length,
           last.hash == signature.hash {
            return
        }
        lastFlushedStreamingSignature = signature

        let beforeHeight = tableView.contentSize.height
        let flushStart = CFAbsoluteTimeGetCurrent()

        UIView.performWithoutAnimation {
            if let cell = tableView.cellForRow(at: indexPath) as? ChatMessageMarkdownCell {
                cell.applyStreamingText(message.content)
                cell.contentView.layoutIfNeeded()
            } else {
                tableView.reloadRows(at: [indexPath], with: .none)
            }
            tableView.beginUpdates()
            tableView.endUpdates()
            tableView.layoutIfNeeded()
        }

        if AppConfig.enablephaseLogs {
            streamingFlushSampleCount += 1
            let flushMs = (CFAbsoluteTimeGetCurrent() - flushStart) * 1000
            if flushMs >= 10 || streamingFlushSampleCount == 1 || streamingFlushSampleCount % 40 == 0 {
                print(
                    "[ConversationPerf][tableFlush] len=\(message.content.count) | row=\(indexPath.row) | ms=\(String(format: "%.2f", flushMs))"
                )
            }
        }

        if shouldAutoScroll {
            let afterHeight = tableView.contentSize.height
            let delta = autoScroll.computePinnedDelta(beforeHeight: beforeHeight, afterHeight: afterHeight)
            if abs(delta) > 0.5 {
                tableView.contentOffset.y += delta
            }
            scrollToBottomByOffset(animated: false)
            autoScroll.recordPinnedContentHeight(tableView.contentSize.height)
        }
        updateScrollToBottomButtonVisibility(isNearBottom: isNearBottom())
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

    func updateStreamingDisplayLinkIfNeeded() {
        let shouldRun = currentIsLoading
            && currentMessages.last?.isStreaming == true
            && AppConfig.enableTypewriter
        if shouldRun {
            startStreamingDisplayLinkIfNeeded()
        } else {
            stopStreamingDisplayLink()
        }
    }

    func startStreamingDisplayLinkIfNeeded() {
        guard streamingDisplayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(handleStreamingDisplayLink(_:)))
        let preferred = Int(AppConfig.typewriterRefreshRate)
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: 10,
                maximum: 120,
                preferred: Float(preferred)
            )
        } else {
            link.preferredFramesPerSecond = preferred
        }
        link.add(to: .main, forMode: .common)
        streamingDisplayLink = link
        lastStreamingRefreshRate = AppConfig.typewriterRefreshRate
    }

    func stopStreamingDisplayLink() {
        streamingDisplayLink?.invalidate()
        streamingDisplayLink = nil
        lastStreamingFlushTime = 0
        lastStreamingRefreshRate = 0
    }

    @objc func handleStreamingDisplayLink(_ link: CADisplayLink) {
        guard let indexPath = pendingStreamingIndexPath else { return }
        if tableView.isTracking || tableView.isDragging || tableView.isDecelerating {
            return
        }
        if lastStreamingRefreshRate != AppConfig.typewriterRefreshRate {
            let preferred = Int(AppConfig.typewriterRefreshRate)
            if #available(iOS 15.0, *) {
                link.preferredFrameRateRange = CAFrameRateRange(
                    minimum: 10,
                    maximum: 120,
                    preferred: Float(preferred)
                )
            } else {
                link.preferredFramesPerSecond = preferred
            }
            lastStreamingRefreshRate = AppConfig.typewriterRefreshRate
        }
        let now = link.timestamp
        let rate = max(5, min(120, AppConfig.typewriterRefreshRate))
        if now - lastStreamingFlushTime < (1.0 / rate) { return }
        lastStreamingFlushTime = now
        let shouldAutoScroll = autoScroll.shouldAutoScrollForStreaming()
        pendingStreamingIndexPath = nil
        performStreamingFlush(indexPath: indexPath, shouldAutoScroll: shouldAutoScroll)
    }
}
