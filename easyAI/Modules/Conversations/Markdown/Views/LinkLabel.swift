//
//  LinkLabel.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 可点击链接文本组件
//
//

import UIKit

final class LinkLabel: UILabel {
    var onOpenURL: ((URL) -> Void)?

    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer(size: .zero)
    private var textStorage: NSTextStorage?

    override var attributedText: NSAttributedString? {
        didSet { rebuildTextStorage() }
    }

    override var text: String? {
        didSet { rebuildTextStorage() }
    }

    override var numberOfLines: Int {
        didSet { textContainer.maximumNumberOfLines = numberOfLines }
    }

    override var lineBreakMode: NSLineBreakMode {
        didSet { textContainer.lineBreakMode = lineBreakMode }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isUserInteractionEnabled = true
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.required, for: .horizontal)

        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = numberOfLines
        textContainer.lineBreakMode = lineBreakMode

        layoutManager.addTextContainer(textContainer)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rect = textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines)
        textContainer.size = rect.size
    }

    private func rebuildTextStorage() {
        let attributed: NSAttributedString
        if let attributedText {
            attributed = attributedText
        } else if let text {
            attributed = NSAttributedString(string: text)
        } else {
            attributed = NSAttributedString(string: "")
        }

        let storage = NSTextStorage(attributedString: attributed)
        storage.addLayoutManager(layoutManager)
        textStorage = storage
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        guard let storage = textStorage, storage.length > 0 else { return }

        let location = recognizer.location(in: self)
        let textRect = self.textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines)
        let locationInText = CGPoint(x: location.x - textRect.origin.x, y: location.y - textRect.origin.y)

        guard locationInText.x >= 0, locationInText.y >= 0 else { return }

        layoutManager.ensureLayout(for: textContainer)
        let glyphIndex = layoutManager.glyphIndex(for: locationInText, in: textContainer)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
        guard glyphRect.contains(locationInText) else { return }

        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        guard characterIndex < storage.length else { return }

        if let url = storage.attribute(.link, at: characterIndex, effectiveRange: nil) as? URL {
            onOpenURL?(url)
            return
        }
        if let str = storage.attribute(.link, at: characterIndex, effectiveRange: nil) as? String,
           let url = URL(string: str) {
            onOpenURL?(url)
            return
        }
    }
}
