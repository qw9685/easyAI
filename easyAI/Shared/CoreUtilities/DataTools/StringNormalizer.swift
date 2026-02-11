//
//  StringNormalizer.swift
//  easyAI
//
//  通用字符串规整工具
//

import Foundation

extension DataTools {
    enum StringNormalizer {
        static func trimmed(_ text: String?) -> String {
            (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        static func normalizeLineEndings(_ text: String) -> String {
            text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
        }

        static func collapseExtraBlankLines(_ text: String, maxConsecutive: Int = 2) -> String {
            let allowedCount = max(1, maxConsecutive)
            let needle = String(repeating: "\n", count: allowedCount + 1)
            let replacement = String(repeating: "\n", count: allowedCount)

            var output = text
            while output.contains(needle) {
                output = output.replacingOccurrences(of: needle, with: replacement)
            }
            return output
        }

        static func applyLineBreakAfterMarkers(_ text: String, markers: [String]) -> String {
            var output = text
            for marker in markers {
                output = output.replacingOccurrences(of: marker + " ", with: marker + "\n")

                var searchStart = output.startIndex
                while let range = output.range(of: marker, range: searchStart..<output.endIndex) {
                    if range.upperBound < output.endIndex, output[range.upperBound] != "\n" {
                        output.insert("\n", at: range.upperBound)
                    }
                    searchStart = range.upperBound < output.endIndex
                        ? output.index(after: range.upperBound)
                        : output.endIndex
                }
            }
            return output
        }
    }
}
