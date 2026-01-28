//
//  SettingsView.swift
//  EasyAI
//
//  创建于 2026
//


import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @StateObject private var configManager = ConfigManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showDeleteConfirmation: Bool = false
    @State private var showModelSelector: Bool = false
    @State private var maxTokensText: String = ""
    @State private var apiKeyText: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - API 配置
                Section(header: Text("API 配置"), footer: Text("使用假数据模式时，将使用模拟响应，不需要 API Key。API Key 会安全存入 Keychain。")) {
                    Toggle("使用假数据模式", isOn: $configManager.useMockData)
                    
                    Toggle("启用流式响应", isOn: $configManager.enableStream)

                    Toggle("启用 Phase4 日志（turnId/itemId）", isOn: $configManager.enablePhase4Logs)

                    Picker("上下文策略", selection: $configManager.contextStrategy) {
                        ForEach(MessageContextStrategy.allCases) { strategy in
                            Text(strategy.title).tag(strategy)
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        showModelSelector = true
                    } label: {
                        HStack {
                            Text("选择模型")
                                .foregroundColor(.primary)
                            Spacer()
                            HStack(spacing: 6) {
                                ModelAvatarView(name: fullModelName, provider: modelProvider, size: 20)
                                Text(fullModelName)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        }
                    }

                    HStack {
                        Text("OpenRouter API Key")
                        Spacer()
                        SecureField("sk-or-v1-...", text: $apiKeyText)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 200)
                            .onChange(of: apiKeyText) { newValue in
                                SecretsStore.shared.apiKey = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                    }
                    
                    HStack {
                        Text("最大 Token 数")
                        Spacer()
                        TextField("1000", text: $maxTokensText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onAppear {
                                maxTokensText = String(configManager.maxTokens)
                            }
                            .onChange(of: maxTokensText) { newValue in
                                // 只允许数字输入
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue {
                                    maxTokensText = filtered
                                }
                                // 更新配置
                                if let value = Int(filtered), value > 0 {
                                    configManager.maxTokens = value
                                }
                            }
                            .onChange(of: configManager.maxTokens) { newValue in
                                // 当配置从外部改变时，同步文本
                                if maxTokensText != String(newValue) {
                                    maxTokensText = String(newValue)
                                }
                            }
                    }
                }
                
                // MARK: - 数据管理
                Section(header: Text("数据管理"), footer: Text("删除所有聊天消息，此操作无法撤销。")) {
                    Button(role: .destructive, action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("删除所有消息")
                        }
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        Task {
                            await viewModel.loadModels()
                            await MainActor.run {
                                dismiss()
                            }
                        }
                    }
                }
            }
            .onAppear {
                if apiKeyText.isEmpty {
                    apiKeyText = SecretsStore.shared.apiKey
                }
            }
            .sheet(isPresented: $showModelSelector) {
                ModelSelectorView(selectedModel: Binding(
                    get: { viewModel.selectedModel },
                    set: { viewModel.selectedModel = $0 }
                ))
                .environmentObject(viewModel)
            }
            .alert("确认删除", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    viewModel.clearMessages()
                }
            } message: {
                Text("确定要删除所有聊天消息吗？此操作无法撤销。")
            }
        }
    }

    private var fullModelName: String {
        guard let name = viewModel.selectedModel?.name, !name.isEmpty else {
            return "加载中..."
        }
        return name
    }

    private var modelProvider: ModelProvider {
        viewModel.selectedModel?.provider ?? .openrouter
    }

}

#Preview {
    SettingsView()
        .environmentObject(ChatViewModel())
}
