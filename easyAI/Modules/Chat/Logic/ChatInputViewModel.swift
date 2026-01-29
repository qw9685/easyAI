//
//  ChatInputViewModel.swift
//  EasyAI
//
//  创建于 2026
//

import Foundation
import UIKit
import Combine

@MainActor
final class ChatInputViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var selectedImage: UIImage?
    @Published var selectedImageData: Data?
    @Published var selectedImageMimeType: String?

    var shouldShowClearButton: Bool {
        !inputText.isEmpty && selectedImage == nil
    }

    func isSendDisabled(isChatLoading: Bool, isTypingAnimating: Bool) -> Bool {
        let textIsEmpty = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let noImage = selectedImage == nil
        let hasNoContent = textIsEmpty && noImage
        return hasNoContent || isChatLoading || isTypingAnimating
    }

    func clearText() {
        inputText = ""
    }

    func clearSelectedImage() {
        selectedImage = nil
        selectedImageData = nil
        selectedImageMimeType = nil
    }

    func clearAll() {
        inputText = ""
        clearSelectedImage()
    }

    func setSelectedImageData(_ data: Data) {
        selectedImageData = data
        selectedImage = UIImage(data: data)
        selectedImageMimeType = Self.detectImageMimeType(data)
    }

    func send(chatViewModel: ChatViewModel) {
        guard !isSendDisabled(isChatLoading: chatViewModel.isLoading, isTypingAnimating: chatViewModel.isTypingAnimating) else {
            return
        }

        let message = inputText
        let imageData = selectedImageData
        let imageMimeType = selectedImageMimeType

        clearAll()

        Task {
            await chatViewModel.sendMessage(message, imageData: imageData, imageMimeType: imageMimeType)
        }
    }

    static func detectImageMimeType(_ data: Data) -> String {
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
