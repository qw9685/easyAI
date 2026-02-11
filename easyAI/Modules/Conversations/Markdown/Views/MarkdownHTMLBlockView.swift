//
//  MarkdownHTMLBlockView.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - Markdown HTML/数学块渲染视图（WKWebView + KaTeX）
//

import Foundation
import UIKit
import WebKit
import SnapKit

final class MarkdownHTMLBlockView: UIView, MarkdownBlockView, WKNavigationDelegate {
    var category: MarkdownBlockCategory { .html }
    var onOpenURL: ((URL) -> Void)?

    private let webView: WKWebView
    private var heightConstraint: Constraint?
    private var pendingHTML: String?

    override init(frame: CGRect) {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = self
        webView.allowsLinkPreview = false
        addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            heightConstraint = make.height.equalTo(60).constraint
        }
    }

    func update(block: MarkdownBlock, style: MarkdownStyle) {
        let renderResult: (html: String, allowJavaScript: Bool)
        switch block.kind {
        case .html(let raw):
            renderResult = (htmlWrapper(bodyHTML: sanitizeHTMLBody(raw), useKatex: false), false)
        case .math(let latex):
            renderResult = (htmlWrapper(bodyHTML: latexBody(for: latex), useKatex: true), true)
        default:
            return
        }

        pendingHTML = renderResult.html
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = renderResult.allowJavaScript
        webView.loadHTMLString(renderResult.html, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let js = "document.body.scrollHeight"
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self else { return }
            if let height = result as? CGFloat {
                self.heightConstraint?.update(offset: max(20, height))
                self.setNeedsLayout()
            } else if let height = result as? Double {
                self.heightConstraint?.update(offset: max(20, CGFloat(height)))
                self.setNeedsLayout()
            }
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url {
            let scheme = url.scheme?.lowercased()
            if scheme == "http" || scheme == "https" {
                onOpenURL?(url)
            }
            decisionHandler(.cancel)
            return
        }

        if let url = navigationAction.request.url,
           let scheme = url.scheme?.lowercased() {
            let allowedSchemes: Set<String> = ["about", "http", "https", "data"]
            if !allowedSchemes.contains(scheme) {
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
}

private extension MarkdownHTMLBlockView {
    func htmlWrapper(bodyHTML: String, useKatex: Bool) -> String {
        if useKatex {
            return """
            <!doctype html>
            <html>
            <head>
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
              <style>
                body { margin: 0; padding: 0; font: -apple-system-body; color: #111; }
                .math { padding: 0; }
              </style>
            </head>
            <body>
              <div class="math">\(bodyHTML)</div>
              <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
              <script>
                const el = document.querySelector('.math');
                if (el) {
                  katex.render(el.textContent, el, { displayMode: true, throwOnError: false });
                }
              </script>
            </body>
            </html>
            """
        }
        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { margin: 0; padding: 0; font: -apple-system-body; color: #111; }
          </style>
        </head>
        <body>\(bodyHTML)</body>
        </html>
        """
    }

    func latexBody(for latex: String) -> String {
        DataTools.MarkupEscaper.escapeHTML(latex)
    }

    func sanitizeHTMLBody(_ raw: String) -> String {
        var sanitized = raw
        sanitized = replacingRegex(in: sanitized, pattern: "(?is)<script\\b[^>]*>.*?</script>", with: "")
        sanitized = replacingRegex(in: sanitized, pattern: "(?is)<(iframe|object|embed|base|form)\\b[^>]*>.*?</\\1>", with: "")
        sanitized = replacingRegex(in: sanitized, pattern: "(?is)<(iframe|object|embed|base|form)\\b[^>]*/?>", with: "")
        sanitized = replacingRegex(in: sanitized, pattern: "(?is)\\son\\w+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)", with: "")
        sanitized = replacingRegex(in: sanitized, pattern: "(?i)javascript\\s*:", with: "")
        return sanitized
    }

    func replacingRegex(in text: String, pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }
}
