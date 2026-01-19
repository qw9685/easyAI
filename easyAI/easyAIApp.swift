//
//  easyAIApp.swift
//  easyAI
//
//  Created on 2024
//

import SwiftUI

@main
struct easyAIApp: App {
    @StateObject private var chatViewModel = ChatViewModel()
    
    init() {
        // 初始化配置管理器，确保配置被加载
        _ = ConfigManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ChatView()
                    .environmentObject(chatViewModel)
            }
        }
    }
}
