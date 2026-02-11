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
    private let fallbackEnabledKey = "Config.fallbackEnabled"
    private let fallbackMaxRetriesKey = "Config.fallbackMaxRetries"
    private let nativeFallbackDepthKey = "Config.nativeFallbackDepth"
    private let fallbackBudgetModeKey = "Config.fallbackBudgetMode"
    private let routingModeKey = "Config.routingMode"
    private let budgetModeKey = "Config.budgetMode"
    private let fallbackRetryOnRateLimitedKey = "Config.fallbackRetryOnRateLimited"
    private let fallbackRetryOnTimeoutKey = "Config.fallbackRetryOnTimeout"
    private let fallbackRetryOnServerUnavailableKey = "Config.fallbackRetryOnServerUnavailable"
    private let fallbackRetryOnNetworkKey = "Config.fallbackRetryOnNetwork"
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

    @Published var fallbackEnabled: Bool {
        didSet {
            UserDefaults.standard.set(fallbackEnabled, forKey: fallbackEnabledKey)
        }
    }

    @Published var fallbackMaxRetries: Int {
        didSet {
            let clamped = min(max(fallbackMaxRetries, 0), 3)
            if clamped != fallbackMaxRetries {
                fallbackMaxRetries = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: fallbackMaxRetriesKey)
        }
    }

    @Published var nativeFallbackDepth: Int {
        didSet {
            let clamped = min(max(nativeFallbackDepth, 0), 3)
            if clamped != nativeFallbackDepth {
                nativeFallbackDepth = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: nativeFallbackDepthKey)
        }
    }

    @Published var fallbackBudgetMode: FallbackBudgetMode {
        didSet {
            UserDefaults.standard.set(fallbackBudgetMode.rawValue, forKey: fallbackBudgetModeKey)
        }
    }

    @Published var routingMode: RoutingMode {
        didSet {
            UserDefaults.standard.set(routingMode.rawValue, forKey: routingModeKey)
        }
    }

    @Published var budgetMode: BudgetMode {
        didSet {
            UserDefaults.standard.set(budgetMode.rawValue, forKey: budgetModeKey)
        }
    }

    @Published var fallbackRetryOnRateLimited: Bool {
        didSet {
            UserDefaults.standard.set(fallbackRetryOnRateLimited, forKey: fallbackRetryOnRateLimitedKey)
        }
    }

    @Published var fallbackRetryOnTimeout: Bool {
        didSet {
            UserDefaults.standard.set(fallbackRetryOnTimeout, forKey: fallbackRetryOnTimeoutKey)
        }
    }

    @Published var fallbackRetryOnServerUnavailable: Bool {
        didSet {
            UserDefaults.standard.set(fallbackRetryOnServerUnavailable, forKey: fallbackRetryOnServerUnavailableKey)
        }
    }

    @Published var fallbackRetryOnNetwork: Bool {
        didSet {
            UserDefaults.standard.set(fallbackRetryOnNetwork, forKey: fallbackRetryOnNetworkKey)
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
        self.fallbackEnabled = UserDefaults.standard.object(forKey: fallbackEnabledKey) as? Bool ?? true
        let storedRetries = UserDefaults.standard.object(forKey: fallbackMaxRetriesKey) as? Int ?? 2
        self.fallbackMaxRetries = min(max(storedRetries, 0), 3)
        let storedNativeFallbackDepth = UserDefaults.standard.object(forKey: nativeFallbackDepthKey) as? Int ?? 2
        self.nativeFallbackDepth = min(max(storedNativeFallbackDepth, 0), 3)
        let storedFallbackMode = UserDefaults.standard.string(forKey: fallbackBudgetModeKey) ?? ""
        self.fallbackBudgetMode = FallbackBudgetMode(rawValue: storedFallbackMode) ?? .freeFirst
        let storedRoutingMode = UserDefaults.standard.string(forKey: routingModeKey) ?? ""
        self.routingMode = RoutingMode(rawValue: storedRoutingMode) ?? .manual
        let storedBudgetMode = UserDefaults.standard.string(forKey: budgetModeKey) ?? ""
        self.budgetMode = BudgetMode(rawValue: storedBudgetMode) ?? .costEffective
        self.fallbackRetryOnRateLimited = UserDefaults.standard.object(forKey: fallbackRetryOnRateLimitedKey) as? Bool ?? true
        self.fallbackRetryOnTimeout = UserDefaults.standard.object(forKey: fallbackRetryOnTimeoutKey) as? Bool ?? true
        self.fallbackRetryOnServerUnavailable = UserDefaults.standard.object(forKey: fallbackRetryOnServerUnavailableKey) as? Bool ?? true
        self.fallbackRetryOnNetwork = UserDefaults.standard.object(forKey: fallbackRetryOnNetworkKey) as? Bool ?? true
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

        // TTS 参数做合法区间 clamp，避免写入非法值导致系统播放异常
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

    static var fallbackEnabled: Bool {
        get { ConfigManager.shared.fallbackEnabled }
        set { ConfigManager.shared.fallbackEnabled = newValue }
    }

    static var fallbackMaxRetries: Int {
        get { ConfigManager.shared.fallbackMaxRetries }
        set { ConfigManager.shared.fallbackMaxRetries = newValue }
    }

    static var nativeFallbackDepth: Int {
        get { ConfigManager.shared.nativeFallbackDepth }
        set { ConfigManager.shared.nativeFallbackDepth = newValue }
    }

    static var fallbackBudgetMode: FallbackBudgetMode {
        get { ConfigManager.shared.fallbackBudgetMode }
        set { ConfigManager.shared.fallbackBudgetMode = newValue }
    }

    static var routingMode: RoutingMode {
        get { ConfigManager.shared.routingMode }
        set { ConfigManager.shared.routingMode = newValue }
    }

    static var budgetMode: BudgetMode {
        get { ConfigManager.shared.budgetMode }
        set { ConfigManager.shared.budgetMode = newValue }
    }

    static var fallbackRetryOnRateLimited: Bool {
        get { ConfigManager.shared.fallbackRetryOnRateLimited }
        set { ConfigManager.shared.fallbackRetryOnRateLimited = newValue }
    }

    static var fallbackRetryOnTimeout: Bool {
        get { ConfigManager.shared.fallbackRetryOnTimeout }
        set { ConfigManager.shared.fallbackRetryOnTimeout = newValue }
    }

    static var fallbackRetryOnServerUnavailable: Bool {
        get { ConfigManager.shared.fallbackRetryOnServerUnavailable }
        set { ConfigManager.shared.fallbackRetryOnServerUnavailable = newValue }
    }

    static var fallbackRetryOnNetwork: Bool {
        get { ConfigManager.shared.fallbackRetryOnNetwork }
        set { ConfigManager.shared.fallbackRetryOnNetwork = newValue }
    }

    static var typewriterSpeed: Double {
        get { ConfigManager.shared.typewriterSpeed }
        set { ConfigManager.shared.typewriterSpeed = newValue }
    }

    static var typewriterRefreshRate: Double {
        get { ConfigManager.shared.typewriterRefreshRate }
        set { ConfigManager.shared.typewriterRefreshRate = newValue }
    }

    static func clampTypewriterSpeed(_ speed: Double) -> Double {
        max(0.1, min(8.0, speed))
    }

    static func typewriterMinCharsPerTick(for speed: Double) -> Int {
        let normalized = clampTypewriterSpeed(speed)
        if normalized >= 7.0 { return 4 }
        if normalized >= 5.0 { return 3 }
        if normalized >= 3.0 { return 2 }
        return 1
    }

    static func typewriterMaxCharsPerTick(for speed: Double) -> Int {
        let normalized = clampTypewriterSpeed(speed)
        if normalized >= 7.0 { return 14 }
        if normalized >= 5.0 { return 12 }
        if normalized >= 3.0 { return 10 }
        return 8
    }

    static func typewriterSpeedTierName(for speed: Double) -> String {
        let normalized = clampTypewriterSpeed(speed)
        if normalized >= 7.0 { return "极速" }
        if normalized >= 5.0 { return "高速" }
        if normalized >= 3.0 { return "流畅" }
        return "标准"
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

enum FallbackBudgetMode: String, CaseIterable, Identifiable {
    case freeFirst
    case costEffective
    case qualityFirst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .freeFirst:
            return "免费优先"
        case .costEffective:
            return "性价比"
        case .qualityFirst:
            return "质量优先"
        }
    }
}

enum RoutingMode: String, CaseIterable, Identifiable, Codable {
    case manual
    case smart

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual:
            return "手动"
        case .smart:
            return "智能"
        }
    }
}

enum BudgetMode: String, CaseIterable, Identifiable, Codable {
    case freeFirst
    case costEffective
    case qualityFirst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .freeFirst:
            return "免费优先"
        case .costEffective:
            return "性价比"
        case .qualityFirst:
            return "质量优先"
        }
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
