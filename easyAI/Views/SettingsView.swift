//
//  SettingsView.swift
//  EasyAI
//
//  Created on 2024
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @StateObject private var configManager = ConfigManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showDeleteConfirmation: Bool = false
    @State private var maxTokensText: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - API 配置
                Section(header: Text("API 配置"), footer: Text("使用假数据模式时，将使用模拟响应，不需要 API Key。流式响应可以实时显示 AI 回复内容。")) {
                    Toggle("使用假数据模式", isOn: $configManager.useMockData)
                    
                    Toggle("启用流式响应", isOn: $configManager.enableStream)

                    Toggle("启用 Phase4 日志（turnId/itemId）", isOn: $configManager.enablePhase4Logs)
                    
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
                        dismiss()
                    }
                }
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
}

#Preview {
    SettingsView()
        .environmentObject(ChatViewModel())
}
