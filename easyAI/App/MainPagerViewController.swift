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

final class MainPagerViewController: UIViewController {
    private let viewModel: ChatViewModel
    private let swiftUIAdapter: ChatViewModelSwiftUIAdapter
    private let pageViewController: UIPageViewController
    private let tabTitles = ["历史", "会话", "设置"]

    private let topBarView = UIView()
    private let leftButton = UIButton(type: .system)
    private let rightButton = UIButton(type: .system)
    private let ttsButton = UIButton(type: .system)
    private let titleLabel = UILabel()

    private var controllers: [UIViewController] = []
    private var currentIndex: Int = 1
    private var isPageReady = false
    private let pageTransitionDuration: CFTimeInterval = 0.28
    private var themeObserver: NSObjectProtocol?
    private let disposeBag = DisposeBag()

    init(viewModel: ChatViewModel, swiftUIAdapter: ChatViewModelSwiftUIAdapter) {
        self.viewModel = viewModel
        self.swiftUIAdapter = swiftUIAdapter
        self.pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
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
        updateNavTitle()
        updateTopBarButtons()
        observeThemeChanges()
        observeEvents()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isPageReady = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }

    private func setupControllers() {
        let chatVC = ChatViewController(viewModel: viewModel, router: self)
        let historyView = HistoryConversationsListView()
            .environmentObject(swiftUIAdapter)
            .environmentObject(ThemeManager.shared)
        let historyVC = UIHostingController(rootView: historyView)

        let settingsView = SettingsView()
            .environmentObject(swiftUIAdapter)
            .environmentObject(ThemeManager.shared)
        let settingsVC = UIHostingController(rootView: settingsView)

        controllers = [historyVC, chatVC, settingsVC]
    }

    private func setupUI() {
        view.backgroundColor = AppTheme.canvas

        setupTopBar()

        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)
        pageViewController.dataSource = self
        pageViewController.delegate = self
        pageViewController.setViewControllers(
            [controllers[currentIndex]],
            direction: .forward,
            animated: false
        )

        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.topAnchor.constraint(equalTo: topBarView.bottomAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupTopBar() {
        topBarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBarView)

        leftButton.setImage(UIImage(systemName: "clock"), for: .normal)
        rightButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        ttsButton.setImage(ttsToggleImage(), for: .normal)
        leftButton.addTarget(self, action: #selector(didTapHistory), for: .touchUpInside)
        rightButton.addTarget(self, action: #selector(didTapSettings), for: .touchUpInside)
        ttsButton.addTarget(self, action: #selector(didTapTtsToggle), for: .touchUpInside)

        [leftButton, rightButton, ttsButton, titleLabel].forEach { item in
            item.translatesAutoresizingMaskIntoConstraints = false
            topBarView.addSubview(item)
        }

        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)

        NSLayoutConstraint.activate([
            topBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBarView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBarView.heightAnchor.constraint(equalToConstant: 44),

            leftButton.leadingAnchor.constraint(equalTo: topBarView.leadingAnchor, constant: 16),
            leftButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            leftButton.widthAnchor.constraint(equalToConstant: 28),
            leftButton.heightAnchor.constraint(equalToConstant: 28),

            rightButton.trailingAnchor.constraint(equalTo: topBarView.trailingAnchor, constant: -16),
            rightButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            rightButton.widthAnchor.constraint(equalToConstant: 28),
            rightButton.heightAnchor.constraint(equalToConstant: 28),

            ttsButton.trailingAnchor.constraint(equalTo: rightButton.leadingAnchor, constant: -12),
            ttsButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            ttsButton.widthAnchor.constraint(equalToConstant: 28),
            ttsButton.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.centerXAnchor.constraint(equalTo: topBarView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor)
        ])
    }

    private func observeThemeChanges() {
        themeObserver = NotificationCenter.default.addObserver(
            forName: .themeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
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
        topBarView.backgroundColor = .white
        titleLabel.textColor = AppTheme.textPrimary

        leftButton.tintColor = AppTheme.textPrimary
        rightButton.tintColor = AppTheme.textPrimary
        ttsButton.tintColor = AppTheme.textPrimary
    }

    private func updateNavTitle() {
        titleLabel.text = tabTitles[currentIndex]
    }

    private func updateTopBarButtons() {
        switch currentIndex {
        case 1:
            // Chat: left -> history, right -> settings, tts -> toggle
            leftButton.isHidden = false
            rightButton.isHidden = false
            ttsButton.isHidden = false
            leftButton.setImage(UIImage(systemName: "clock"), for: .normal)
            rightButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
            ttsButton.setImage(ttsToggleImage(), for: .normal)
            leftButton.removeTarget(nil, action: nil, for: .allEvents)
            rightButton.removeTarget(nil, action: nil, for: .allEvents)
            ttsButton.removeTarget(nil, action: nil, for: .allEvents)
            leftButton.addTarget(self, action: #selector(didTapHistory), for: .touchUpInside)
            rightButton.addTarget(self, action: #selector(didTapSettings), for: .touchUpInside)
            ttsButton.addTarget(self, action: #selector(didTapTtsToggle), for: .touchUpInside)
        case 0:
            // History: left hidden, right -> back to chat
            leftButton.isHidden = true
            rightButton.isHidden = false
            ttsButton.isHidden = true
            rightButton.setImage(UIImage(systemName: "bubble.left"), for: .normal)
            rightButton.removeTarget(nil, action: nil, for: .allEvents)
            rightButton.addTarget(self, action: #selector(didTapChat), for: .touchUpInside)
        case 2:
            // Settings: left -> back to chat, right hidden
            leftButton.isHidden = false
            rightButton.isHidden = true
            ttsButton.isHidden = true
            leftButton.setImage(UIImage(systemName: "bubble.left"), for: .normal)
            leftButton.removeTarget(nil, action: nil, for: .allEvents)
            leftButton.addTarget(self, action: #selector(didTapChat), for: .touchUpInside)
        default:
            break
        }
    }

    @objc private func didTapHistory() {
        switchTo(index: 0)
    }

    @objc private func didTapSettings() {
        switchTo(index: 2)
    }

    @objc private func didTapChat() {
        viewModel.dispatch(.startNewConversation)
        switchTo(index: 1)
    }

    @objc private func didTapTtsToggle() {
        AppConfig.ttsMuted.toggle()
        TextToSpeechManager.shared.handleMuteChanged()
        ttsButton.setImage(ttsToggleImage(), for: .normal)
    }

    private func switchTo(index: Int) {
        guard index >= 0, index < controllers.count else { return }
        guard index != currentIndex else { return }
        guard isPageReady else {
            DispatchQueue.main.async { [weak self] in
                self?.switchTo(index: index)
            }
            return
        }
        let direction: UIPageViewController.NavigationDirection = index > currentIndex ? .forward : .reverse
        pageViewController.view.layoutIfNeeded()
        CATransaction.begin()
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        CATransaction.setAnimationDuration(pageTransitionDuration)
        pageViewController.setViewControllers(
            [controllers[index]],
            direction: direction,
            animated: true
        ) { [weak self] completed in
            guard let self, completed else { return }
            self.currentIndex = index
            self.updateNavTitle()
            self.updateTopBarButtons()
        }
        CATransaction.commit()
    }

    private func ttsToggleImage() -> UIImage? {
        AppConfig.ttsMuted
            ? UIImage(systemName: "speaker.slash")
            : UIImage(systemName: "speaker.wave.2")
    }
}

extension MainPagerViewController: ChatRouting {
    func showSettings(from presenter: UIViewController) {
        let settingsView = SettingsView()
            .environmentObject(swiftUIAdapter)
            .environmentObject(ThemeManager.shared)
        let controller = UIHostingController(rootView: settingsView)
        controller.modalPresentationStyle = .formSheet
        presenter.present(controller, animated: true)
    }

    func showConversations(from presenter: UIViewController) {
        let conversationView = HistoryConversationsListView()
            .environmentObject(swiftUIAdapter)
            .environmentObject(ThemeManager.shared)
        let controller = UIHostingController(rootView: conversationView)
        controller.modalPresentationStyle = .formSheet
        presenter.present(controller, animated: true)
    }
}

extension MainPagerViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let index = controllers.firstIndex(of: viewController) else { return nil }
        let prev = index - 1
        guard prev >= 0 else { return nil }
        return controllers[prev]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let index = controllers.firstIndex(of: viewController) else { return nil }
        let next = index + 1
        guard next < controllers.count else { return nil }
        return controllers[next]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let visible = pageViewController.viewControllers?.first,
              let index = controllers.firstIndex(of: visible) else { return }
        currentIndex = index
        updateNavTitle()
        updateTopBarButtons()
    }
}
