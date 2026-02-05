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

    private lazy var historyBackButton = makeBarButton(
        systemName: "bubble.left",
        action: #selector(handleBackToChat)
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
        historyVC.navigationItem.titleView = makeTitleLabel("会话")
        historyVC.navigationItem.largeTitleDisplayMode = .never
        historyVC.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: historyBackButton)

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
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self

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
        historyBackButton.tintColor = tint
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
        appearance.buttonAppearance = buttonAppearance
        appearance.doneButtonAppearance = buttonAppearance

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
        button.addTarget(self, action: action, for: .touchUpInside)
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        return button
    }

    private func switchTo(index: Int) {
        guard index >= 0, index < controllers.count else { return }
        guard index != currentIndex else { return }
        let width = scrollView.bounds.width
        guard width > 0 else {
            DispatchQueue.main.async { [weak self] in
                self?.switchTo(index: index)
            }
            return
        }
        let targetOffset = CGPoint(x: width * CGFloat(index), y: 0)
        pageAnimator?.stopAnimation(true)
        let animator = UIViewPropertyAnimator(duration: pageTransitionDuration, curve: .easeInOut) { [weak self] in
            self?.scrollView.contentOffset = targetOffset
        }
        animator.addCompletion { [weak self] _ in
            self?.syncIndexFromScroll()
        }
        pageAnimator = animator
        animator.startAnimation()
    }

    @objc private func handleBackToChat() {
        viewModel.dispatch(.startNewConversation)
        switchTo(index: 1)
    }

    private func syncIndexFromScroll() {
        let width = scrollView.bounds.width
        guard width > 0 else { return }
        let rawIndex = Int(round(scrollView.contentOffset.x / width))
        let clamped = max(0, min(rawIndex, controllers.count - 1))
        guard clamped != currentIndex else { return }
        currentIndex = clamped
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
