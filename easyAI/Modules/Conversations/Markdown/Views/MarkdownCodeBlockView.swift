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
    private let codeScrollView = UIScrollView()
    private let label = LinkLabel()
    private let leftFadeView = UIView()
    private let rightFadeView = UIView()
    private let leftFadeLayer = CAGradientLayer()
    private let rightFadeLayer = CAGradientLayer()
    private var fadeBaseColor: UIColor = .clear
    private var codeContentWidthConstraint: Constraint?
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

    override func layoutSubviews() {
        super.layoutSubviews()
        leftFadeLayer.frame = leftFadeView.bounds
        rightFadeLayer.frame = rightFadeView.bounds
        updateEdgeFadeVisibility()
    }

    private func setup() {
        backgroundColor = .clear

        container.layer.masksToBounds = true

        label.numberOfLines = 0
        label.lineBreakMode = .byClipping
        label.adjustsFontForContentSizeCategory = true

        codeScrollView.showsHorizontalScrollIndicator = false
        codeScrollView.showsVerticalScrollIndicator = false
        codeScrollView.alwaysBounceHorizontal = true
        codeScrollView.alwaysBounceVertical = false
        codeScrollView.delegate = self

        leftFadeView.isUserInteractionEnabled = false
        rightFadeView.isUserInteractionEnabled = false
        leftFadeLayer.startPoint = CGPoint(x: 0, y: 0.5)
        leftFadeLayer.endPoint = CGPoint(x: 1, y: 0.5)
        rightFadeLayer.startPoint = CGPoint(x: 0, y: 0.5)
        rightFadeLayer.endPoint = CGPoint(x: 1, y: 0.5)
        leftFadeView.layer.addSublayer(leftFadeLayer)
        rightFadeView.layer.addSublayer(rightFadeLayer)

        addSubview(container)
        container.addSubview(headerContainer)
        headerContainer.addSubview(headerStack)
        headerContainer.addSubview(headerSeparator)
        container.addSubview(codeScrollView)
        container.addSubview(leftFadeView)
        container.addSubview(rightFadeView)
        codeScrollView.addSubview(label)

        headerContainer.clipsToBounds = true

        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.distribution = .fill
        headerStack.spacing = 8

        languageLabel.numberOfLines = 1
        languageLabel.setContentHuggingPriority(.required, for: .horizontal)
        languageLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        languageLabel.adjustsFontForContentSizeCategory = true
        languageLabel.textAlignment = .left

        actionsStack.axis = .horizontal
        actionsStack.alignment = .center
        actionsStack.distribution = .fill
        actionsStack.spacing = 8

        copyButton.accessibilityLabel = "Copy code"
        applyHeaderButtonSymbolConfiguration()
        configureHeaderActionButton(copyButton)
        copyButton.addTarget(self, action: #selector(handleCopyTapped), for: .touchUpInside)
        copyButton.setContentHuggingPriority(.required, for: .horizontal)
        copyButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        exportButton.accessibilityLabel = "Export code"
        configureHeaderActionButton(exportButton)
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
            make.height.equalTo(34)
        }

        headerStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().inset(8)
            make.centerY.equalToSuperview()
        }

        headerSeparator.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1 / UIScreen.main.scale)
        }

        copyButton.snp.makeConstraints { make in
            make.width.height.equalTo(22)
        }

        exportButton.snp.makeConstraints { make in
            make.width.height.equalTo(22)
        }

        codeScrollView.snp.makeConstraints { make in
            make.top.equalTo(headerContainer.snp.bottom).offset(10)
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().inset(8)
            make.bottom.equalToSuperview().inset(12)
        }

        leftFadeView.snp.makeConstraints { make in
            make.leading.equalTo(codeScrollView)
            make.top.bottom.equalTo(codeScrollView)
            make.width.equalTo(16)
        }

        rightFadeView.snp.makeConstraints { make in
            make.trailing.equalTo(codeScrollView)
            make.top.bottom.equalTo(codeScrollView)
            make.width.equalTo(16)
        }

        label.snp.makeConstraints { make in
            make.edges.equalTo(codeScrollView.contentLayoutGuide)
            make.height.equalTo(codeScrollView.frameLayoutGuide)
            codeContentWidthConstraint = make.width.greaterThanOrEqualTo(codeScrollView.frameLayoutGuide).constraint
        }
    }

    func update(block: MarkdownBlock, style: MarkdownStyle) {
        container.backgroundColor = style.codeBlockBackgroundColor
        container.layer.borderColor = style.codeBlockBorderColor.cgColor
        container.layer.borderWidth = style.codeBlockBorderWidth
        container.layer.cornerRadius = style.codeBlockCornerRadius

        headerContainer.backgroundColor = style.codeBlockHeaderBackgroundColor
        headerSeparator.backgroundColor = style.codeBlockHeaderSeparatorColor
        fadeBaseColor = style.codeBlockBackgroundColor
        updateFadeLayersColor()

        languageLabel.font = style.codeBlockHeaderFont
        languageLabel.textColor = style.codeBlockHeaderTextColor

        copyButton.tintColor = style.codeBlockHeaderTextColor
        exportButton.tintColor = style.codeBlockHeaderTextColor
        updateCopyButtonIcon(copied: false)
        updateExportButtonIcon()

        switch block.kind {
        case .code(let language, let text):
            label.attributedText = text
            lastCopiedText = text.string
            updateCodeContentWidth(using: text)
            updateEdgeFadeVisibility()
            let lang = (language ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if lang.isEmpty {
                languageLabel.text = nil
                languageLabel.attributedText = nil
                languageLabel.isHidden = true
            } else {
                let title = lang.uppercased()
                languageLabel.attributedText = NSAttributedString(
                    string: title,
                    attributes: [
                        .font: style.codeBlockHeaderFont,
                        .foregroundColor: style.codeBlockHeaderTextColor,
                        .kern: 0.3
                    ]
                )
                languageLabel.isHidden = false
            }
        default:
            label.attributedText = nil
            lastCopiedText = nil
            codeContentWidthConstraint?.deactivate()
            updateEdgeFadeVisibility()
            languageLabel.text = nil
            languageLabel.attributedText = nil
            languageLabel.isHidden = true
        }
    }
}

private extension MarkdownCodeBlockView {
    func updateCodeContentWidth(using attributedText: NSAttributedString) {
        let maxLine = maxCodeLineWidth(for: attributedText)
        let targetWidth = max(1, ceil(maxLine))
        codeContentWidthConstraint?.deactivate()
        label.snp.makeConstraints { make in
            codeContentWidthConstraint = make.width.equalTo(targetWidth).constraint
        }
        setNeedsLayout()
    }

    func maxCodeLineWidth(for attributedText: NSAttributedString) -> CGFloat {
        let full = attributedText.string as NSString
        if full.length == 0 { return 1 }

        var maxWidth: CGFloat = 1
        full.enumerateSubstrings(in: NSRange(location: 0, length: full.length), options: .byLines) { _, range, _, _ in
            let line = attributedText.attributedSubstring(from: range)
            let rect = line.boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            maxWidth = max(maxWidth, rect.width)
        }
        return maxWidth + 2
    }

    func updateFadeLayersColor() {
        let transparent = fadeBaseColor.withAlphaComponent(0)
        leftFadeLayer.colors = [fadeBaseColor.cgColor, transparent.cgColor]
        rightFadeLayer.colors = [transparent.cgColor, fadeBaseColor.cgColor]
    }

    func updateEdgeFadeVisibility() {
        let contentWidth = codeScrollView.contentSize.width
        let visibleWidth = codeScrollView.bounds.width
        guard contentWidth > 0, visibleWidth > 0, contentWidth - visibleWidth > 1 else {
            leftFadeView.isHidden = true
            rightFadeView.isHidden = true
            return
        }

        let x = codeScrollView.contentOffset.x
        let maxX = max(0, contentWidth - visibleWidth)
        leftFadeView.isHidden = x <= 1
        rightFadeView.isHidden = x >= (maxX - 1)
    }

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
        exportButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
    }

    func configureHeaderActionButton(_ button: UIButton) {
        if #available(iOS 15.0, *) {
            var configuration = button.configuration ?? UIButton.Configuration.plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
            button.configuration = configuration
        } else {
            button.contentEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        }

        button.backgroundColor = .clear
        button.layer.cornerRadius = 6
        button.layer.masksToBounds = true
    }

    func applyHeaderButtonSymbolConfiguration() {
        let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        copyButton.setPreferredSymbolConfiguration(config, forImageIn: .normal)
        exportButton.setPreferredSymbolConfiguration(config, forImageIn: .normal)
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


extension MarkdownCodeBlockView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateEdgeFadeVisibility()
    }
}
