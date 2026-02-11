//
//  ChatLogger.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - phase 日志开关与格式化输出
//
//

import Foundation

struct ChatLogger {
    let isphaseEnabled: () -> Bool

    init(isphaseEnabled: @escaping () -> Bool) {
        self.isphaseEnabled = isphaseEnabled
    }

    func phase(_ message: @autoclosure () -> String) {
        guard isphaseEnabled() else { return }
        RuntimeTools.AppDiagnostics.debug("ConversationSSE", "[phase] \(message())")
    }
}
