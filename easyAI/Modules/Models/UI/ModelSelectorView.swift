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
    @EnvironmentObject var viewModel: ChatViewModel
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
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.95, green: 0.97, blue: 1.0),
                Color(red: 0.98, green: 0.99, blue: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var scrollContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                searchBar
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
                .foregroundColor(.secondary)
            
            TextField("搜索模型...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(searchBarBackground)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("筛选")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(isFilterExpanded ? "收起" : "展开") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFilterExpanded.toggle()
                    }
                }
                .font(.caption)
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
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemGray6))
                )
        }
        .buttonStyle(.plain)
    }

    private func filterSection(title: String, options: [(key: String, label: String)], selection: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
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
                            .foregroundColor(isSelected ? .white : .primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.blue : Color(.systemGray6))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var searchBarBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var loadingView: some View {
        if viewModel.isLoadingModels {
            HStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                Text("正在加载模型列表...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                    .foregroundColor(.orange)
                Text("加载失败")
                    .font(.headline)
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("重试") {
                    fetchModels()
                }
                .buttonStyle(.borderedProminent)
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
    }
    
    private var doneButton: some View {
        Button("完成") {
            dismiss()
        }
        .fontWeight(.semibold)
    }
    
    private func fetchModels(forceRefresh: Bool = false) {
        // 如果不是强制刷新且已经有请求到的数据，就不再次请求
        if !forceRefresh && hasFetchedData {
            return
        }
        Task {
            await viewModel.loadModels(forceRefresh: forceRefresh)
        }
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
        return .gray
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
                .foregroundColor(.primary)
            
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
                .foregroundColor(.blue)
            Text("输入: \(formatModalities(model.inputModalities))")
                .font(.caption2)
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.blue.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private var outputModalityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
            Text("输出: \(formatModalities(model.outputModalities))")
                .font(.caption2)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.green.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private var modelDescription: some View {
        Text(model.description)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(2)
    }

    private var modelMetaView: some View {
        HStack(spacing: 12) {
            Text(priceText)
            Text(contextText)
        }
        .font(.caption2)
        .foregroundColor(.secondary)
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
                .foregroundColor(isFavorite ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
    }
    
    private var checkmarkGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemBackground))
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
    }
    
    private var shadowColor: Color {
        isSelected ? modelColor.opacity(0.3) : Color.black.opacity(0.05)
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
        isSelected ? 2 : 0
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
            colors: [modelColor.opacity(0.6), modelColor.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var clearBorderGradient: LinearGradient {
        LinearGradient(
            colors: [Color.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
