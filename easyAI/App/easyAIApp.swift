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
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    
    init() {
        // 初始化配置管理器，确保配置被加载
        _ = ConfigManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ChatRootView()
                .environmentObject(chatViewModel)
                .environmentObject(themeManager)
        }
    }
}
