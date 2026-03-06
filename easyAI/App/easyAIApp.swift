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
    init() {
        if !Self.isRunningUnitTests {
            _ = ConfigManager.shared
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if Self.isRunningUnitTests {
                    EmptyView()
                } else {
                    AppBootstrapView()
                }
            }
        }
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}

private struct AppBootstrapView: View {
    private let chatViewModel: ChatViewModel
    @StateObject private var chatAdapter: ChatViewModelSwiftUIAdapter
    @StateObject private var themeManager = ThemeManager.shared

    init(container: AppContainer = .shared) {
        let viewModel = container.makeChatViewModel()
        self.chatViewModel = viewModel
        _chatAdapter = StateObject(
            wrappedValue: ChatViewModelSwiftUIAdapter(
                viewModel: viewModel,
                conversationSearchUseCase: container.makeConversationSearchUseCase()
            )
        )
    }

    var body: some View {
        ChatRootView(viewModel: chatViewModel)
            .environmentObject(chatAdapter)
            .environmentObject(themeManager)
    }
}
