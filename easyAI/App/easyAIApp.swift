//
//  easyAIApp.swift
//  easyAI
//
//  创建于 2026
//  主要功能：
//  - 应用入口与依赖注入
//  - 初始化配置并加载根视图
//
//


import SwiftUI

@main
struct easyAIApp: App {
    private let chatViewModel: ChatViewModel
    @StateObject private var chatAdapter: ChatViewModelSwiftUIAdapter
    @StateObject private var themeManager = ThemeManager.shared

    init() {
        _ = ConfigManager.shared
        let viewModel = AppContainer.shared.makeChatViewModel()
        self.chatViewModel = viewModel
        _chatAdapter = StateObject(wrappedValue: ChatViewModelSwiftUIAdapter(viewModel: viewModel))
    }

    var body: some Scene {
        WindowGroup {
            ChatRootView(viewModel: chatViewModel)
                .environmentObject(chatAdapter)
                .environmentObject(themeManager)
        }
    }
}
