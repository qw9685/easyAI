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
import AVFoundation

/// 配置管理器，使用 UserDefaults 持久化配置
class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    // MARK: - UserDefaults 键
    private let useMockDataKey = "Config.useMockData"
    private let enableStreamKey = "Config.enableStream"
    private let enableTypewriterKey = "Config.enableTypewriter"
    private let typewriterSpeedKey = "Config.typewriterSpeed"
    private let typewriterRefreshRateKey = "Config.typewriterRefreshRate"
    private let maxTokensKey = "Config.maxTokens"
    private let enablephaseLogsKey = "Config.enablephaseLogs"
    private let contextStrategyKey = "Config.contextStrategy"
    private let selectedModelIdKey = "Config.selectedModelId"
    private let favoriteModelIdsKey = "Config.favoriteModelIds"
    private let selectedThemeIdKey = "Config.selectedThemeId"
    private let ttsMutedKey = "Config.ttsMuted"
    private let ttsVoiceIdentifierKey = "Config.ttsVoiceIdentifier"
    private let ttsRateKey = "Config.ttsRate"
    private let ttsPitchKey = "Config.ttsPitch"
    
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

    @Published var enableTypewriter: Bool {
        didSet {
            UserDefaults.standard.set(enableTypewriter, forKey: enableTypewriterKey)
        }
    }

    @Published var typewriterSpeed: Double {
        didSet {
            UserDefaults.standard.set(typewriterSpeed, forKey: typewriterSpeedKey)
        }
    }

    @Published var typewriterRefreshRate: Double {
        didSet {
            UserDefaults.standard.set(typewriterRefreshRate, forKey: typewriterRefreshRateKey)
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

    @Published var selectedThemeId: String? {
        didSet {
            if let selectedThemeId {
                UserDefaults.standard.set(selectedThemeId, forKey: selectedThemeIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: selectedThemeIdKey)
            }
        }
    }

    @Published var ttsMuted: Bool {
        didSet {
            UserDefaults.standard.set(ttsMuted, forKey: ttsMutedKey)
        }
    }

    @Published var ttsVoiceIdentifier: String? {
        didSet {
            if let ttsVoiceIdentifier {
                UserDefaults.standard.set(ttsVoiceIdentifier, forKey: ttsVoiceIdentifierKey)
            } else {
                UserDefaults.standard.removeObject(forKey: ttsVoiceIdentifierKey)
            }
        }
    }

    @Published var ttsRate: Double {
        didSet {
            UserDefaults.standard.set(ttsRate, forKey: ttsRateKey)
        }
    }

    @Published var ttsPitch: Double {
        didSet {
            UserDefaults.standard.set(ttsPitch, forKey: ttsPitchKey)
        }
    }

    
    private init() {
        // 从 UserDefaults 读取配置，如果没有则使用默认值
        self.useMockData = UserDefaults.standard.object(forKey: useMockDataKey) as? Bool ?? false
        self.enableStream = UserDefaults.standard.object(forKey: enableStreamKey) as? Bool ?? true
        self.enableTypewriter = UserDefaults.standard.object(forKey: enableTypewriterKey) as? Bool ?? true
        let storedSpeed = UserDefaults.standard.object(forKey: typewriterSpeedKey) as? Double ?? 1.0
        self.typewriterSpeed = max(0.1, min(8.0, storedSpeed))
        let storedRate = UserDefaults.standard.object(forKey: typewriterRefreshRateKey) as? Double ?? 30
        self.typewriterRefreshRate = max(5, min(120, storedRate))
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
        self.selectedThemeId = UserDefaults.standard.string(forKey: selectedThemeIdKey)
        self.ttsMuted = UserDefaults.standard.object(forKey: ttsMutedKey) as? Bool ?? false
        self.ttsVoiceIdentifier = UserDefaults.standard.string(forKey: ttsVoiceIdentifierKey)

        let storedTtsRate = UserDefaults.standard.object(forKey: ttsRateKey) as? Double
        let minRate = Double(AVSpeechUtteranceMinimumSpeechRate)
        let maxRate = Double(AVSpeechUtteranceMaximumSpeechRate)
        let defaultRate = Double(AVSpeechUtteranceDefaultSpeechRate)
        let clampedRate = min(max(storedTtsRate ?? defaultRate, minRate), maxRate)
        self.ttsRate = clampedRate

        let storedPitch = UserDefaults.standard.object(forKey: ttsPitchKey) as? Double
        let clampedPitch = min(max(storedPitch ?? 1.0, 0.5), 2.0)
        self.ttsPitch = clampedPitch

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

    static var enableTypewriter: Bool {
        get { ConfigManager.shared.enableTypewriter }
        set { ConfigManager.shared.enableTypewriter = newValue }
    }

    static var typewriterSpeed: Double {
        get { ConfigManager.shared.typewriterSpeed }
        set { ConfigManager.shared.typewriterSpeed = newValue }
    }

    static var typewriterRefreshRate: Double {
        get { ConfigManager.shared.typewriterRefreshRate }
        set { ConfigManager.shared.typewriterRefreshRate = newValue }
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

    static var selectedThemeId: String? {
        get { ConfigManager.shared.selectedThemeId }
        set { ConfigManager.shared.selectedThemeId = newValue }
    }

    static var ttsMuted: Bool {
        get { ConfigManager.shared.ttsMuted }
        set { ConfigManager.shared.ttsMuted = newValue }
    }

    static var ttsVoiceIdentifier: String? {
        get { ConfigManager.shared.ttsVoiceIdentifier }
        set { ConfigManager.shared.ttsVoiceIdentifier = newValue }
    }

    static var ttsRate: Double {
        get { ConfigManager.shared.ttsRate }
        set { ConfigManager.shared.ttsRate = newValue }
    }

    static var ttsPitch: Double {
        get { ConfigManager.shared.ttsPitch }
        set { ConfigManager.shared.ttsPitch = newValue }
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
