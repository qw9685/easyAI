//
//  ChatLogger.swift
//  EasyAI
//
//  创建于 2026
//

import Foundation

struct ChatLogger {
    let isPhase4Enabled: () -> Bool

    init(isPhase4Enabled: @escaping () -> Bool) {
        self.isPhase4Enabled = isPhase4Enabled
    }

    func phase4(_ message: @autoclosure () -> String) {
        guard isPhase4Enabled() else { return }
        print("[ConversationSSE][Phase4] \(message())")
    }
}

