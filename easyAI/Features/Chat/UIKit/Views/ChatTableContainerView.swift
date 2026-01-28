//
//  ChatTableContainerView.swift
//  EasyAI
//
//  创建于 2026
//

import SwiftUI

struct ChatTableContainerView: UIViewControllerRepresentable {
    let viewModel: ChatListViewModel
    
    func makeUIViewController(context: Context) -> ChatTableViewController {
        let controller = ChatTableViewController()
        controller.bind(viewModel: viewModel)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ChatTableViewController, context: Context) {
        uiViewController.bind(viewModel: viewModel)
    }
}
