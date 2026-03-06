//
//  ConversationSearchKit.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 搜索查询归一化
//  - FTS 查询构造
//  - 拼音检索辅助
//


import Foundation
import CoreFoundation

enum ConversationSearchKit {
    static func trimmedQuery(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func searchTokens(in value: String) -> [String] {
        let lowered = value.lowercased()
        var tokens: [String] = []
        var current = ""

        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                tokens.append(current)
                current.removeAll(keepingCapacity: true)
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    static func makeFTSMatchQuery(_ query: String) -> String? {
        let trimmed = trimmedQuery(query)
        guard canUseFTS(query: trimmed) else {
            return nil
        }

        let tokens = searchTokens(in: trimmed)
        guard !tokens.isEmpty else {
            return nil
        }

        return tokens.map { "\($0)*" }.joined(separator: " ")
    }

    static func makePhoneticForms(for value: String) -> ConversationSearchPhoneticForms {
        let normalizedLatin = makeNormalizedLatinString(from: value)
        let tokens = searchTokens(in: normalizedLatin)
        let spaced = tokens.joined(separator: " ")
        let joined = tokens.joined()
        let initials = tokens.compactMap { $0.first }.map(String.init).joined()

        return ConversationSearchPhoneticForms(
            spaced: spaced,
            joined: joined,
            initials: initials
        )
    }

    static func matchesPhonetically(text: String, query: String) -> Bool {
        let textForms = makePhoneticForms(for: text)
        let queryForms = makePhoneticForms(for: query)

        guard !textForms.joined.isEmpty,
              !queryForms.joined.isEmpty else {
            return false
        }

        if !queryForms.spaced.isEmpty, textForms.spaced.contains(queryForms.spaced) {
            return true
        }

        if textForms.joined.contains(queryForms.joined) {
            return true
        }

        if !textForms.initials.isEmpty, textForms.initials.contains(queryForms.joined) {
            return true
        }

        return false
    }

    private static func canUseFTS(query: String) -> Bool {
        guard !query.isEmpty else {
            return false
        }

        return query.unicodeScalars.allSatisfy { scalar in
            CharacterSet.whitespacesAndNewlines.contains(scalar)
                || CharacterSet.alphanumerics.contains(scalar)
        }
    }

    private static func makeNormalizedLatinString(from value: String) -> String {
        let trimmed = trimmedQuery(value)
        guard !trimmed.isEmpty else {
            return ""
        }

        let mutable = NSMutableString(string: trimmed.lowercased()) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false)
        return (mutable as String).lowercased()
    }
}

struct ConversationSearchPhoneticForms: Equatable {
    let spaced: String
    let joined: String
    let initials: String
}
