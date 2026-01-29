//
//  ChatLogger.swift
//  EasyAI
//
//  创建于 2026
//

import Foundation

struct ChatLogger {
    let isphaseEnabled: () -> Bool

    init(isphaseEnabled: @escaping () -> Bool) {
        self.isphaseEnabled = isphaseEnabled
    }

    func phase(_ message: @autoclosure () -> String) {
        guard isphaseEnabled() else { return }
        print("[ConversationSSE][phase] \(message())")
    }
}

