//
//  ChatMessageMediaCell.swift
//  EasyAI
//
//  创建于 2026
//

import UIKit
import SnapKit

final class ChatMessageMediaCell: ChatBaseBubbleCell {
    static let reuseIdentifier = "ChatMessageMediaCell"

    private let mediaStack = UIStackView()
    private var currentMessageId: UUID?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        mediaStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        currentMessageId = nil
    }

    func configure(messageId: UUID, role: MessageRole, mediaContents: [MediaContent]) {
        currentMessageId = messageId
        configureBase(role: role, timestamp: nil, showTimestamp: false)
        setBubbleHidden(mediaContents.isEmpty)
        let isUser = role == .user

        mediaStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for media in mediaContents {
            if media.type == .image {
                let imageView = UIImageView()
                imageView.contentMode = .scaleAspectFit
                imageView.layer.cornerRadius = 12
                imageView.layer.masksToBounds = true
                imageView.backgroundColor = isUser
                    ? UIColor.white.withAlphaComponent(0.12)
                    : UIColor.black.withAlphaComponent(0.05)

                let messageIdAtStart = currentMessageId
                let maxPixelSize = 400
                if let cached = ChatImageThumbnailer.cachedThumbnail(for: media.data, maxPixelSize: maxPixelSize) {
                    imageView.image = cached
                } else {
                    let data = media.data
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        guard let thumbnail = ChatImageThumbnailer.makeThumbnail(from: data, maxPixelSize: maxPixelSize) else { return }
                        ChatImageThumbnailer.setCachedThumbnail(thumbnail, for: data, maxPixelSize: maxPixelSize)
                        DispatchQueue.main.async {
                            guard let self else { return }
                            guard self.currentMessageId == messageIdAtStart else { return }
                            imageView.image = thumbnail
                        }
                    }
                }

                let container = UIView()
                container.addSubview(imageView)
                imageView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                    make.width.lessThanOrEqualTo(200)
                    make.height.lessThanOrEqualTo(200)
                }
                mediaStack.addArrangedSubview(container)
            } else {
                let placeholder = UILabel()
                placeholder.numberOfLines = 0
                placeholder.font = UIFont.preferredFont(forTextStyle: .caption1)
                placeholder.textColor = isUser ? UIColor.white.withAlphaComponent(0.8) : .secondaryLabel
                placeholder.textAlignment = isUser ? .right : .left
                placeholder.text = "\(media.type.rawValue.uppercased()) • \(media.fileSizeFormatted)"
                mediaStack.addArrangedSubview(placeholder)
            }
        }
    }

    private func setupViews() {
        mediaStack.axis = .vertical
        mediaStack.spacing = 8
        bubbleContentView.addSubview(mediaStack)
        mediaStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
