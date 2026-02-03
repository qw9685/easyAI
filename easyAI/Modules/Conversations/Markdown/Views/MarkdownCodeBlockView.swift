//
//  MarkdownCodeBlockView.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 代码块视图（含复制/分享）
//
//

import UIKit
import SnapKit

final class MarkdownCodeBlockView: UIView, MarkdownBlockView {
    var category: MarkdownBlockCategory { .code }
    var onOpenURL: ((URL) -> Void)? {
        didSet { label.onOpenURL = onOpenURL }
    }

    private let container = UIView()
    private let headerContainer = UIView()
    private let headerStack = UIStackView()
    private let languageLabel = UILabel()
    private let actionsStack = UIStackView()
    private let copyButton = UIButton(type: .system)
    private let exportButton = UIButton(type: .system)
    private let headerSeparator = UIView()
    private let label = LinkLabel()
    private var lastCopiedText: String?
    private var resetCopyWorkItem: DispatchWorkItem?

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

        container.layer.masksToBounds = true

        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.adjustsFontForContentSizeCategory = true

        addSubview(container)
        container.addSubview(headerContainer)
        headerContainer.addSubview(headerStack)
        headerContainer.addSubview(headerSeparator)
        container.addSubview(label)

        headerContainer.clipsToBounds = true

        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.distribution = .fill
        headerStack.spacing = 10

        languageLabel.numberOfLines = 1
        languageLabel.setContentHuggingPriority(.required, for: .horizontal)
        languageLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        languageLabel.adjustsFontForContentSizeCategory = true
        languageLabel.textAlignment = .left

        actionsStack.axis = .horizontal
        actionsStack.alignment = .center
        actionsStack.distribution = .fill
        actionsStack.spacing = 12

        copyButton.accessibilityLabel = "Copy code"
        copyButton.addTarget(self, action: #selector(handleCopyTapped), for: .touchUpInside)
        copyButton.setContentHuggingPriority(.required, for: .horizontal)
        copyButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        exportButton.accessibilityLabel = "Export code"
        exportButton.addTarget(self, action: #selector(handleExportTapped), for: .touchUpInside)
        exportButton.setContentHuggingPriority(.required, for: .horizontal)
        exportButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        headerStack.addArrangedSubview(languageLabel)
        headerStack.addArrangedSubview(UIView())
        headerStack.addArrangedSubview(actionsStack)

        actionsStack.addArrangedSubview(copyButton)
        actionsStack.addArrangedSubview(exportButton)

        container.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        headerContainer.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        headerStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().inset(12)
            make.bottom.equalToSuperview().inset(10)
        }

        headerSeparator.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1 / UIScreen.main.scale)
        }

        copyButton.snp.makeConstraints { make in
            make.width.height.equalTo(28)
        }

        exportButton.snp.makeConstraints { make in
            make.width.height.equalTo(28)
        }

        label.snp.makeConstraints { make in
            make.top.equalTo(headerContainer.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().inset(12)
            make.bottom.equalToSuperview().inset(10)
        }
    }

    func update(block: MarkdownBlock, style: MarkdownStyle) {
        container.backgroundColor = style.codeBlockBackgroundColor
        container.layer.borderColor = style.codeBlockBorderColor.cgColor
        container.layer.borderWidth = style.codeBlockBorderWidth
        container.layer.cornerRadius = style.codeBlockCornerRadius

        headerContainer.backgroundColor = style.codeBlockHeaderBackgroundColor
        headerSeparator.backgroundColor = style.codeBlockHeaderSeparatorColor

        languageLabel.font = style.codeBlockHeaderFont
        languageLabel.textColor = style.codeBlockHeaderTextColor

        copyButton.tintColor = style.codeBlockHeaderTextColor.withAlphaComponent(0.9)
        exportButton.tintColor = style.codeBlockHeaderTextColor.withAlphaComponent(0.9)
        updateCopyButtonIcon(copied: false)
        updateExportButtonIcon()

        switch block.kind {
        case .code(let language, let text):
            label.attributedText = text
            lastCopiedText = text.string
            let lang = (language ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if lang.isEmpty {
                languageLabel.text = nil
                languageLabel.isHidden = true
            } else {
                languageLabel.text = lang.uppercased()
                languageLabel.isHidden = false
            }
        default:
            label.attributedText = nil
            lastCopiedText = nil
            languageLabel.text = nil
            languageLabel.isHidden = true
        }
    }
}

private extension MarkdownCodeBlockView {
    @objc func handleCopyTapped() {
        guard let lastCopiedText, !lastCopiedText.isEmpty else { return }

        UIPasteboard.general.string = lastCopiedText
        updateCopyButtonIcon(copied: true)

        resetCopyWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.updateCopyButtonIcon(copied: false)
        }
        resetCopyWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
    }

    @objc func handleExportTapped() {
        guard let lastCopiedText, !lastCopiedText.isEmpty else { return }
        guard let viewController = findViewController() else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("code-\(UUID().uuidString.prefix(8)).txt")
        do {
            try lastCopiedText.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return
        }

        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = exportButton
        activity.popoverPresentationController?.sourceRect = exportButton.bounds
        viewController.present(activity, animated: true)
    }

    func updateCopyButtonIcon(copied: Bool) {
        let imageName = copied ? "checkmark" : "doc.on.doc"
        copyButton.setImage(UIImage(systemName: imageName), for: .normal)
    }

    func updateExportButtonIcon() {
        exportButton.setImage(UIImage(systemName: "square.and.arrow.down"), for: .normal)
    }

    func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let vc = current as? UIViewController { return vc }
            responder = current.next
        }
        return nil
    }
}
