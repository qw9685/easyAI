//
//  ChatTextSelectionViewController.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 文本选择与复制界面
//
//

import UIKit
import SnapKit

final class ChatTextSelectionViewController: UIViewController {
    private let textView = UITextView()
    private let content: String

    init(text: String, title: String? = "选择文字") {
        self.content = text
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.canvas

        let attributed = MarkdownAttributedTextBuilder().build(from: content)
        textView.attributedText = attributed
        textView.isEditable = false
        textView.isSelectable = true
        textView.alwaysBounceVertical = true
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = AppTheme.textPrimary
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)

        view.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(handleDone)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "复制",
            style: .plain,
            target: self,
            action: #selector(handleCopy)
        )
    }

    @objc private func handleDone() {
        dismiss(animated: true)
    }

    @objc private func handleCopy() {
        UIPasteboard.general.string = textView.text
    }
}
