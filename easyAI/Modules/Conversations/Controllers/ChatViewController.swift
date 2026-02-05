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
    private var themeObserver: NSObjectProtocol?
    
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
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "list.bullet"),
            style: .plain,
            target: self,
            action: #selector(showConversations)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )
        
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
        appearance.backgroundColor = AppTheme.canvas
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: AppTheme.textPrimary,
            .font: AppTheme.titleFont
        ]

        let navBar = navigationController?.navigationBar
        navBar?.standardAppearance = appearance
        navBar?.scrollEdgeAppearance = appearance
        navBar?.compactAppearance = appearance
        navBar?.isTranslucent = false
        navBar?.tintColor = AppTheme.textSecondary
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

    private func applyTheme() {
        setupBackground()
        setupNavigationBarAppearance()
        inputBarController.applyTheme()
        tableViewController.applyTheme()
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
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
}
