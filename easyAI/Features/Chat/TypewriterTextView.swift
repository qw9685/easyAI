
//
//  TypewriterTextKitView.swift
//  EasyAI
//

import SwiftUI
import UIKit

/// 按块（句子/固定长度）逐步显示的打字机，避免频繁重排导致行尾跳行。
struct ChunkTypewriterTextView: View {
    let text: String
    /// 每一"块"的最小长度（字符数），可根据需要调大一点
    let chunkSize: Int
    /// 两块之间的间隔（秒）
    let chunkDelay: Double
    /// 进度回调（每次更新可见长度时调用）
    let onProgress: (() -> Void)?
    /// 结束回调
    let onFinish: (() -> Void)?
    
    @State private var visibleLength: Int = 0
    @State private var animationTask: Task<Void, Never>?
    
    var body: some View {
        UILabelTextView(text: String(text.prefix(visibleLength)))
        .onAppear {
            // 只在首次出现时开始动画
            if visibleLength == 0 && animationTask == nil {
                animationTask = Task {
                    await playChunks()
                }
            }
        }
        .onChange(of: text) { newText in
            // 文本变化时，取消旧任务并重新开始
            animationTask?.cancel()
            visibleLength = 0
            animationTask = Task {
                await playChunks()
            }
        }
        .onDisappear {
            // 视图消失时取消任务
            animationTask?.cancel()
        }
    }
    
    private func nextChunkEnd(from current: Int) -> Int {
        let chars = Array(text)
        let total = chars.count
        guard current < total else { return total }
        
        // 至少走 chunkSize 个字符
        var idx = min(current + chunkSize, total)
        
        // 尝试往后扩一点点，直到最近的空格/标点，尽量在“合理的断点”停下
        let breakChars: Set<Character> = [" ", "，", "。", "！", "？", ".", ",", "!", "?", ";", "；", "\n"]
        while idx < total && !breakChars.contains(chars[idx]) && idx - current < chunkSize * 2 {
            idx += 1
        }
        return idx
    }
    
    private func playChunks() async {
        await MainActor.run { visibleLength = 0 }
        
        guard !text.isEmpty else {
            await MainActor.run { onFinish?() }
            return
        }
        
        var current = 0
        while current < text.count {
            let end = nextChunkEnd(from: current)
            await MainActor.run {
                visibleLength = end
                onProgress?() // 每次更新时触发进度回调，用于滚动到底部
            }
            current = end
            
            if current >= text.count { break }
            try? await Task.sleep(nanoseconds: UInt64(chunkDelay * 1_000_000_000))
        }
        
        await MainActor.run { onFinish?() }
    }
}

private struct UILabelTextView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.dataDetectorTypes = [.link, .phoneNumber, .address]
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = UIColor.label
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
            uiView.invalidateIntrinsicContentSize()
        }
    }
}
