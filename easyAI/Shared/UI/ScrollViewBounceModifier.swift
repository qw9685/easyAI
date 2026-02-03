//
//  ScrollViewBounceModifier.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - SwiftUI 滚动回弹控制
//
//


import SwiftUI
import UIKit

/// 禁用 ScrollView 回弹效果的 ViewModifier
struct DisableScrollBounceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ScrollViewBounceDisabler())
    }
}

private struct ScrollViewBounceDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        // 延迟执行，确保视图已经添加到视图层次结构中
        DispatchQueue.main.async {
            self.disableBounce(in: view)
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 每次更新时也尝试禁用回弹
        DispatchQueue.main.async {
            self.disableBounce(in: uiView)
        }
    }
    
    private func disableBounce(in view: UIView) {
        // 向上遍历视图层次结构查找 UIScrollView
        var current: UIView? = view.superview
        var maxDepth = 10 // 限制查找深度，避免无限循环
        
        while current != nil && maxDepth > 0 {
            if let scrollView = current as? UIScrollView {
                scrollView.bounces = false
                break
            }
            current = current?.superview
            maxDepth -= 1
        }
    }
}

extension View {
    func disableScrollBounce() -> some View {
        modifier(DisableScrollBounceModifier())
    }
}

