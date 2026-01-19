//
//  ChatView.swift
//  EasyAI
//
//  Created on 2024
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var showModelSelector: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if viewModel.isLoading {
                            HStack {
                                ProgressView()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    // 禁用因消息数量变化带来的整体布局动画，避免列表高度变化时“抖一下”
                    .animation(nil, value: viewModel.messages.count)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        // 使用无动画的方式滚动到底部，避免在高度变化时产生额外的动画抖动
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            // 输入区域
            HStack(spacing: 12) {
                TextField("输入消息...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(inputText.isEmpty ? Color.gray : Color.blue)
                        .clipShape(Circle())
                }
                .disabled(inputText.isEmpty || viewModel.isLoading)
            }
            .padding()
        }
        .navigationTitle("EasyAI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showModelSelector = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                        Text(viewModel.selectedModel.name)
                            .font(.caption)
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.clearMessages()
                }) {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $showModelSelector) {
            ModelSelectorView(selectedModel: $viewModel.selectedModel)
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let message = inputText
        inputText = ""
        isInputFocused = false
        
        Task {
            await viewModel.sendMessage(message)
        }
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == .assistant {
                bubbleView
                Spacer(minLength: 50)
            } else {
                Spacer(minLength: 50)
                bubbleView
            }
        }
        // 整行固定在左 / 右，避免内容变长时整行重新对齐导致闪动
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        // 禁用因内容变化带来的隐式布局动画
        .animation(nil, value: message.content)
    }
    
    private var bubbleView: some View {
        VStack(
            alignment: message.role == .user ? .trailing : .leading,
            spacing: 4
        ) {
            Text(message.content)
                .fixedSize(horizontal: false, vertical: true) // 高度根据内容增长，避免多次测量导致跳变
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(message.role == .user ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(message.role == .user ? .white : .primary)
                .cornerRadius(16)
                .multilineTextAlignment(message.role == .user ? .trailing : .leading)
            
            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(ChatViewModel())
}

