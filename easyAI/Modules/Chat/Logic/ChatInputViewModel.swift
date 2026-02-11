//
//  ChatInputViewModel.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 输入文本与图片选择状态
//  - 负责发送触发与校验
//
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

@MainActor
final class ChatInputViewModel {
    struct SelectedImage: Identifiable, Equatable {
        let id: UUID
        let image: UIImage
        let media: MediaContent

        static func == (lhs: SelectedImage, rhs: SelectedImage) -> Bool {
            lhs.id == rhs.id
        }
    }

    private let inputTextRelay = BehaviorRelay<String>(value: "")
    private let selectedImagesRelay = BehaviorRelay<[SelectedImage]>(value: [])
    var actionHandler: ((ChatViewModel.Action) -> Void)?

    let maxImageCount: Int = 5

    var shouldShowClearButton: Bool {
        !inputTextRelay.value.isEmpty
    }

    func isSendDisabled(isChatLoading: Bool) -> Bool {
        if isChatLoading {
            return false
        }
        let normalizedText = sanitizeOutgoingText(inputTextRelay.value)
        let textIsEmpty = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let noImage = selectedImagesRelay.value.isEmpty
        let hasNoContent = textIsEmpty && noImage
        return hasNoContent
    }

    func clearText() {
        inputTextRelay.accept("")
    }

    func clearSelectedImages() { selectedImagesRelay.accept([]) }

    func clearAll() {
        inputText = ""
        clearSelectedImages()
    }

    var remainingSelectionLimit: Int {
        max(0, maxImageCount - selectedImagesRelay.value.count)
    }

    func addSelectedImageData(_ data: Data) {
        guard remainingSelectionLimit > 0 else { return }
        guard let image = UIImage(data: data) else { return }
        let mimeType = Self.detectImageMimeType(data)
        let media = MediaContent(id: UUID(), type: .image, data: data, mimeType: mimeType, fileName: nil)
        var updated = selectedImagesRelay.value
        updated.append(SelectedImage(id: media.id, image: image, media: media))
        selectedImagesRelay.accept(updated)
    }

    func removeSelectedImage(id: UUID) {
        let updated = selectedImagesRelay.value.filter { $0.id != id }
        selectedImagesRelay.accept(updated)
    }

    func send(chatViewModel: ChatViewModel) {
        if chatViewModel.isLoading {
            if let actionHandler {
                actionHandler(.stopGenerating)
            } else {
                chatViewModel.stopGenerating()
            }
            return
        }

        guard !isSendDisabled(isChatLoading: chatViewModel.isLoading) else {
            return
        }

        let message = sanitizeOutgoingText(inputTextRelay.value)
        let mediaContents = selectedImagesRelay.value.map { $0.media }

        let textIsEmpty = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if textIsEmpty && mediaContents.isEmpty {
            return
        }

        guard chatViewModel.canStartSendMessage(content: message, mediaContents: mediaContents) else {
            return
        }

        clearAll()

        if let actionHandler {
            let payload = ChatViewModel.SendPayload(
                content: message,
                imageData: nil,
                imageMimeType: nil,
                mediaContents: mediaContents
            )
            actionHandler(.sendMessage(payload))
        } else {
            chatViewModel.startSendMessage(message, mediaContents: mediaContents)
        }
    }

    var inputText: String {
        get { inputTextRelay.value }
        set { inputTextRelay.accept(newValue) }
    }

    var selectedImages: [SelectedImage] {
        selectedImagesRelay.value
    }

    var inputTextObservable: Observable<String> {
        inputTextRelay.asObservable()
    }

    var selectedImagesObservable: Observable<[SelectedImage]> {
        selectedImagesRelay.asObservable()
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
            if header.count >= 12,
               let webpMark = String(data: header[8..<12], encoding: .ascii)?.uppercased(),
               webpMark == "WEBP" {
                return "image/webp"
            }
            return "image/jpeg"
        }

        if header.count >= 12,
           header[4] == 0x66,
           header[5] == 0x74,
           header[6] == 0x79,
           header[7] == 0x70,
           let brand = String(data: header[8..<12], encoding: .ascii)?.lowercased(),
           ["heic", "heix", "hevc", "hevx", "mif1", "msf1"].contains(brand) {
            return "image/heic"
        }

        return "image/jpeg"
    }

    private func sanitizeOutgoingText(_ raw: String) -> String {
        var text = raw.replacingOccurrences(of: "\r\n", with: "\n")

        let placeholderMarkers: Set<String> = [
            "原文：", "内容：", "主题：", "会议内容：", "报错/上下文：", "目标：", "代码：", "输入："
        ]

        var lines = text.components(separatedBy: "\n")
        while let last = lines.last, last.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.removeLast()
        }

        if let last = lines.last,
           placeholderMarkers.contains(last.trimmingCharacters(in: .whitespacesAndNewlines)) {
            lines.removeLast()
            while let trailing = lines.last, trailing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.removeLast()
            }
        }

        text = lines.joined(separator: "\n")

        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
