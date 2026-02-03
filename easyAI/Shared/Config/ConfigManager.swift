//
//  ConfigManager.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 配置持久化与全局开关管理
//
//


import Foundation
import SwiftUI
import Combine

/// 配置管理器，使用 UserDefaults 持久化配置
class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    // MARK: - UserDefaults 键
    private let useMockDataKey = "Config.useMockData"
    private let enableStreamKey = "Config.enableStream"
    private let maxTokensKey = "Config.maxTokens"
    private let enablephaseLogsKey = "Config.enablephaseLogs"
    private let contextStrategyKey = "Config.contextStrategy"
    private let selectedModelIdKey = "Config.selectedModelId"
    private let favoriteModelIdsKey = "Config.favoriteModelIds"
    
    // MARK: - 发布属性
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

    @Published var enablephaseLogs: Bool {
        didSet {
            UserDefaults.standard.set(enablephaseLogs, forKey: enablephaseLogsKey)
        }
    }

    @Published var contextStrategy: MessageContextStrategy {
        didSet {
            UserDefaults.standard.set(contextStrategy.rawValue, forKey: contextStrategyKey)
        }
    }

    @Published var selectedModelId: String? {
        didSet {
            if let selectedModelId {
                UserDefaults.standard.set(selectedModelId, forKey: selectedModelIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: selectedModelIdKey)
            }
        }
    }

    @Published var favoriteModelIds: [String] {
        didSet {
            UserDefaults.standard.set(favoriteModelIds, forKey: favoriteModelIdsKey)
        }
    }
    
    private init() {
        // 从 UserDefaults 读取配置，如果没有则使用默认值
        self.useMockData = UserDefaults.standard.object(forKey: useMockDataKey) as? Bool ?? false
        self.enableStream = UserDefaults.standard.object(forKey: enableStreamKey) as? Bool ?? true
        self.maxTokens = UserDefaults.standard.object(forKey: maxTokensKey) as? Int ?? 1000
#if DEBUG
        let defaultEnablephaseLogs = true
#else
        let defaultEnablephaseLogs = false
#endif
        self.enablephaseLogs = UserDefaults.standard.object(forKey: enablephaseLogsKey) as? Bool ?? defaultEnablephaseLogs
        let strategyRaw = UserDefaults.standard.string(forKey: contextStrategyKey)
        self.contextStrategy = MessageContextStrategy(rawValue: strategyRaw ?? "") ?? .fullContext
        self.selectedModelId = UserDefaults.standard.string(forKey: selectedModelIdKey)
        self.favoriteModelIds = UserDefaults.standard.stringArray(forKey: favoriteModelIdsKey) ?? []
    }
}

// MARK: - AppConfig 扩展
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

    /// phase（turnId/itemId）相关日志开关（从 ConfigManager 读取）
    static var enablephaseLogs: Bool {
        get { ConfigManager.shared.enablephaseLogs }
        set { ConfigManager.shared.enablephaseLogs = newValue }
    }

    static var contextStrategy: MessageContextStrategy {
        get { ConfigManager.shared.contextStrategy }
        set { ConfigManager.shared.contextStrategy = newValue }
    }

    /// 上次选择的模型 ID（从 ConfigManager 读取）
    static var selectedModelId: String? {
        get { ConfigManager.shared.selectedModelId }
        set { ConfigManager.shared.selectedModelId = newValue }
    }

    /// 收藏的模型 ID（从 ConfigManager 读取）
    static var favoriteModelIds: [String] {
        get { ConfigManager.shared.favoriteModelIds }
        set { ConfigManager.shared.favoriteModelIds = newValue }
    }
}

enum MessageContextStrategy: String, CaseIterable, Identifiable {
    case fullContext
    case textOnly
    case currentOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullContext:
            return "全部上下文"
        case .textOnly:
            return "仅文本"
        case .currentOnly:
            return "仅当前轮"
        }
    }
}
