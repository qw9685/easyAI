//
//  ModelSelectorView.swift
//  EasyAI
//
//  Created by cc on 2026
//

import SwiftUI

struct ModelSelectorView: View {
    @Binding var selectedModel: AIModel?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    private let modelRepository: ModelRepositoryProtocol = ModelRepository.shared
    
    /// 判断是否已经有从 API 请求到的数据
    /// 如果 availableModels 不为空，说明已经请求过
    private var hasFetchedData: Bool {
        !viewModel.availableModels.isEmpty
    }
    
    var filteredModels: [AIModel] {
        if searchText.isEmpty {
            return viewModel.availableModels
        } else {
            return viewModel.availableModels.filter { model in
                model.name.localizedCaseInsensitiveContains(searchText) ||
                model.description.localizedCaseInsensitiveContains(searchText)
            }
        }
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
                if !hasFetchedData {
                    fetchModels()
                }
            }
        }
    }
    
    // MARK: - Main View Components
    
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
    
    private var searchBarBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var loadingView: some View {
        if isLoading {
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
        if let error = errorMessage {
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
                isSelected: isModelSelected(model)
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
        .disabled(isLoading)
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
        
        isLoading = true
        errorMessage = nil
        
        Task {
            let models = await modelRepository.fetchModels(filter: .all)

            await MainActor.run {
                if models.isEmpty && !hasFetchedData {
                    errorMessage = "无法加载在线模型列表，请检查网络连接或API配置"
                } else if models.isEmpty {
                    errorMessage = "刷新失败，显示已有数据"
                } else {
                    errorMessage = nil
                    viewModel.availableModels = models
                }
                isLoading = false
            }
        }
    }
}

struct ModelRow: View {
    let model: AIModel
    let isSelected: Bool
    let action: () -> Void
    
    var modelIcon: String {
        return "cpu"
    }
    
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
    
    // MARK: - Subviews
    
    private var modelIconView: some View {
        ZStack {
            Circle()
                .fill(iconGradient)
                .frame(width: 50, height: 50)
            
            Image(systemName: modelIcon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(isSelected ? .white : modelColor)
        }
        .frame(width: 50)
    }
    
    private var iconGradient: LinearGradient {
        let colors = isSelected 
            ? [modelColor, modelColor.opacity(0.7)]
            : [Color.gray.opacity(0.2), Color.gray.opacity(0.1)]
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var modelInfoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            modelNameAndModalities
            modelDescription
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
        HStack(spacing: 4) {
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
