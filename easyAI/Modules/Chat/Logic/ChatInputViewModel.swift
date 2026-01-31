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
    struct SelectedImage: Identifiable, Equatable {
        let id: UUID
        let image: UIImage
        let media: MediaContent

        static func == (lhs: SelectedImage, rhs: SelectedImage) -> Bool {
            lhs.id == rhs.id
        }
    }

    @Published var inputText: String = ""
    @Published private(set) var selectedImages: [SelectedImage] = []

    let maxImageCount: Int = 5

    var shouldShowClearButton: Bool {
        !inputText.isEmpty
    }

    func isSendDisabled(isChatLoading: Bool) -> Bool {
        let textIsEmpty = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let noImage = selectedImages.isEmpty
        let hasNoContent = textIsEmpty && noImage
        return hasNoContent || isChatLoading
    }

    func clearText() {
        inputText = ""
    }

    func clearSelectedImages() { selectedImages = [] }

    func clearAll() {
        inputText = ""
        clearSelectedImages()
    }

    var remainingSelectionLimit: Int {
        max(0, maxImageCount - selectedImages.count)
    }

    func addSelectedImageData(_ data: Data) {
        guard remainingSelectionLimit > 0 else { return }
        guard let image = UIImage(data: data) else { return }
        let mimeType = Self.detectImageMimeType(data)
        let media = MediaContent(id: UUID(), type: .image, data: data, mimeType: mimeType, fileName: nil)
        selectedImages.append(SelectedImage(id: media.id, image: image, media: media))
    }

    func removeSelectedImage(id: UUID) {
        selectedImages.removeAll { $0.id == id }
    }

    func send(chatViewModel: ChatViewModel) {
        guard !isSendDisabled(isChatLoading: chatViewModel.isLoading) else {
            return
        }

        let message = inputText
        let mediaContents = selectedImages.map { $0.media }

        clearAll()

        Task {
            await chatViewModel.sendMessage(message, mediaContents: mediaContents)
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
