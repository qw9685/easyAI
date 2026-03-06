//
//  RuntimeTools.swift
//  easyAI
//
//  运行时工具命名空间
//

import Foundation

enum RuntimeTools {}

extension RuntimeTools {
    enum AppRuntime {
        static var isRunningTests: Bool {
            let environment = ProcessInfo.processInfo.environment
            return environment["XCTestSessionIdentifier"] != nil
                || environment["XCTestBundlePath"] != nil
                || environment["XCTestConfigurationFilePath"] != nil
        }
    }
}
