//
//  MarkdownStyle.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - Markdown 渲染样式与字体定义
//
//

import UIKit

struct MarkdownStyle {
    let bodyFont: UIFont
    let textColor: UIColor
    let secondaryTextColor: UIColor
    let linkColor: UIColor

    let quoteBarColor: UIColor
    let quoteBackgroundColor: UIColor

    let inlineCodeFont: UIFont
    let inlineCodeTextColor: UIColor
    let inlineCodeBackgroundColor: UIColor

    let codeBlockFont: UIFont
    let codeBlockTextColor: UIColor
    let codeBlockBackgroundColor: UIColor
    let codeBlockBorderColor: UIColor
    let codeBlockBorderWidth: CGFloat
    let codeBlockCornerRadius: CGFloat
    let codeBlockHeaderBackgroundColor: UIColor
    let codeBlockHeaderSeparatorColor: UIColor
    let codeBlockHeaderFont: UIFont
    let codeBlockHeaderTextColor: UIColor

    /// 默认 block 间距策略：除 code 外都为 0；code 上下各 10。
    let codeBlockVerticalSpacing: CGFloat

    static func `default`() -> MarkdownStyle {
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let inlineCodeFont = UIFont.monospacedSystemFont(ofSize: bodyFont.pointSize, weight: .regular)
        let codeBase = UIFont.preferredFont(forTextStyle: .callout)
        let codeBlockFont = UIFont.monospacedSystemFont(ofSize: codeBase.pointSize, weight: .regular)
        return MarkdownStyle(
            bodyFont: bodyFont,
            textColor: AppTheme.textPrimary,
            secondaryTextColor: AppTheme.textSecondary,
            linkColor: AppTheme.accent,
            quoteBarColor: AppTheme.border,
            quoteBackgroundColor: AppTheme.surfaceAlt,
            inlineCodeFont: inlineCodeFont,
            inlineCodeTextColor: AppTheme.textPrimary,
            inlineCodeBackgroundColor: AppTheme.surfaceAlt,
            codeBlockFont: codeBlockFont,
            codeBlockTextColor: AppTheme.textPrimary.withAlphaComponent(0.92),
            codeBlockBackgroundColor: AppTheme.surfaceAlt,
            codeBlockBorderColor: AppTheme.border,
            codeBlockBorderWidth: AppTheme.borderWidth / UIScreen.main.scale,
            codeBlockCornerRadius: 12,
            codeBlockHeaderBackgroundColor: AppTheme.surface,
            codeBlockHeaderSeparatorColor: AppTheme.border,
            codeBlockHeaderFont: UIFont.preferredFont(forTextStyle: .caption2).withTraits(.traitBold),
            codeBlockHeaderTextColor: AppTheme.textSecondary,
            codeBlockVerticalSpacing: 10
        )
    }

    func headingFont(level: Int) -> UIFont {
        switch level {
        case 1:
            return UIFont.preferredFont(forTextStyle: .title3).withTraits(.traitBold)
        case 2:
            return UIFont.preferredFont(forTextStyle: .headline).withTraits(.traitBold)
        case 3:
            return UIFont.preferredFont(forTextStyle: .subheadline).withTraits(.traitBold)
        default:
            return bodyFont.withTraits(.traitBold)
        }
    }
}

extension MarkdownStyle {
    func spacingAfterBlock(_ block: MarkdownBlock, next: MarkdownBlock?) -> CGFloat {
        var spacing: CGFloat = 0
        if block.category == .code { spacing = max(spacing, codeBlockVerticalSpacing) }
        if next?.category == .code { spacing = max(spacing, codeBlockVerticalSpacing) }
        return spacing
    }
}

extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let combined = fontDescriptor.symbolicTraits.union(traits)
        guard let descriptor = fontDescriptor.withSymbolicTraits(combined) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
