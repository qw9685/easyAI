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
        stack.spacing = 12
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
        loadModelsIfNeeded()
        observeThemeChanges()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradient.frame = view.bounds
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
        appearance.buttonAppearance = buttonAppearance
        appearance.doneButtonAppearance = buttonAppearance

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
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
}
