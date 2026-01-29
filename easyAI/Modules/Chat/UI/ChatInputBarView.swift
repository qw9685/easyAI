//
//  ChatInputBarView.swift
//  EasyAI
//
//  创建于 2026
//

import SwiftUI
import PhotosUI

struct ChatInputBarView: View {
    @ObservedObject var viewModel: ChatViewModel
    @StateObject private var input = ChatInputViewModel()
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.2))
            
            HStack(spacing: 12) {
                photoPickerButton
                
                HStack(spacing: 8) {
                    if let selectedImage = input.selectedImage {
                        imagePreviewView(selectedImage)
                    }
                    
                    inputField
                    
                    if input.shouldShowClearButton {
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

    private func clearSelectedImage() {
        input.clearSelectedImage()
    }
    
    private var clearTextButton: some View {
        Button(action: {
            input.clearText()
        }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 18))
        }
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
        input.isSendDisabled(isChatLoading: viewModel.isLoading, isTypingAnimating: viewModel.isTypingAnimating)
    }
    
    private func sendMessage() {
        guard !isSendDisabled else { return }
        input.send(chatViewModel: viewModel)
        isInputFocused = false
    }
    
    private var photoPickerButton: some View {
        Group {
            if #available(iOS 16.0, *) {
                PhotosPickerButton(input: input)
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
            TextField("输入消息...", text: $input.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .onSubmit {
                    sendMessage()
                }
        } else {
            ZStack(alignment: .leading) {
                if input.inputText.isEmpty {
                    Text("输入消息...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                TextEditor(text: $input.inputText)
                    .font(.body)
                    .frame(minHeight: 20, maxHeight: 120)
                    .focused($isInputFocused)
            }
        }
    }
}

@available(iOS 16.0, *)
private struct PhotosPickerButton: View {
    @ObservedObject var input: ChatInputViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    
    var body: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            let iconName = input.selectedImage != nil ? "photo.fill" : "photo"
            let iconColor = input.selectedImage != nil ? Color.blue : Color.secondary
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
                    input.setSelectedImageData(data)
                }
            }
        }
    }
}
