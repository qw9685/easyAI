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
    let viewModel: ChatViewModel
    @EnvironmentObject var adapter: ChatViewModelSwiftUIAdapter

    func makeUIViewController(context: Context) -> UIViewController {
        MainPagerViewController(viewModel: viewModel, swiftUIAdapter: adapter)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 无需更新
    }
}
