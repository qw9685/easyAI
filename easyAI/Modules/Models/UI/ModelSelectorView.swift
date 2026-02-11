//
//  ModelSelectorView.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 模型选择与筛选界面
//
//


import SwiftUI
import Foundation

struct ModelSelectorView: View {
    @Binding var selectedModel: AIModel?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: ChatViewModelSwiftUIAdapter
    @EnvironmentObject var themeManager: ThemeManager
    @State private var searchText: String = ""
    @State private var selectedInputFilters: Set<String> = []
    @State private var selectedOutputFilters: Set<String> = []
    @State private var isFilterExpanded: Bool = false
    @State private var favoriteModelIds: Set<String> = []
    @State private var isFreeOnly: Bool = false
    @State private var isFavoritesOnly: Bool = false
    
    /// 判断是否已经有从 API 请求到的数据
    /// 如果 availableModels 不为空，说明已经请求过
    private var hasFetchedData: Bool {
        !viewModel.availableModels.isEmpty
    }
    
    var filteredModels: [AIModel] {
        if searchText.isEmpty {
            return applyFilters(to: viewModel.availableModels)
        } else {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.isEmpty {
                return applyFilters(to: viewModel.availableModels)
            }
            let searched = viewModel.availableModels.filter { model in
                let inputTokens = formatModalities(model.inputModalities)
                let outputTokens = formatModalities(model.outputModalities)
                return model.name.localizedCaseInsensitiveContains(query) ||
                model.description.localizedCaseInsensitiveContains(query) ||
                inputTokens.localizedCaseInsensitiveContains(query) ||
                outputTokens.localizedCaseInsensitiveContains(query)
            }
            return applyFilters(to: searched)
        }
    }

    /// 格式化输入/输出类型显示
    private func formatModalities(_ modalities: [String]) -> String {
        let localized: [String: String] = [
            "text": "文本",
            "image": "图片",
            "file": "文件",
            "audio": "音频",
            "video": "视频",
            "embeddings": "向量"
        ]
        return modalities.map { localized[$0.lowercased()] ?? $0.capitalized }.joined(separator: ", ")
    }

    private func applyFilters(to models: [AIModel]) -> [AIModel] {
        let inputFilters = selectedInputFilters
        let outputFilters = selectedOutputFilters

        let favorites = favoriteModelIds
        let freeOnly = isFreeOnly
        let favoritesOnly = isFavoritesOnly
        let filtered = models.filter { model in
            if !inputFilters.isEmpty {
                let inputs = Set(model.inputModalities.map { $0.lowercased() })
                if inputFilters.isDisjoint(with: inputs) {
                    return false
                }
            }
            if !outputFilters.isEmpty {
                let outputs = Set(model.outputModalities.map { $0.lowercased() })
                if outputFilters.isDisjoint(with: outputs) {
                    return false
                }
            }
            if freeOnly && !model.isFree {
                return false
            }
            if favoritesOnly && !favorites.contains(model.id) {
                return false
            }
            return true
        }
        return filtered.sorted { lhs, rhs in
            let lhsFavorite = favorites.contains(lhs.id)
            let rhsFavorite = favorites.contains(rhs.id)
            if lhsFavorite != rhsFavorite {
                return lhsFavorite && !rhsFavorite
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var inputFilterOptions: [(key: String, label: String)] {
        [
            ("text", "文本"),
            ("image", "图片"),
            ("file", "文件"),
            ("audio", "音频"),
            ("video", "视频")
        ]
    }

    private var outputFilterOptions: [(key: String, label: String)] {
        [
            ("text", "文本"),
            ("image", "图片"),
            ("embeddings", "向量")
        ]
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                scrollContent
            }
            .navigationTitle("选择AI模型")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppThemeSwift.accent)
            .id(themeManager.selection)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    refreshButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    doneButton
                }
            }
            .onAppear {
                favoriteModelIds = Set(AppConfig.favoriteModelIds)
                if !hasFetchedData {
                    fetchModels()
                }
            }
        }
    }
    
    // MARK: - 主要视图组件
    
    private var backgroundGradient: some View {
        AppThemeSwift.backgroundGradient
            .ignoresSafeArea()
    }
    
    private var scrollContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                searchBar
                recentStatsCard
                routingStatsCard
                providerStatsCard
                filterPanel
                loadingView
                errorView
                modelList
            }
            .padding(.vertical, 8)
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppThemeSwift.textTertiary)
            
            TextField("搜索模型...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(searchBarBackground)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var recentStatsCard: some View {
        let stats = viewModel.recentAssistantStats
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("最近对话统计")
                    .font(.subheadline)
                    .foregroundColor(AppThemeSwift.textPrimary)
                Spacer()
                Text("近\(stats.windowSize)轮")
                    .font(.caption)
                    .foregroundColor(AppThemeSwift.textTertiary)
            }

            if stats.hasSamples {
                HStack(spacing: 10) {
                    metricChip(title: "样本", value: "\(stats.sampleCount)")
                    metricChip(title: "平均耗时", value: formatLatency(stats.averageLatencyMs))
                    metricChip(title: "平均成本", value: formatCost(stats.averageCostUSD))
                    metricChip(title: "平均Token", value: formatTokens(stats.averageTokens))
                }

                Text("含指标样本：\(stats.metricsSampleCount)")
                    .font(.caption2)
                    .foregroundColor(AppThemeSwift.textTertiary)
            } else {
                Text("暂无可统计的助手回复，发送几轮后会自动显示。")
                    .font(.caption)
                    .foregroundColor(AppThemeSwift.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppThemeSwift.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppThemeSwift.border, lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }



    private var routingStatsCard: some View {
        let stats = viewModel.routingEffectStats
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("智能路由效果")
                    .font(.subheadline)
                    .foregroundColor(AppThemeSwift.textPrimary)
                Spacer()
                Text("P1")
                    .font(.caption)
                    .foregroundColor(AppThemeSwift.textTertiary)
            }

            if stats.hasSamples {
                HStack(spacing: 10) {
                    metricChip(title: "命中率", value: formatPercent(stats.smartHitRate))
                    metricChip(title: "命中后成功率", value: formatPercent(stats.routedSuccessRate))
                    metricChip(title: "平均耗时变化", value: formatLatencyDelta(stats.latencyDeltaMs))
                    metricChip(title: "平均成本变化", value: formatCostDelta(stats.costDeltaUSD))
                }

                Text("样本：\(stats.totalCompletedAssistantCount)（路由命中 \(stats.smartRoutedCount)）")
                    .font(.caption2)
                    .foregroundColor(AppThemeSwift.textTertiary)
            } else {
                Text("暂无路由效果数据，开启智能路由并发送几轮后自动显示。")
                    .font(.caption)
                    .foregroundColor(AppThemeSwift.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppThemeSwift.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppThemeSwift.border, lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }

    private var providerStatsCard: some View {
        let stats = viewModel.providerStats
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Provider 统计")
                    .font(.subheadline)
                    .foregroundColor(AppThemeSwift.textPrimary)
                Spacer()
                if !stats.isEmpty {
                    Button("清空") {
                        viewModel.clearProviderStats()
                    }
                    .font(.caption)
                    .foregroundColor(AppThemeSwift.accent)
                    .buttonStyle(.plain)
                }
                Text("累计")
                    .font(.caption)
                    .foregroundColor(AppThemeSwift.textTertiary)
            }

            if stats.isEmpty {
                Text("暂无 Provider 统计数据，发送几轮后会自动累计。")
                    .font(.caption)
                    .foregroundColor(AppThemeSwift.textSecondary)
            } else {
                ForEach(stats, id: \.providerId) { item in
                    providerStatsRow(item)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppThemeSwift.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppThemeSwift.border, lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }

    private func providerStatsRow(_ item: ProviderStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(providerDisplayName(item.providerId))
                    .font(.caption)
                    .foregroundColor(AppThemeSwift.textPrimary)
                Spacer()
                Text("成功率 \(formatPercent(item.successRate))")
                    .font(.caption2)
                    .foregroundColor(AppThemeSwift.textSecondary)
            }

            HStack(spacing: 8) {
                metricChip(title: "请求", value: "\(item.requestCount)")
                metricChip(title: "均耗时", value: formatLatency(item.averageLatencyMs))
                metricChip(title: "均成本", value: formatCost(item.averageCostUSD))
                metricChip(title: "均Token", value: formatTokens(item.averageTokens))
            }

            let errorSummary = providerErrorSummary(item)
            if !errorSummary.isEmpty {
                Text(errorSummary)
                    .font(.caption2)
                    .foregroundColor(AppThemeSwift.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    private func providerErrorSummary(_ item: ProviderStats) -> String {
        let rateLimited = item.errorCount(for: .rateLimited)
        let timeout = item.errorCount(for: .timeout)
        let unavailable = item.errorCount(for: .serverUnavailable)
        let contextTooLong = item.errorCount(for: .contextTooLong)
        let lowCredits = item.errorCount(for: .insufficientCredits)

        var parts: [String] = []
        if rateLimited > 0 { parts.append("限流 \(rateLimited)") }
        if timeout > 0 { parts.append("超时 \(timeout)") }
        if unavailable > 0 { parts.append("服务不可用 \(unavailable)") }
        if contextTooLong > 0 { parts.append("上下文超限 \(contextTooLong)") }
        if lowCredits > 0 { parts.append("余额不足 \(lowCredits)") }
        return parts.joined(separator: " · ")
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(AppThemeSwift.textTertiary)
            Text(value)
                .font(.caption)
                .foregroundColor(AppThemeSwift.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(AppThemeSwift.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatLatency(_ latencyMs: Int?) -> String {
        guard let latencyMs else { return "--" }
        if latencyMs < 1000 {
            return "\(latencyMs)ms"
        }
        let seconds = Double(latencyMs) / 1000
        return String(format: "%.2fs", seconds)
    }

    private func formatCost(_ cost: Double?) -> String {
        guard let cost else { return "--" }
        if cost < 0.0001 {
            return "<$0.0001"
        }
        return String(format: "$%.4f", cost)
    }

    private func formatTokens(_ tokens: Int?) -> String {
        guard let tokens else { return "--" }
        return "\(tokens)"
    }



    private func formatLatencyDelta(_ deltaMs: Int?) -> String {
        guard let deltaMs else { return "--" }
        if deltaMs == 0 { return "0ms" }
        let sign = deltaMs > 0 ? "+" : ""
        if abs(deltaMs) < 1000 {
            return "\(sign)\(deltaMs)ms"
        }
        let seconds = Double(deltaMs) / 1000
        return String(format: "%@%.2fs", sign, seconds)
    }

    private func formatCostDelta(_ delta: Double?) -> String {
        guard let delta else { return "--" }
        if abs(delta) < 0.0001 {
            return "$0.0000"
        }
        let sign = delta > 0 ? "+" : ""
        return String(format: "%@$%.4f", sign, delta)
    }

    private func formatPercent(_ ratio: Double) -> String {
        let percentage = max(0, min(100, ratio * 100))
        return String(format: "%.1f%%", percentage)
    }

    private func providerDisplayName(_ providerId: String) -> String {
        switch providerId.lowercased() {
        case ModelProvider.openrouter.rawValue:
            return "OpenRouter"
        default:
            return providerId
        }
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("筛选")
                    .font(.subheadline)
                    .foregroundColor(AppThemeSwift.textSecondary)
                Spacer()
                Button(isFilterExpanded ? "收起" : "展开") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFilterExpanded.toggle()
                    }
                }
                .font(.caption)
                .foregroundColor(AppThemeSwift.textSecondary)
            }

            if isFilterExpanded {
                filterSection(title: "输入", options: inputFilterOptions, selection: $selectedInputFilters)
                filterSection(title: "输出", options: outputFilterOptions, selection: $selectedOutputFilters)
                filterToggleRow

                if !selectedInputFilters.isEmpty || !selectedOutputFilters.isEmpty || isFreeOnly || isFavoritesOnly {
                    Button("清除筛选") {
                        selectedInputFilters.removeAll()
                        selectedOutputFilters.removeAll()
                        isFreeOnly = false
                        isFavoritesOnly = false
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppThemeSwift.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppThemeSwift.border, lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }

    private var filterToggleRow: some View {
        HStack(spacing: 10) {
            filterChip(title: "仅免费", isSelected: isFreeOnly) {
                isFreeOnly.toggle()
            }
            filterChip(title: "仅收藏", isSelected: isFavoritesOnly) {
                isFavoritesOnly.toggle()
            }
            Spacer()
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .foregroundColor(isSelected ? .white : AppThemeSwift.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? AppThemeSwift.accent : AppThemeSwift.surfaceAlt)
                )
        }
        .buttonStyle(.plain)
    }

    private func filterSection(title: String, options: [(key: String, label: String)], selection: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppThemeSwift.textSecondary)
            let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(options, id: \.key) { option in
                    let isSelected = selection.wrappedValue.contains(option.key)
                    Button {
                        if isSelected {
                            selection.wrappedValue.remove(option.key)
                        } else {
                            selection.wrappedValue.insert(option.key)
                        }
                    } label: {
                        Text(option.label)
                            .font(.caption)
                            .foregroundColor(isSelected ? .white : AppThemeSwift.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? AppThemeSwift.accent : AppThemeSwift.surfaceAlt)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var searchBarBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AppThemeSwift.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppThemeSwift.border, lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
    
    @ViewBuilder
    private var loadingView: some View {
        if viewModel.isLoadingModels {
            HStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                Text("正在加载模型列表...")
                    .font(.subheadline)
                    .foregroundColor(AppThemeSwift.textSecondary)
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var errorView: some View {
        if let error = viewModel.modelListState.errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundColor(AppThemeSwift.accent)
                Text("加载失败")
                    .font(.headline)
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(AppThemeSwift.textSecondary)
                    .multilineTextAlignment(.center)
                Button("重试") {
                    fetchModels()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppThemeSwift.accent)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
    
    private var modelList: some View {
        ForEach(filteredModels) { model in
            ModelRow(
                model: model,
                isSelected: isModelSelected(model),
                isFavorite: favoriteModelIds.contains(model.id),
                onToggleFavorite: {
                    toggleFavorite(model)
                }
            ) {
                selectModel(model)
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func isModelSelected(_ model: AIModel) -> Bool {
        model.id == selectedModel?.id ?? ""
    }
    
    private func selectModel(_ model: AIModel) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedModel = model
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
        }
    }
    
    private var refreshButton: some View {
        Button(action: {
            fetchModels(forceRefresh: true)
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 16, weight: .medium))
        }
        .disabled(viewModel.isLoadingModels)
        .buttonStyle(.plain)
    }
    
    private var doneButton: some View {
        Button("完成") {
            dismiss()
        }
        .fontWeight(.semibold)
        .buttonStyle(.plain)
    }
    
    private func fetchModels(forceRefresh: Bool = false) {
        // 如果不是强制刷新且已经有请求到的数据，就不再次请求
        if !forceRefresh && hasFetchedData {
            return
        }
        viewModel.dispatch(.loadModels(forceRefresh: forceRefresh))
    }

    private func toggleFavorite(_ model: AIModel) {
        if favoriteModelIds.contains(model.id) {
            favoriteModelIds.remove(model.id)
        } else {
            favoriteModelIds.insert(model.id)
        }
        AppConfig.favoriteModelIds = Array(favoriteModelIds)
    }
}

struct ModelRow: View {
    let model: AIModel
    let isSelected: Bool
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let action: () -> Void
    
    var modelColor: Color {
        return AppThemeSwift.accent
    }
    
    /// 格式化输入/输出类型显示
    private func formatModalities(_ modalities: [String]) -> String {
        let localized: [String: String] = [
            "text": "文本",
            "image": "图片",
            "file": "文件",
            "audio": "音频",
            "video": "视频",
            "embeddings": "向量"
        ]
        return modalities.map { localized[$0.lowercased()] ?? $0.capitalized }.joined(separator: ", ")
    }

    var body: some View {
        Button(action: action) {
            contentView
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var contentView: some View {
        HStack(alignment: .center, spacing: 16) {
            modelIconView
            modelInfoView
            favoriteButton
            selectionIndicator
        }
        .padding(16)
        .background(backgroundView)
        .overlay(borderOverlay)
        .scaleEffect(scaleValue)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var scaleValue: CGFloat {
        isSelected ? 1.02 : 1.0
    }
    
    // MARK: - 子视图
    
    private var modelIconView: some View {
        ZStack {
            ModelAvatarView(name: model.name, provider: model.provider, size: 50)
        }
    }
    
    private var modelInfoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            modelNameAndModalities
            modelDescription
            modelMetaView
        }
        .layoutPriority(1)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }
    
    private var modelNameAndModalities: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.name)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(AppThemeSwift.textPrimary)
            
            modalitiesView
        }
    }
    
    @ViewBuilder
    private var modalitiesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !model.inputModalities.isEmpty {
                inputModalityBadge
            }
            
            if !model.outputModalities.isEmpty {
                outputModalityBadge
            }
        }
    }
    
    private var inputModalityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.caption2)
                .foregroundColor(AppThemeSwift.accent)
            Text("输入: \(formatModalities(model.inputModalities))")
                .font(.caption2)
                .foregroundColor(AppThemeSwift.accent)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(AppThemeSwift.accent.opacity(0.12))
        .clipShape(Capsule())
    }
    
    private var outputModalityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.caption2)
                .foregroundColor(AppThemeSwift.accent2)
            Text("输出: \(formatModalities(model.outputModalities))")
                .font(.caption2)
                .foregroundColor(AppThemeSwift.accent2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(AppThemeSwift.accent2.opacity(0.12))
        .clipShape(Capsule())
    }
    
    private var modelDescription: some View {
        Text(model.description)
            .font(.subheadline)
            .foregroundColor(AppThemeSwift.textSecondary)
            .lineLimit(2)
    }

    private var modelMetaView: some View {
        HStack(spacing: 12) {
            Text(priceText)
            Text(contextText)
        }
        .font(.caption2)
        .foregroundColor(AppThemeSwift.textTertiary)
    }

    private var priceText: String {
        if model.isFree {
            return "免费"
        }
        guard let pricing = model.pricing else {
            return "价格未知"
        }
        let prompt = pricing.prompt ?? "?"
        let completion = pricing.completion ?? "?"
        return "输入 $\(prompt) / 输出 $\(completion)"
    }

    private var contextText: String {
        guard let contextLength = model.contextLength, contextLength > 0 else {
            return "上下文未知"
        }
        if contextLength >= 1000 {
            let kilo = Double(contextLength) / 1000.0
            let formatted = String(format: "%.0fK", kilo)
            return "上下文 \(formatted)"
        }
        return "上下文 \(contextLength)"
    }
    
    private var selectionIndicator: some View {
        HStack(spacing: 0) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(checkmarkGradient)
                    .font(.system(size: 18))
                    .transition(.scale.combined(with: .opacity))
            } else {
                Color.clear
                    .frame(width: 18, height: 18)
            }
        }
        .frame(width: 18, height: 18)
        .padding(.trailing, 16)
        .layoutPriority(0)
    }

    private var favoriteButton: some View {
        Button(action: onToggleFavorite) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 16))
                .foregroundColor(isFavorite ? AppThemeSwift.accent : AppThemeSwift.textTertiary)
        }
        .buttonStyle(.plain)
    }
    
    private var checkmarkGradient: LinearGradient {
        LinearGradient(
            colors: [AppThemeSwift.accent, AppThemeSwift.accent2],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(AppThemeSwift.surface)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
    }
    
    private var shadowColor: Color {
        isSelected ? modelColor.opacity(0.18) : Color.black.opacity(0.04)
    }
    
    private var shadowRadius: CGFloat {
        isSelected ? 12.0 : 8.0
    }
    
    private var shadowY: CGFloat {
        isSelected ? 4.0 : 2.0
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(borderGradient, lineWidth: borderWidth)
    }
    
    private var borderWidth: CGFloat {
        isSelected ? 1.5 : 0.8
    }
    
    private var borderGradient: LinearGradient {
        if isSelected {
            return selectedBorderGradient
        } else {
            return clearBorderGradient
        }
    }
    
    private var selectedBorderGradient: LinearGradient {
        LinearGradient(
            colors: [modelColor.opacity(0.7), modelColor.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var clearBorderGradient: LinearGradient {
        LinearGradient(
            colors: [AppThemeSwift.border],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
