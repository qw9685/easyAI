//
//  MainPagerViewController.swift
//  easyAI
//
//  Root pager for Chat / History / Settings.
//

import UIKit
import SwiftUI
import RxSwift
import RxCocoa
import SnapKit

final class MainPagerViewController: UIViewController {
    private let viewModel: ChatViewModel
    private let swiftUIAdapter: ChatViewModelSwiftUIAdapter
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private var controllers: [UIViewController] = []
    private var currentIndex: Int = 1
    private let pageTransitionDuration: TimeInterval = 0.28
    private var pageAnimator: UIViewPropertyAnimator?
    private var lastScrollSize: CGSize = .zero
    private let disposeBag = DisposeBag()
    private var interactiveSourceIndex: Int?
    private var interactiveTargetIndex: Int?
    private lazy var leftEdgePanGesture: UIScreenEdgePanGestureRecognizer = {
        let gesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleLeftEdgePan(_:)))
        gesture.edges = .left
        return gesture
    }()
    private lazy var rightEdgePanGesture: UIScreenEdgePanGestureRecognizer = {
        let gesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleRightEdgePan(_:)))
        gesture.edges = .right
        return gesture
    }()

    private lazy var historyNewButton = makeBarButton(
        systemName: "square.and.pencil",
        action: #selector(handleStartNewConversation)
    )
    private lazy var settingsBackButton = makeBarButton(
        systemName: "bubble.left",
        action: #selector(handleBackToChat)
    )

    init(viewModel: ChatViewModel, swiftUIAdapter: ChatViewModelSwiftUIAdapter) {
        self.viewModel = viewModel
        self.swiftUIAdapter = swiftUIAdapter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupControllers()
        setupUI()
        applyTheme()
        observeThemeChanges()
        observeEvents()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = scrollView.bounds.size
        guard size.width > 0, size != lastScrollSize else { return }
        lastScrollSize = size
        let offset = CGPoint(x: size.width * CGFloat(currentIndex), y: 0)
        scrollView.setContentOffset(offset, animated: false)
    }

    private func setupControllers() {
        let chatVC = ChatViewController(viewModel: viewModel, router: self)
        let historyView = HistoryConversationsListView(isEmbeddedInPager: true)
            .environmentObject(swiftUIAdapter)
            .environmentObject(ThemeManager.shared)
        let historyVC = UIHostingController(rootView: historyView)
        historyVC.navigationItem.titleView = makeTitleLabel("历史")
        historyVC.navigationItem.largeTitleDisplayMode = .never
        historyVC.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: historyNewButton)

        let settingsView = SettingsView(isEmbeddedInPager: true)
            .environmentObject(swiftUIAdapter)
            .environmentObject(ThemeManager.shared)
        let settingsVC = UIHostingController(rootView: settingsView)
        settingsVC.navigationItem.titleView = makeTitleLabel("设置")
        settingsVC.navigationItem.largeTitleDisplayMode = .never
        settingsVC.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: settingsBackButton)

        let historyNav = UINavigationController(rootViewController: historyVC)
        let chatNav = UINavigationController(rootViewController: chatVC)
        let settingsNav = UINavigationController(rootViewController: settingsVC)

        controllers = [historyNav, chatNav, settingsNav]
    }

    private func embedControllers() {
        controllers.forEach { controller in
            addChild(controller)
            contentStack.addArrangedSubview(controller.view)
            controller.didMove(toParent: self)
            controller.view.snp.makeConstraints { make in
                make.width.equalTo(scrollView.frameLayoutGuide)
            }
        }
    }

    private func setupUI() {
        view.backgroundColor = AppTheme.canvas

        scrollView.isPagingEnabled = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.isScrollEnabled = false
        scrollView.delegate = self
        view.addGestureRecognizer(leftEdgePanGesture)
        view.addGestureRecognizer(rightEdgePanGesture)

        contentStack.axis = .horizontal
        contentStack.alignment = .fill
        contentStack.distribution = .fillEqually

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        embedControllers()

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentStack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.height.equalTo(scrollView.frameLayoutGuide)
        }
    }

    private func observeThemeChanges() {
        ThemeManager.shared.themeRelay
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.applyTheme()
            })
            .disposed(by: disposeBag)
    }

    private func observeEvents() {
        viewModel.events
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                switch event {
                case .switchToChat:
                    self?.switchTo(index: 1)
                case .switchToSettings:
                    self?.switchTo(index: 2)
                }
            })
            .disposed(by: disposeBag)
    }

    private func applyTheme() {
        view.backgroundColor = AppTheme.canvas
        controllers.compactMap { $0 as? UINavigationController }.forEach { navigation in
            applyNavigationAppearance(navigation)
            if let label = navigation.topViewController?.navigationItem.titleView as? UILabel {
                label.textColor = AppTheme.textPrimary
                label.font = AppTheme.titleFont
            }
        }
        let tint = AppTheme.textPrimary
        historyNewButton.tintColor = tint
        settingsBackButton.tintColor = tint
    }

    private func applyNavigationAppearance(_ navigation: UINavigationController) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: AppTheme.textPrimary,
            .font: AppTheme.titleFont
        ]
        let buttonAppearance = UIBarButtonItemAppearance(style: .plain)
        buttonAppearance.normal.titleTextAttributes = [
            .foregroundColor: AppTheme.textPrimary
        ]
        buttonAppearance.normal.backgroundImage = nil
        buttonAppearance.highlighted.backgroundImage = nil
        buttonAppearance.disabled.backgroundImage = nil
        buttonAppearance.focused.backgroundImage = nil
        appearance.buttonAppearance = buttonAppearance
        appearance.doneButtonAppearance = buttonAppearance
        appearance.backButtonAppearance = buttonAppearance

        let navBar = navigation.navigationBar
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.isTranslucent = false
        navBar.tintColor = AppTheme.textPrimary
        navBar.prefersLargeTitles = false
    }

    private func makeTitleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = AppTheme.titleFont
        label.textColor = AppTheme.textPrimary
        return label
    }

    private func makeBarButton(systemName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = AppTheme.textPrimary
        button.backgroundColor = .clear
        button.configuration = .plain()
        if #available(iOS 15.0, *) {
            var configuration = button.configuration ?? UIButton.Configuration.plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
            button.configuration = configuration
        } else {
            button.adjustsImageWhenHighlighted = false
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        }
        button.configurationUpdateHandler = { updateButton in
            let isPressed = updateButton.state.contains(.highlighted) || updateButton.state.contains(.selected)
            updateButton.alpha = isPressed ? 0.92 : 1.0
        }
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func switchTo(index: Int) {
        guard index >= 0, index < controllers.count else { return }
        let width = scrollView.bounds.width
        guard width > 0 else {
            DispatchQueue.main.async { [weak self] in
                self?.switchTo(index: index)
            }
            return
        }
        let targetOffset = CGPoint(x: width * CGFloat(index), y: 0)
        if index == currentIndex {
            let offsetDelta = abs(scrollView.contentOffset.x - targetOffset.x)
            guard offsetDelta > 0.5 else { return }
        }
        debugPagerLog("switchTo request from=\(currentIndex) to=\(index)")
        pageAnimator?.stopAnimation(true)
        let animator = UIViewPropertyAnimator(duration: pageTransitionDuration, curve: .easeInOut) { [weak self] in
            self?.scrollView.contentOffset = targetOffset
        }
        animator.addCompletion { [weak self] _ in
            self?.syncIndexFromScroll()
            self?.debugPagerLog("switchTo complete current=\(self?.currentIndex ?? -1)")
        }
        pageAnimator = animator
        animator.startAnimation()
    }

    @objc private func handleBackToChat() {
        switchTo(index: 1)
    }

    @objc private func handleStartNewConversation() {
        viewModel.dispatch(.startNewConversation)
        switchTo(index: 1)
    }

    private func syncIndexFromScroll() {
        let width = scrollView.bounds.width
        guard width > 0 else { return }
        let rawIndex = Int(round(scrollView.contentOffset.x / width))
        let clamped = max(0, min(rawIndex, controllers.count - 1))
        guard clamped != currentIndex else { return }
        debugPagerLog("syncIndex from=\(currentIndex) to=\(clamped)")
        currentIndex = clamped
    }

    private func beginInteractiveTransition(targetIndex: Int) {
        guard targetIndex >= 0, targetIndex < controllers.count else {
            interactiveSourceIndex = nil
            interactiveTargetIndex = nil
            return
        }
        pageAnimator?.stopAnimation(true)
        interactiveSourceIndex = currentIndex
        interactiveTargetIndex = targetIndex
        debugPagerLog("interactive begin source=\(currentIndex) target=\(targetIndex)")
    }

    private func updateInteractiveTransition(progress: CGFloat) {
        guard let sourceIndex = interactiveSourceIndex,
              let targetIndex = interactiveTargetIndex else { return }
        let width = scrollView.bounds.width
        guard width > 0 else { return }
        let sourceX = width * CGFloat(sourceIndex)
        let targetX = width * CGFloat(targetIndex)
        let clampedProgress = min(max(progress, 0), 1)
        let x = sourceX + (targetX - sourceX) * clampedProgress
        scrollView.contentOffset = CGPoint(x: x, y: 0)
    }

    private func endInteractiveTransition(progress: CGFloat, velocity: CGFloat) {
        guard let sourceIndex = interactiveSourceIndex,
              let targetIndex = interactiveTargetIndex else { return }
        let settleIndex = resolveSettleIndex(
            sourceIndex: sourceIndex,
            targetIndex: targetIndex,
            progress: progress,
            velocity: velocity
        )
        let shouldComplete = settleIndex == targetIndex
        debugPagerLog(
            "interactive end progress=\(String(format: "%.2f", progress)) velocity=\(Int(velocity)) settle=\(settleIndex) complete=\(shouldComplete)"
        )

        interactiveSourceIndex = nil
        interactiveTargetIndex = nil

        switchTo(index: settleIndex)
    }

    private func resolveSettleIndex(sourceIndex: Int, targetIndex: Int, progress: CGFloat, velocity: CGFloat) -> Int {
        let velocityThreshold: CGFloat = 720

        if abs(velocity) >= velocityThreshold {
            if targetIndex > sourceIndex {
                return velocity < 0 ? targetIndex : sourceIndex
            }
            return velocity > 0 ? targetIndex : sourceIndex
        }

        return progress >= 0.5 ? targetIndex : sourceIndex
    }

    private func cancelInteractiveTransition() {
        guard let sourceIndex = interactiveSourceIndex else { return }
        debugPagerLog("interactive cancel source=\(sourceIndex)")
        interactiveSourceIndex = nil
        interactiveTargetIndex = nil
        switchTo(index: sourceIndex)
    }

    private func debugPagerLog(_ message: String) {
#if DEBUG
        print("[Pager] \(message)")
#endif
    }
}

private extension MainPagerViewController {
    @objc func handleLeftEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        let translation = gesture.translation(in: view).x
        let velocity = gesture.velocity(in: view).x
        let width = max(scrollView.bounds.width, 1)
        let progress = min(max(translation / width, 0), 1)

        switch gesture.state {
        case .began:
            beginInteractiveTransition(targetIndex: currentIndex - 1)
        case .changed:
            updateInteractiveTransition(progress: progress)
        case .ended:
            endInteractiveTransition(progress: progress, velocity: velocity)
        case .cancelled, .failed:
            cancelInteractiveTransition()
        default:
            break
        }
    }

    @objc func handleRightEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        let translation = gesture.translation(in: view).x
        let velocity = gesture.velocity(in: view).x
        let width = max(scrollView.bounds.width, 1)
        let progress = min(max(-translation / width, 0), 1)

        switch gesture.state {
        case .began:
            beginInteractiveTransition(targetIndex: currentIndex + 1)
        case .changed:
            updateInteractiveTransition(progress: progress)
        case .ended:
            endInteractiveTransition(progress: progress, velocity: velocity)
        case .cancelled, .failed:
            cancelInteractiveTransition()
        default:
            break
        }
    }
}

extension MainPagerViewController: ChatRouting {
    func showSettings(from presenter: UIViewController) {
        switchTo(index: 2)
    }

    func showConversations(from presenter: UIViewController) {
        switchTo(index: 0)
    }
}

extension MainPagerViewController: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        pageAnimator?.stopAnimation(true)
        pageAnimator = nil
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        syncIndexFromScroll()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            syncIndexFromScroll()
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        syncIndexFromScroll()
    }
}
