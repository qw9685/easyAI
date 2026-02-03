//
//  MarkdownImageBlockView.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - Markdown 图片块视图（基于 Kingfisher）
//
//

import UIKit
import SnapKit
import Kingfisher

final class MarkdownImageBlockView: UIView, MarkdownBlockView {
    var category: MarkdownBlockCategory { .image }
    var onOpenURL: ((URL) -> Void)?

    private let imageView = UIImageView()
    private var heightConstraint: Constraint?
    private var lastImage: UIImage?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        imageView.backgroundColor = UIColor.secondarySystemBackground
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8

        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            heightConstraint = make.height.equalTo(160).constraint
        }
    }

    func update(block: MarkdownBlock, style: MarkdownStyle) {
        guard case let .image(url, _) = block.kind else { return }
        imageView.kf.setImage(with: url, options: [.transition(.fade(0.2))]) { [weak self] result in
            guard let self else { return }
            if case let .success(value) = result {
                self.lastImage = value.image
                self.updateHeightForImage(value.image)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let image = lastImage {
            updateHeightForImage(image)
        }
    }
}

private extension MarkdownImageBlockView {
    func updateHeightForImage(_ image: UIImage) {
        let width = bounds.width
        guard width > 0, image.size.width > 0 else { return }
        let ratio = image.size.height / image.size.width
        let height = max(60, min(360, width * ratio))
        heightConstraint?.update(offset: height)
        setNeedsLayout()
    }
}
