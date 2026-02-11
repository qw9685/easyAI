//
//  AppDiagnostics.swift
//  easyAI
//
//  通用运行时诊断输出
//

import Foundation

extension RuntimeTools {
    enum AppDiagnostics {
#if DEBUG
        static var debugEnabled = true
#else
        static var debugEnabled = false
#endif

        static func debug(_ domain: String, _ message: @autoclosure () -> String) {
            guard debugEnabled else { return }
            print("[\(domain)][DEBUG] \(message())")
        }

        static func warn(_ domain: String, _ message: @autoclosure () -> String) {
            print("[\(domain)][WARN] \(message())")
        }

        static func error(_ domain: String, _ message: @autoclosure () -> String) {
            print("[\(domain)][ERROR] \(message())")
        }
    }
}
