//
//  ChatView.swift
//  EasyAI
//
//  创建于 2026
//


import SwiftUI
import PhotosUI

struct ChatView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var showModelSelector: Bool = false
    @State private var showSettings: Bool = false
    @State private var showConversations: Bool = false
    @State private var isUserScrolling: Bool = false
    @State private var scrollTask: Task<Void, Never>?
    @State private var selectedImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var selectedImageMimeType: String?
    
    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color(red: 0.98, green: 0.99, blue: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 消息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // 空状态提示
                            if viewModel.messages.isEmpty {
                                VStack(spacing: 20) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 60))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    
                                    Text("开始与AI对话")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    Text("选择模型后，输入消息开始聊天")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 100)
                                .frame(maxWidth: .infinity)
                            }
                            
                            ForEach(viewModel.messages) { message in
                                MessageBubble(
                                    message: message,
                                    stopToken: viewModel.animationStopToken,
                                    onProgress: {
                                        // 只有在用户没有手动滚动时才自动滚动到底部
                                        guard !isUserScrolling else { return }
                                        
                                        // 实时滚动到底部，跟随打字机高度变化
                                        // 取消之前的滚动任务，确保只执行最新的滚动
                                        scrollTask?.cancel()
                                        
                                        // 使用很短的延迟（10ms）来批量处理频繁的更新，但保持实时性
                                        scrollTask = Task {
                                            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                                            guard !Task.isCancelled else { return }
                                            
                                            await MainActor.run {
                                                guard !isUserScrolling else { return }
                                                // 避免在视图更新期直接触发 scrollTo
                                                withAnimation(.linear(duration: 0.05)) {
                                                    proxy.scrollTo("bottomSpacer", anchor: .bottom)
                                                }
                                            }
                                        }
                                    },
                                    onContentUpdate: {
                                        // 助手气泡打字机动画完成后，允许再次发送
                                        if message.role == .assistant {
                                            viewModel.isTypingAnimating = false
                                        }
                                        // 动画完成后，如果用户没有在滚动，也滚动到底部
                                        if !isUserScrolling {
                                            withAnimation(.easeOut(duration: 0.3)) {
                                                proxy.scrollTo("bottomSpacer", anchor: .bottom)
                                            }
                                        }
                                    }
                                )
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }
                            
                            if viewModel.isLoading {
                                TypingIndicator()
                                    .transition(.opacity)
                            }
                            
                            // 底部占位视图，用于滚动时预留额外间距
                            // 高度设置为期望的底部间距，确保手动和自动滚动一致
                            Color.clear
                                .frame(height: 24)
                                .id("bottomSpacer")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        // 只设置顶部 padding，底部间距由 bottomSpacer 统一控制，确保手动和自动滚动一致
                    }
                    .disableScrollBounce() // 禁用回弹效果
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                // 用户开始拖拽时，标记为正在手动滚动
                                isUserScrolling = true
                            }
                            .onEnded { _ in
                                // 拖拽结束后，延迟一小段时间后重置状态
                                // 这样如果用户快速滚动后停止，可以恢复自动滚动
                                Task {
                                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                                    await MainActor.run {
                                        isUserScrolling = false
                                    }
                                }
                            }
                    )
                    .onChange(of: viewModel.messages.count) { _ in
                        if viewModel.messages.last != nil && !isUserScrolling {
                            // 新消息到达时，如果用户没有在滚动，自动滚动到底部
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("bottomSpacer", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.currentConversationId) { _ in
                        guard !isUserScrolling else { return }
                        // 切换会话后滚动到底部
                        DispatchQueue.main.async {
                            proxy.scrollTo("bottomSpacer", anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.isLoading) { _ in
                        if viewModel.isLoading && !isUserScrolling {
                            // loading 开始时，如果用户没有在滚动，自动滚动到底部
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("bottomSpacer", anchor: .bottom)
                            }
                        }
                    }
                }
                
                // 输入区域
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.gray.opacity(0.2))
                    
                    HStack(spacing: 12) {
                        // 图片选择按钮
                        photoPickerButton
                        
                        // 输入框
                        HStack(spacing: 8) {
                            // 显示选中的图片预览
                            if let selectedImage = selectedImage {
                                imagePreviewView(selectedImage)
                            }
                            
                            inputField
                            
                            if shouldShowClearButton {
                                clearTextButton
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        )
                        
                        // 发送按钮
                        sendButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Color(.systemBackground)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: -2)
                    )
                }
            }
        }
        .navigationTitle("EasyAI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button(action: {
                    showConversations = true
                }) {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // 设置按钮
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.primary)
                }
                
            }
        }
        .sheet(isPresented: $showModelSelector) {
            ModelSelectorView(selectedModel: Binding(
                get: { viewModel.selectedModel },
                set: { viewModel.selectedModel = $0 }
            ))
            .environmentObject(viewModel)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showConversations) {
            ConversationListView()
                .environmentObject(viewModel)
        }
        .onAppear {
            // 确保模型列表已加载
            if viewModel.availableModels.isEmpty {
                Task {
                    await viewModel.loadModels()
                }
            }
        }
    }
    
    // MARK: - 辅助视图
    
    @ViewBuilder
    private func imagePreviewView(_ image: UIImage) -> some View {
        HStack(spacing: 8) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Button(action: clearSelectedImage) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))
            }
        }
        .padding(.leading, 8)
    }
    
    private var clearTextButton: some View {
        Button(action: {
            inputText = ""
        }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 18))
        }
    }
    
    private var shouldShowClearButton: Bool {
        !inputText.isEmpty && selectedImage == nil
    }
    
    private func clearSelectedImage() {
        selectedImage = nil
        selectedImageData = nil
        selectedImageMimeType = nil
    }
    
    private var sendButton: some View {
        let gradientColors = isSendDisabled
        ? [Color.gray.opacity(0.3), Color.gray.opacity(0.3)]
        : [Color.blue, Color.purple]
        
        return Button(action: sendMessage) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .disabled(isSendDisabled)
        .animation(.easeInOut(duration: 0.2), value: isSendDisabled)
    }
    
    private var isSendDisabled: Bool {
        let textIsEmpty = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let noImage = selectedImage == nil
        let hasNoContent = textIsEmpty && noImage
        return hasNoContent || viewModel.isLoading || viewModel.isTypingAnimating
    }
    
    private func sendMessage() {
        // 文本和图片都为空，或当前正在加载 / 打字机动画中，都不发送
        guard !isSendDisabled else { return }
        
        let message = inputText
        let imageData = selectedImageData
        let imageMimeType = selectedImageMimeType
        
        // 清空输入和图片
        clearInput()
        
        Task {
            await viewModel.sendMessage(message, imageData: imageData, imageMimeType: imageMimeType)
        }
    }
    
    private func clearInput() {
        inputText = ""
        selectedImage = nil
        selectedImageData = nil
        selectedImageMimeType = nil
        isInputFocused = false
    }
    
    private var photoPickerButton: some View {
        Group {
            if #available(iOS 16.0, *) {
                PhotosPickerButton(
                    selectedImage: $selectedImage,
                    selectedImageData: $selectedImageData,
                    selectedImageMimeType: $selectedImageMimeType
                )
            } else {
                Button(action: {}) {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
                .disabled(true)
            }
        }
    }
    
    @ViewBuilder
    private var inputField: some View {
        if #available(iOS 16.0, *) {
            TextField("输入消息...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .onSubmit {
                    sendMessage()
                }
        } else {
            ZStack(alignment: .leading) {
                if inputText.isEmpty {
                    Text("输入消息...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                TextEditor(text: $inputText)
                    .font(.body)
                    .frame(minHeight: 20, maxHeight: 120)
                    .focused($isInputFocused)
            }
        }
    }
}

@available(iOS 16.0, *)
private struct PhotosPickerButton: View {
    @Binding var selectedImage: UIImage?
    @Binding var selectedImageData: Data?
    @Binding var selectedImageMimeType: String?
    @State private var selectedPhoto: PhotosPickerItem?
    
    var body: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            let iconName = selectedImage != nil ? "photo.fill" : "photo"
            let iconColor = selectedImage != nil ? Color.blue : Color.secondary
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
        }
        .onChange(of: selectedPhoto) { newItem in
            Task {
                guard let newItem = newItem else { return }
                guard let data = try? await newItem.loadTransferable(type: Data.self) else {
                    return
                }
                await MainActor.run {
                    selectedImageData = data
                    selectedImage = UIImage(data: data)
                    selectedImageMimeType = detectImageMimeType(data)
                }
            }
        }
    }
    
    private func detectImageMimeType(_ data: Data) -> String {
        let header = data.prefix(12)
        
        guard header.count >= 3 else {
            return "image/jpeg"
        }
        
        // JPEG: FF D8 FF
        if header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF {
            return "image/jpeg"
        }
        
        guard header.count >= 4 else {
            return "image/jpeg"
        }
        
        // PNG: 89 50 4E 47
        if header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47 {
            return "image/png"
        }
        
        // GIF: 47 49 46
        if header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46 {
            return "image/gif"
        }
        
        // WebP: 52 49 46 46
        if header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 {
            return "image/webp"
        }
        
        // 默认为 JPEG
        return "image/jpeg"
    }
}

struct MessageBubble: View {
    let message: Message
    let stopToken: UUID
    var onProgress: (() -> Void)?
    var onContentUpdate: (() -> Void)?
    
    /// 是否显示时间戳（助手消息在打字机完成后显示，用户消息立即显示）
    @State private var showTimestamp: Bool = false
    
    /// 单条气泡的最大宽度（屏幕宽度减去左右loading间距）
    /// loading左间距为60，左右都有，所以是 60*2 = 120
    private var maxBubbleWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    var isUser: Bool {
        message.role == .user
    }
    
    private var messageBackground: some View {
        Group {
            if isUser {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color(.systemGray6)
            }
        }
    }
    
    private var messageCorners: UIRectCorner {
        isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight]
    }
    
    private var messageShadowColor: Color {
        Color.black.opacity(isUser ? 0.15 : 0.05)
    }
    
    @ViewBuilder
    private var userMessageContent: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // 显示所有媒体内容（图片、视频等）
            ForEach(message.mediaContents) { media in
                if media.type == .image, let uiImage = UIImage(data: media.data) {
                    messageImageView(uiImage)
                } else {
                    // 其他媒体类型的占位符
                    MediaPlaceholderView(media: media)
                }
            }
            
            // 显示文本（如果有）
            if !message.content.isEmpty {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(.white)
            }
        }
    }
    
    private func messageImageView(_ uiImage: UIImage) -> some View {
        let maxImageWidth = min(maxBubbleWidth, 200)
        return Image(uiImage: uiImage)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: maxImageWidth, maxHeight: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
    
    private var timestampView: some View {
        Text(message.timestamp, style: .time)
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 60)
                
                // 用户发送的气泡：不需要打字机，只用普通 Text，自适应宽度，最多到 0.7 屏宽
                VStack(alignment: .trailing, spacing: 6) {
                    userMessageContent
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(messageBackground)
                        .cornerRadius(20, corners: messageCorners)
                        .shadow(color: messageShadowColor, radius: 8, x: 0, y: 2)
                        .frame(maxWidth: maxBubbleWidth, alignment: .trailing)
                    
                    if showTimestamp {
                        timestampView
                    }
                }
                .onAppear {
                    // 用户消息立即显示时间戳
                    showTimestamp = true
                }
            } else {
                // 助手气泡：与 loading 指示器左对齐
                VStack(alignment: .leading, spacing: 6) {
                    // Stream 模式或曾经是 stream 的消息：直接显示文本，不使用打字机效果
                    if message.isStreaming || message.wasStreamed {
                        Text(message.content)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(messageBackground)
                            .cornerRadius(20, corners: messageCorners)
                            .shadow(color: messageShadowColor, radius: 8, x: 0, y: 2)
                            .frame(maxWidth: maxBubbleWidth, alignment: .leading)
                            .onChange(of: message.content) { _ in
                                // Stream 模式下，内容更新时触发滚动
                                if message.isStreaming {
                                    onProgress?()
                                }
                            }
                            .onChange(of: message.isStreaming) { isStreaming in
                                // Stream 完成后，显示时间戳并触发更新回调
                                if !isStreaming {
                                    showTimestamp = true
                                    onContentUpdate?()
                                }
                            }
                            .onAppear {
                                // 如果消息已经完成 stream，立即显示时间戳
                                if !message.isStreaming && message.wasStreamed {
                                    showTimestamp = true
                                }
                            }
                    } else {
                        // 非 stream 模式，使用打字机效果
                        ChunkTypewriterTextView(
                            text: message.content,
                            chunkSize: 20,          // 每次增加大约 20 个字符
                            chunkDelay: 0.04,       // 块之间的停顿
                            onProgress: onProgress, // 打字机进度回调，用于实时滚动
                            onFinish: {
                                // 打字机动画完成后显示时间戳
                                showTimestamp = true
                                onContentUpdate?()
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(messageBackground)
                        .cornerRadius(20, corners: messageCorners)
                        .shadow(color: messageShadowColor, radius: 8, x: 0, y: 2)
                        .frame(maxWidth: maxBubbleWidth, alignment: .leading)
                    }
                    
                    // 显示时间戳（stream 完成后或打字机动画完成后）
                    if showTimestamp {
                        Text(message.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
                .frame(maxWidth: maxBubbleWidth, alignment: .leading)
                
                Spacer(minLength: 60)
            }
        }
        // 禁用内容变化的动画，避免因文本变长触发额外动画
        .animation(nil, value: message.content)
    }
}

// 打字指示器
struct TypingIndicator: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .offset(y: animationPhase == index ? -4 : 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(20, corners: [.topLeft, .topRight, .bottomRight])
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            
            Spacer(minLength: 60)
        }
        .id("loading")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// 扩展：自定义圆角
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - 媒体占位视图

/// 非图片媒体类型的占位符视图
struct MediaPlaceholderView: View {
    let media: MediaContent
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(media.type.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(media.fileSizeFormatted)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var iconName: String {
        switch media.type {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "music.note"
        case .pdf:
            return "doc.fill"
        case .document:
            return "doc.text.fill"
        }
    }
}


#Preview {
    NavigationView {
        ChatView()
            .environmentObject(ChatViewModel())
    }
}
