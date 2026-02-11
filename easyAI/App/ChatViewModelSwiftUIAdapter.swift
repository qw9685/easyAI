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

struct RecentAssistantStats {
    let windowSize: Int
    let sampleCount: Int
    let metricsSampleCount: Int
    let averageLatencyMs: Int?
    let averageCostUSD: Double?
    let averageTokens: Int?

    static let empty = RecentAssistantStats(
        windowSize: 30,
        sampleCount: 0,
        metricsSampleCount: 0,
        averageLatencyMs: nil,
        averageCostUSD: nil,
        averageTokens: nil
    )

    var hasSamples: Bool {
        sampleCount > 0
    }
}

struct RoutingEffectStats {
    let totalCompletedAssistantCount: Int
    let smartRoutedCount: Int
    let routedSuccessCount: Int
    let nonRoutedSuccessCount: Int
    let routedAverageLatencyMs: Int?
    let nonRoutedAverageLatencyMs: Int?
    let routedAverageCostUSD: Double?
    let nonRoutedAverageCostUSD: Double?

    static let empty = RoutingEffectStats(
        totalCompletedAssistantCount: 0,
        smartRoutedCount: 0,
        routedSuccessCount: 0,
        nonRoutedSuccessCount: 0,
        routedAverageLatencyMs: nil,
        nonRoutedAverageLatencyMs: nil,
        routedAverageCostUSD: nil,
        nonRoutedAverageCostUSD: nil
    )

    var smartHitRate: Double {
        guard totalCompletedAssistantCount > 0 else { return 0 }
        return Double(smartRoutedCount) / Double(totalCompletedAssistantCount)
    }

    var routedSuccessRate: Double {
        guard smartRoutedCount > 0 else { return 0 }
        return Double(routedSuccessCount) / Double(smartRoutedCount)
    }

    var latencyDeltaMs: Int? {
        guard let routedAverageLatencyMs, let nonRoutedAverageLatencyMs else { return nil }
        return routedAverageLatencyMs - nonRoutedAverageLatencyMs
    }

    var costDeltaUSD: Double? {
        guard let routedAverageCostUSD, let nonRoutedAverageCostUSD else { return nil }
        return routedAverageCostUSD - nonRoutedAverageCostUSD
    }

    var hasSamples: Bool {
        totalCompletedAssistantCount > 0
    }
}

@MainActor
final class ChatViewModelSwiftUIAdapter: ObservableObject {
    let viewModel: ChatViewModel
    private let disposeBag = DisposeBag()

    @Published private(set) var conversations: [ConversationRecord] = []
    @Published private(set) var isSwitchingConversation: Bool = false
    @Published private(set) var modelListState: ModelListState = .idle
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var recentAssistantStats: RecentAssistantStats = .empty
    @Published private(set) var routingEffectStats: RoutingEffectStats = .empty
    @Published private(set) var providerStats: [ProviderStats] = []

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        self.providerStats = ProviderStatsRepository.shared.fetchAll()
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

    func clearProviderStats() {
        ProviderStatsRepository.shared.clearAll()
        providerStats = []
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

        viewModel.listSnapshotObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] snapshot in
                self?.recentAssistantStats = Self.makeRecentAssistantStats(from: snapshot.messages)
                self?.routingEffectStats = Self.makeRoutingEffectStats(from: snapshot.messages)
                self?.providerStats = ProviderStatsRepository.shared.fetchAll()
            })
            .disposed(by: disposeBag)
    }

    private static func makeRecentAssistantStats(from messages: [Message], windowSize: Int = 30) -> RecentAssistantStats {
        let completedAssistantMessages = messages.filter { message in
            guard message.role == .assistant else { return false }
            if message.isStreaming { return false }
            return !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let recent = Array(completedAssistantMessages.suffix(windowSize))
        let metricsItems = recent.compactMap(\.metrics)

        let latencies = metricsItems.compactMap(\.latencyMs)
        let costs = metricsItems.compactMap(\.estimatedCostUSD)
        let totalTokens = metricsItems.compactMap(\.totalTokens)

        let avgLatency: Int?
        if latencies.isEmpty {
            avgLatency = nil
        } else {
            avgLatency = Int((Double(latencies.reduce(0, +)) / Double(latencies.count)).rounded())
        }

        let avgCost: Double?
        if costs.isEmpty {
            avgCost = nil
        } else {
            avgCost = costs.reduce(0, +) / Double(costs.count)
        }

        let avgTokens: Int?
        if totalTokens.isEmpty {
            avgTokens = nil
        } else {
            avgTokens = Int((Double(totalTokens.reduce(0, +)) / Double(totalTokens.count)).rounded())
        }

        return RecentAssistantStats(
            windowSize: windowSize,
            sampleCount: recent.count,
            metricsSampleCount: metricsItems.count,
            averageLatencyMs: avgLatency,
            averageCostUSD: avgCost,
            averageTokens: avgTokens
        )
    }

    private static func makeRoutingEffectStats(from messages: [Message]) -> RoutingEffectStats {
        let completedAssistantMessages = messages.filter { message in
            guard message.role == .assistant else { return false }
            if message.isStreaming { return false }
            let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty
        }

        guard !completedAssistantMessages.isEmpty else {
            return .empty
        }

        let routed = completedAssistantMessages.filter { $0.routingMetadata != nil }
        let nonRouted = completedAssistantMessages.filter { $0.routingMetadata == nil }

        let routedSuccess = routed.filter { !isErrorMessage($0) }
        let nonRoutedSuccess = nonRouted.filter { !isErrorMessage($0) }

        return RoutingEffectStats(
            totalCompletedAssistantCount: completedAssistantMessages.count,
            smartRoutedCount: routed.count,
            routedSuccessCount: routedSuccess.count,
            nonRoutedSuccessCount: nonRoutedSuccess.count,
            routedAverageLatencyMs: averageInt(routedSuccess.compactMap { $0.metrics?.latencyMs }),
            nonRoutedAverageLatencyMs: averageInt(nonRoutedSuccess.compactMap { $0.metrics?.latencyMs }),
            routedAverageCostUSD: averageDouble(routedSuccess.compactMap { $0.metrics?.estimatedCostUSD }),
            nonRoutedAverageCostUSD: averageDouble(nonRoutedSuccess.compactMap { $0.metrics?.estimatedCostUSD })
        )
    }

    private static func isErrorMessage(_ message: Message) -> Bool {
        if message.itemId?.contains("|k:error|") == true { return true }
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("抱歉，发生了错误")
    }

    private static func averageInt(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private static func averageDouble(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
