//
//  ChatViewModelSwiftUIAdapter.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - SwiftUI 适配层（Combine）桥接 Rx ChatViewModel
//

import Foundation
import Combine
import RxSwift
import RxCocoa

@MainActor
final class ChatViewModelSwiftUIAdapter: ObservableObject {
    let viewModel: ChatViewModel
    private let disposeBag = DisposeBag()

    @Published private(set) var conversations: [ConversationRecord] = []
    @Published private(set) var isSwitchingConversation: Bool = false
    @Published private(set) var modelListState: ModelListState = .idle
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading: Bool = false

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        bind()
    }

    var selectedModel: AIModel? {
        get { modelListState.selectedModel }
        set { viewModel.selectedModel = newValue }
    }

    var availableModels: [AIModel] {
        modelListState.models
    }

    var isLoadingModels: Bool {
        modelListState.isLoading
    }

    func dispatch(_ action: ChatViewModel.Action) {
        viewModel.dispatch(action)
    }

    func emitEvent(_ event: ChatViewModel.Event) {
        viewModel.emitEvent(event)
    }

    func selectConversationAfterLoaded(id: String) async {
        await viewModel.selectConversationAfterLoaded(id: id)
    }

    func loadModels(forceRefresh: Bool = false) async {
        await viewModel.loadModels(forceRefresh: forceRefresh)
    }

    private func bind() {
        viewModel.conversationsObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in self?.conversations = $0 })
            .disposed(by: disposeBag)

        viewModel.isSwitchingConversationObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in self?.isSwitchingConversation = $0 })
            .disposed(by: disposeBag)

        viewModel.modelListStateObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in self?.modelListState = $0 })
            .disposed(by: disposeBag)

        viewModel.errorMessageObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in self?.errorMessage = $0 })
            .disposed(by: disposeBag)

        viewModel.isLoadingObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in self?.isLoading = $0 })
            .disposed(by: disposeBag)
    }
}
