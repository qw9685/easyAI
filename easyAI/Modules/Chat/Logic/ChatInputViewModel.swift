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
        let mimeType = DataTools.MediaTypeInspector.detectImageMimeType(data)
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

    private func sanitizeOutgoingText(_ raw: String) -> String {
        var text = DataTools.StringNormalizer.normalizeLineEndings(raw)

        let placeholderMarkers: Set<String> = [
            "原文：", "内容：", "主题：", "会议内容：", "报错/上下文：", "目标：", "代码：", "输入："
        ]

        var lines = text.components(separatedBy: "\n")
        while let last = lines.last, DataTools.StringNormalizer.trimmed(last).isEmpty {
            lines.removeLast()
        }

        if let last = lines.last,
           placeholderMarkers.contains(DataTools.StringNormalizer.trimmed(last)) {
            lines.removeLast()
            while let trailing = lines.last, DataTools.StringNormalizer.trimmed(trailing).isEmpty {
                lines.removeLast()
            }
        }

        text = lines.joined(separator: "\n")
        text = DataTools.StringNormalizer.collapseExtraBlankLines(text, maxConsecutive: 2)
        return DataTools.StringNormalizer.trimmed(text)
    }
}
