//
//  MarkupEscaper.swift
//  easyAI
//
//  通用标记文本转义工具
//

import Foundation

extension DataTools {
    enum MarkupEscaper {
        static func escapeHTML(_ text: String) -> String {
            text
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
        }
    }
}
