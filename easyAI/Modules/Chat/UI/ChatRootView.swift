//
//  ChatRootView.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - SwiftUI 包装 UIKit 导航栈
//  - 作为聊天根视图入口
//
//

import SwiftUI

struct ChatRootView: UIViewControllerRepresentable {
    @EnvironmentObject var viewModel: ChatViewModel
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = ChatViewController(viewModel: viewModel)
        return UINavigationController(rootViewController: controller)
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // 无需更新
    }
}
