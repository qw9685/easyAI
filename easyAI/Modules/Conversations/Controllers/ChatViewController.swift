//
//  ChatViewController.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 聊天主界面容器与导航按钮
//  - 处理键盘与背景布局
//
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

final class ChatViewController: UIViewController {
    private let viewModel: ChatViewModel
    private weak var router: ChatRouting?
    private let listViewModel = ChatListViewModel()
    private let tableViewController = ChatTableViewController()
    private let actionRelay = PublishRelay<ChatViewModel.Action>()
    private var output: ChatViewModel.Output?
    private lazy var inputBarController = ChatInputBarViewController(
        viewModel: viewModel,
        actionHandler: { [weak self] action in
            self?.actionRelay.accept(action)
        }
    )
    private let disposeBag = DisposeBag()
    private let backgroundGradient = CAGradientLayer()
    private var lastLayoutHeights: (table: CGFloat, input: CGFloat)?
    private lazy var dismissKeyboardTapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(didTapToDismissKeyboard))
        gesture.cancelsTouchesInView = false
        gesture.delegate = self
        return gesture
    }()
    private let errorBanner = UIView()
    private let errorBannerLabel = UILabel()
    private var errorBannerHideTask: DispatchWorkItem?
    private var errorBannerTopConstraint: Constraint?

    private lazy var historyButton = makeBarButton(
        systemName: "clock",
        action: #selector(showConversations)
    )

    private lazy var settingsButton = makeBarButton(
        systemName: "gearshape",
        action: #selector(showSettings)
    )

    private lazy var ttsButton = makeBarButton(
        systemName: ttsToggleImageName(),
        action: #selector(didTapTtsToggle)
    )

    private lazy var rightButtonsStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [ttsButton, settingsButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        return stack
    }()

    private lazy var leftBarItem = UIBarButtonItem(customView: historyButton)
    private lazy var rightBarItem = UIBarButtonItem(customView: rightButtonsStack)
    
    init(viewModel: ChatViewModel, router: ChatRouting? = nil) {
        self.viewModel = viewModel
        self.router = router
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        setupKeyboardDismissTapGesture()
        loadModelsIfNeeded()
        observeThemeChanges()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradient.frame = view.bounds

        let tableHeight = tableViewController.view.bounds.height
        let inputHeight = inputBarController.view.bounds.height
        defer { lastLayoutHeights = (tableHeight, inputHeight) }

        guard tableHeight > 0, inputHeight > 0 else { return }
        guard let last = lastLayoutHeights else { return }

        let didTableHeightChange = abs(last.table - tableHeight) > 0.5
        let didInputHeightChange = abs(last.input - inputHeight) > 0.5
        if didTableHeightChange || didInputHeightChange {
            tableViewController.keepBottomPinnedForLayoutChange(animated: false)
        }
    }
    
    private func setupUI() {
        setupBackground()
        setupNavigationBarAppearance()
        title = "EasyAI"
        configureNavigationItems()
        
        addChild(tableViewController)
        view.addSubview(tableViewController.view)
        tableViewController.didMove(toParent: self)
        
        addChild(inputBarController)
        view.addSubview(inputBarController.view)
        inputBarController.didMove(toParent: self)
        inputBarController.view.backgroundColor = .clear
        
        tableViewController.view.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(inputBarController.view.snp.top)
        }
        inputBarController.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
        }

        setupErrorBanner()
    }

    private func configureNavigationItems() {
        navigationItem.leftBarButtonItem = leftBarItem
        navigationItem.rightBarButtonItem = rightBarItem
    }
    
    private func setupBackground() {
        view.backgroundColor = AppTheme.canvas
        backgroundGradient.colors = [
            AppTheme.canvas.cgColor,
            AppTheme.canvasSoft.cgColor
        ]
        backgroundGradient.startPoint = CGPoint(x: 0, y: 0)
        backgroundGradient.endPoint = CGPoint(x: 1, y: 1)
        backgroundGradient.frame = view.bounds
        if backgroundGradient.superlayer == nil {
            view.layer.insertSublayer(backgroundGradient, at: 0)
        }
    }

    private func setupNavigationBarAppearance() {
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

        let navBar = navigationController?.navigationBar
        navBar?.standardAppearance = appearance
        navBar?.scrollEdgeAppearance = appearance
        navBar?.compactAppearance = appearance
        navBar?.isTranslucent = false
        navBar?.tintColor = AppTheme.textPrimary
        navBar?.prefersLargeTitles = false
    }

    private func observeThemeChanges() {
        ThemeManager.shared.themeRelay
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.applyTheme()
            })
            .disposed(by: disposeBag)
    }

    private func applyTheme() {
        setupBackground()
        setupNavigationBarAppearance()
        inputBarController.applyTheme()
        tableViewController.applyTheme()
        let tint = AppTheme.textPrimary
        historyButton.tintColor = tint
        settingsButton.tintColor = tint
        ttsButton.tintColor = tint
        ttsButton.setImage(UIImage(systemName: ttsToggleImageName()), for: .normal)
    }

    private func bindViewModel() {
        output = viewModel.transform(
            ChatViewModel.Input(actions: actionRelay.asObservable())
        )
        listViewModel.bind(container: viewModel)
        tableViewController.bind(viewModel: listViewModel)
        tableViewController.onDeleteMessage = { [weak self] message in
            self?.actionRelay.accept(.deleteMessage(message.id))
        }
        tableViewController.onSelectText = { [weak self] message in
            self?.presentTextSelection(for: message)
        }
        tableViewController.onWillBeginDragging = { [weak self] in
            self?.view.endEditing(true)
        }

        output?.errorMessage
            .observe(on: MainScheduler.instance)
            .distinctUntilChanged { lhs, rhs in
                lhs == rhs
            }
            .subscribe(onNext: { [weak self] message in
                guard let self else { return }
                let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let trimmed, !trimmed.isEmpty else {
                    self.hideErrorBanner(animated: true)
                    return
                }
                self.showErrorBanner(text: trimmed)
            })
            .disposed(by: disposeBag)
    }

    private func setupKeyboardDismissTapGesture() {
        view.addGestureRecognizer(dismissKeyboardTapGesture)
    }

    @objc private func didTapToDismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func didTapBackgroundToDismissKeyboard() {
        view.endEditing(true)
    }

    
    private func loadModelsIfNeeded() {
        if viewModel.availableModels.isEmpty {
            actionRelay.accept(.loadModels(forceRefresh: false))
        }
    }

    private func presentTextSelection(for message: Message) {
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let controller = ChatTextSelectionViewController(text: message.content)
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }
    
    @objc private func showSettings() {
        router?.showSettings(from: self)
    }
    
    @objc private func showConversations() {
        router?.showConversations(from: self)
    }

    @objc private func didTapTtsToggle() {
        AppConfig.ttsMuted.toggle()
        TextToSpeechManager.shared.handleMuteChanged()
        ttsButton.setImage(UIImage(systemName: ttsToggleImageName()), for: .normal)
    }

    private func ttsToggleImageName() -> String {
        AppConfig.ttsMuted ? "speaker.slash" : "speaker.wave.2"
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

    private func setupErrorBanner() {
        errorBanner.backgroundColor = UIColor.systemRed.withAlphaComponent(0.94)
        errorBanner.layer.cornerRadius = 12
        errorBanner.layer.masksToBounds = true
        errorBanner.alpha = 0
        errorBanner.transform = CGAffineTransform(translationX: 0, y: -8)
        errorBanner.isUserInteractionEnabled = false

        errorBannerLabel.font = UIFont.preferredFont(forTextStyle: .callout)
        errorBannerLabel.textColor = .white
        errorBannerLabel.numberOfLines = 2
        errorBannerLabel.textAlignment = .left

        view.addSubview(errorBanner)
        errorBanner.addSubview(errorBannerLabel)

        errorBanner.snp.makeConstraints { make in
            errorBannerTopConstraint = make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(8).constraint
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualToSuperview().inset(16)
            make.leading.greaterThanOrEqualToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().inset(16)
        }

        errorBannerLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        }
    }

    private func showErrorBanner(text: String) {
        errorBannerHideTask?.cancel()
        errorBannerLabel.text = text
        errorBannerTopConstraint?.update(offset: 8)

        UIView.animate(withDuration: 0.2) {
            self.errorBanner.alpha = 1
            self.errorBanner.transform = .identity
        }

        let hideTask = DispatchWorkItem { [weak self] in
            self?.hideErrorBanner(animated: true)
        }
        errorBannerHideTask = hideTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8, execute: hideTask)
    }

    private func hideErrorBanner(animated: Bool) {
        errorBannerHideTask?.cancel()
        errorBannerHideTask = nil

        let animations = {
            self.errorBanner.alpha = 0
            self.errorBanner.transform = CGAffineTransform(translationX: 0, y: -8)
        }

        if animated {
            UIView.animate(withDuration: 0.18, animations: animations)
        } else {
            animations()
        }
    }
}

extension ChatViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === dismissKeyboardTapGesture else { return true }

        guard let touchedView = touch.view else { return true }

        if touchedView is UIControl { return false }

        if touchedView.isDescendant(of: inputBarController.view) { return false }

        if let identifier = touchedView.accessibilityIdentifier,
           identifier == "ChatInput.TemplateScrollView" {
            return false
        }

        var currentView: UIView? = touchedView
        while let view = currentView {
            if view is UIScrollView,
               view.accessibilityIdentifier == "ChatInput.TemplateScrollView" {
                return false
            }
            currentView = view.superview
        }

        return true
    }
}
