//
//  MarkdownHTMLBlockView.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - Markdown HTML/数学块渲染视图（WKWebView + KaTeX）
//
//

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
        switch block.kind {
        case .html(let raw):
            pendingHTML = htmlWrapper(bodyHTML: raw, useKatex: false)
        case .math(let latex):
            pendingHTML = htmlWrapper(bodyHTML: latexBody(for: latex), useKatex: true)
        default:
            return
        }
        if let pendingHTML {
            webView.loadHTMLString(pendingHTML, baseURL: nil)
        }
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
            onOpenURL?(url)
            decisionHandler(.cancel)
            return
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
        var escaped = latex
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\n", with: "\n")
        return escaped
    }
}
