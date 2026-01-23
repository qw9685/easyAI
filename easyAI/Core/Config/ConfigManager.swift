//
//  ConfigManager.swift
//  EasyAI
//
//  Created by cc on 2026
//

import Foundation
import SwiftUI
import Combine

/// 配置管理器，使用 UserDefaults 持久化配置
class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    // MARK: - UserDefaults Keys
    private let useMockDataKey = "Config.useMockData"
    private let enableStreamKey = "Config.enableStream"
    private let maxTokensKey = "Config.maxTokens"
    private let enablePhase4LogsKey = "Config.enablePhase4Logs"
    
    // MARK: - Published Properties
    @Published var useMockData: Bool {
        didSet {
            UserDefaults.standard.set(useMockData, forKey: useMockDataKey)
        }
    }
    
    @Published var enableStream: Bool {
        didSet {
            UserDefaults.standard.set(enableStream, forKey: enableStreamKey)
        }
    }
    
    @Published var maxTokens: Int {
        didSet {
            UserDefaults.standard.set(maxTokens, forKey: maxTokensKey)
        }
    }

    @Published var enablePhase4Logs: Bool {
        didSet {
            UserDefaults.standard.set(enablePhase4Logs, forKey: enablePhase4LogsKey)
        }
    }
    
    private init() {
        // 从 UserDefaults 读取配置，如果没有则使用默认值
        self.useMockData = UserDefaults.standard.object(forKey: useMockDataKey) as? Bool ?? false
        self.enableStream = UserDefaults.standard.object(forKey: enableStreamKey) as? Bool ?? true
        self.maxTokens = UserDefaults.standard.object(forKey: maxTokensKey) as? Int ?? 1000
#if DEBUG
        let defaultEnablePhase4Logs = true
#else
        let defaultEnablePhase4Logs = false
#endif
        self.enablePhase4Logs = UserDefaults.standard.object(forKey: enablePhase4LogsKey) as? Bool ?? defaultEnablePhase4Logs
    }
}

// MARK: - AppConfig Extension
extension AppConfig {
    /// 使用假数据模式（从 ConfigManager 读取）
    static var useMockData: Bool {
        get { ConfigManager.shared.useMockData }
        set { ConfigManager.shared.useMockData = newValue }
    }
    
    /// 是否启用流式响应（从 ConfigManager 读取）
    static var enableStream: Bool {
        get { ConfigManager.shared.enableStream }
        set { ConfigManager.shared.enableStream = newValue }
    }
    
    /// 最大 token 数（从 ConfigManager 读取）
    static var maxTokens: Int {
        get { ConfigManager.shared.maxTokens }
        set { ConfigManager.shared.maxTokens = newValue }
    }

    /// Phase4（turnId/itemId）相关日志开关（从 ConfigManager 读取）
    static var enablePhase4Logs: Bool {
        get { ConfigManager.shared.enablePhase4Logs }
        set { ConfigManager.shared.enablePhase4Logs = newValue }
    }
}
