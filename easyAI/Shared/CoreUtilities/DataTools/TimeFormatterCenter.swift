//
//  TimeFormatterCenter.swift
//  easyAI
//
//  通用时间格式化中心
//

import Foundation

extension DataTools {
    enum TimeFormatterCenter {
        private static let lock = NSLock()
        private static let clockFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter
        }()

        static func clockTime(_ date: Date) -> String {
            lock.lock()
            defer { lock.unlock() }
            return clockFormatter.string(from: date)
        }
    }
}
