//
//  ValueParser.swift
//  easyAI
//
//  通用数值解析工具
//

import Foundation

extension DataTools {
    enum ValueParser {
        static func decimal(from raw: String?) -> Double? {
            let text = StringNormalizer.trimmed(raw)
            guard !text.isEmpty else { return nil }
            let normalized = text
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "")
            return Double(normalized)
        }
    }
}
