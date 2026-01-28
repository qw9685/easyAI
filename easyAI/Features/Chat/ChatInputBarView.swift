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
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var selectedImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var selectedImageMimeType: String?
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.2))
            
            HStack(spacing: 12) {
                photoPickerButton
                
                HStack(spacing: 8) {
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
        guard !isSendDisabled else { return }
        
        let message = inputText
        let imageData = selectedImageData
        let imageMimeType = selectedImageMimeType
        
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
        
        if header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF {
            return "image/jpeg"
        }
        
        guard header.count >= 4 else {
            return "image/jpeg"
        }
        
        if header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47 {
            return "image/png"
        }
        
        if header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46 {
            return "image/gif"
        }
        
        if header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 {
            return "image/webp"
        }
        
        return "image/jpeg"
    }
}
