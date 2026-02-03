//
//  MarkdownDividerBlockView.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - Markdown 分割线视图
//
//

import UIKit
import SnapKit

final class MarkdownDividerBlockView: UIView, MarkdownBlockView {
    var category: MarkdownBlockCategory { .divider }
    var onOpenURL: ((URL) -> Void)?

    private let lineView = UIView()

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
        addSubview(lineView)
        lineView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(1 / UIScreen.main.scale)
        }
    }

    func update(block: MarkdownBlock, style: MarkdownStyle) {
        lineView.backgroundColor = style.codeBlockBorderColor
    }
}
