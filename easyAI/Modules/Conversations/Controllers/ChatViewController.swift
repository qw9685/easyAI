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
import SwiftUI

final class ChatViewController: UIViewController {
    private let viewModel: ChatViewModel
    private let listViewModel = ChatListViewModel()
    private let tableViewController = ChatTableViewController()
    private lazy var inputBarController = ChatInputBarViewController(viewModel: viewModel)
    private let disposeBag = DisposeBag()
    private var inputBarBottomConstraint: Constraint?
    private let backgroundGradient = CAGradientLayer()
    private var themeObserver: NSObjectProtocol?
    
    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        bindKeyboard()
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
            inputBarBottomConstraint = make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).constraint
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
        listViewModel.bind(container: viewModel)
        tableViewController.bind(viewModel: listViewModel)
        tableViewController.onDeleteMessage = { [weak self] message in
            self?.viewModel.deleteMessage(id: message.id)
        }
        tableViewController.onSelectText = { [weak self] message in
            self?.presentTextSelection(for: message)
        }
    }

    @objc private func didTapBackgroundToDismissKeyboard() {
        view.endEditing(true)
    }

    private func bindKeyboard() {
        NotificationCenter.default.rx.notification(UIResponder.keyboardWillChangeFrameNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] notification in
                self?.handleKeyboard(notification: notification)
            })
            .disposed(by: disposeBag)
    }
    
    private func handleKeyboard(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
            let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
            let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else {
            return
        }
        
        let keyboardFrame = view.convert(endFrame, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrame.minY)
        
        inputBarBottomConstraint?.update(offset: -overlap)
        let options = UIView.AnimationOptions(rawValue: curveValue << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.view.layoutIfNeeded()
            self.tableViewController.keepBottomPinnedForLayoutChange(animated: true)
        } completion: { _ in
            self.tableViewController.keepBottomPinnedForLayoutChange(animated: false)
        }
    }
    
    
    private func loadModelsIfNeeded() {
        if viewModel.availableModels.isEmpty {
            Task {
                await viewModel.loadModels()
            }
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
        let settingsView = SettingsView()
            .environmentObject(viewModel)
            .environmentObject(ThemeManager.shared)
        let controller = UIHostingController(rootView: settingsView)
        controller.modalPresentationStyle = .formSheet
        present(controller, animated: true)
    }
    
    @objc private func showConversations() {
        let conversationView = HistoryConversationsListView()
            .environmentObject(viewModel)
            .environmentObject(ThemeManager.shared)
        let controller = UIHostingController(rootView: conversationView)
        controller.modalPresentationStyle = .formSheet
        present(controller, animated: true)
    }
}
