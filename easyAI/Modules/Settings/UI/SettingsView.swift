//
//  SettingsView.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 应用设置界面
//
//


import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: ChatViewModelSwiftUIAdapter
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var configManager = ConfigManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showDeleteConfirmation: Bool = false
    @State private var showModelSelector: Bool = false
    @State private var showTtsSettings: Bool = false
    @State private var maxTokensText: String = ""
    @State private var apiKeyText: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("外观"), footer: Text("主色调将立即应用到所有页面。")) {
                    Picker("主色调", selection: $themeManager.selection) {
                        ForEach(ThemeOption.allCases) { option in
                            Text(option.name).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
                // MARK: - API 配置
                Section(header: Text("API 配置"), footer: Text("使用假数据模式时，将使用模拟响应，不需要 API Key。API Key 会安全存入 Keychain。")) {
                    Toggle("使用假数据模式", isOn: $configManager.useMockData)
                    
                    Toggle("启用流式响应", isOn: $configManager.enableStream)

                    Toggle("启用打字机", isOn: $configManager.enableTypewriter)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("打字机速度")
                            Spacer()
                            Text(String(format: "%.1fx", configManager.typewriterSpeed))
                                .foregroundColor(AppThemeSwift.textSecondary)
                        }
                        Slider(value: $configManager.typewriterSpeed, in: 0.1...8.0, step: 0.1)
                            .tint(AppThemeSwift.accent)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("打字机刷新率")
                            Spacer()
                            Text("\(Int(configManager.typewriterRefreshRate)) fps")
                                .foregroundColor(AppThemeSwift.textSecondary)
                        }
                        Slider(value: $configManager.typewriterRefreshRate, in: 5...120, step: 5)
                            .tint(AppThemeSwift.accent)
                    }

                    Toggle("启用 phase 日志（turnId/itemId）", isOn: $configManager.enablephaseLogs)

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
                                .foregroundColor(AppThemeSwift.textPrimary)
                            Spacer()
                            HStack(spacing: 6) {
                                ModelAvatarView(name: fullModelName, provider: modelProvider, size: 20)
                                Text(fullModelName)
                            }
                            .font(.caption)
                            .foregroundColor(AppThemeSwift.textSecondary)
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

                // MARK: - 语音朗读增强
                Section(header: Text("语音朗读增强"), footer: Text("配置音色、语速、音高与语音对话模式。")) {
                    Button {
                        showTtsSettings = true
                    } label: {
                        HStack {
                            Text("语音朗读设置")
                                .foregroundColor(AppThemeSwift.textPrimary)
                            Spacer()
                            Text(ttsSummary)
                                .font(.caption)
                                .foregroundColor(AppThemeSwift.textSecondary)
                                .lineLimit(1)
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
                    .disabled(viewModel.conversations.isEmpty)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(AppThemeSwift.backgroundGradient)
            .tint(AppThemeSwift.accent)
            .listRowBackground(AppThemeSwift.surface)
            .listRowSeparatorTint(AppThemeSwift.border)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        viewModel.dispatch(.loadModels(forceRefresh: false))
                        dismiss()
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
                .environmentObject(ThemeManager.shared)
            }
            .sheet(isPresented: $showTtsSettings) {
                TextToSpeechSettingsView()
                    .environmentObject(ThemeManager.shared)
            }
            .alert("确认删除", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    viewModel.dispatch(.clearMessages)
                }
            } message: {
                Text("确定要删除所有聊天消息吗？此操作无法撤销。")
            }
        }
        .id(themeManager.selection)
        .preferredColorScheme(.light)
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

    private var ttsSummary: String {
        let voiceName = TextToSpeechSettingsView.displayName(for: configManager.ttsVoiceIdentifier)
        return "\(voiceName) · 语速 \(String(format: "%.2f", configManager.ttsRate)) · 音高 \(String(format: "%.2f", configManager.ttsPitch))"
    }

}

#Preview {
    SettingsView()
        .environmentObject(ChatViewModelSwiftUIAdapter(viewModel: ChatViewModel()))
        .environmentObject(ThemeManager.shared)
}
