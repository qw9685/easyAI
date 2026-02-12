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
    private struct LinkEntry {
        let range: NSRange
        let url: URL
    }

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

    private func normalizedWebURL(from url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        guard let storage = textStorage, storage.length > 0 else { return }

        let location = recognizer.location(in: self)
        let textRect = self.textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines)
        let locationInText = CGPoint(x: location.x - textRect.origin.x, y: location.y - textRect.origin.y)

        guard locationInText.x >= 0, locationInText.y >= 0 else { return }

        layoutManager.ensureLayout(for: textContainer)
        for entry in linkEntries(in: storage) {
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: entry.range,
                actualCharacterRange: nil
            )
            guard glyphRange.length > 0 else { continue }
            let hitRect = layoutManager
                .boundingRect(forGlyphRange: glyphRange, in: textContainer)
                .insetBy(dx: -4, dy: -4)
            if hitRect.contains(locationInText) {
                onOpenURL?(entry.url)
                return
            }
        }

        var fraction: CGFloat = 0
        let charIndex = layoutManager.characterIndex(
            for: locationInText,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: &fraction
        )
        guard charIndex < storage.length else { return }

        if let entry = linkEntry(at: charIndex, in: storage) {
            onOpenURL?(entry.url)
            return
        }
    }

    private func linkEntries(in storage: NSTextStorage) -> [LinkEntry] {
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return [] }

        var entries: [LinkEntry] = []
        storage.enumerateAttribute(.link, in: fullRange, options: []) { value, range, _ in
            guard let entry = makeLinkEntry(value: value, range: range) else { return }
            entries.append(entry)
        }
        return entries
    }

    private func linkEntry(at index: Int, in storage: NSTextStorage) -> LinkEntry? {
        let value = storage.attribute(.link, at: index, effectiveRange: nil)
        return makeLinkEntry(value: value, range: NSRange(location: index, length: 1))
    }

    private func makeLinkEntry(value: Any?, range: NSRange) -> LinkEntry? {
        if let url = value as? URL, let safeURL = normalizedWebURL(from: url) {
            return LinkEntry(range: range, url: safeURL)
        }
        if let str = value as? String,
           let url = URL(string: str),
           let safeURL = normalizedWebURL(from: url) {
            return LinkEntry(range: range, url: safeURL)
        }
        return nil
    }
}
