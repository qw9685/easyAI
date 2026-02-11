//
//  ProviderStats.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - Provider 维度统计模型
//

import Foundation

struct ProviderStats: Codable, Identifiable, Hashable {
    let id: String
    let providerId: String
    var requestCount: Int
    var successCount: Int
    var failureCount: Int
    var totalLatencyMs: Int
    var totalCostUSD: Double
    var totalTokens: Int
    var latencySampleCount: Int
    var costSampleCount: Int
    var tokenSampleCount: Int
    var errorCategoryCounts: [String: Int]?
    var lastUpdatedAt: Date

    init(providerId: String) {
        self.id = providerId
        self.providerId = providerId
        self.requestCount = 0
        self.successCount = 0
        self.failureCount = 0
        self.totalLatencyMs = 0
        self.totalCostUSD = 0
        self.totalTokens = 0
        self.latencySampleCount = 0
        self.costSampleCount = 0
        self.tokenSampleCount = 0
        self.errorCategoryCounts = [:]
        self.lastUpdatedAt = Date()
    }

    var successRate: Double {
        guard requestCount > 0 else { return 0 }
        return Double(successCount) / Double(requestCount)
    }

    var averageLatencyMs: Int? {
        guard latencySampleCount > 0 else { return nil }
        return Int((Double(totalLatencyMs) / Double(latencySampleCount)).rounded())
    }

    var averageCostUSD: Double? {
        guard costSampleCount > 0 else { return nil }
        return totalCostUSD / Double(costSampleCount)
    }

    var averageTokens: Int? {
        guard tokenSampleCount > 0 else { return nil }
        return Int((Double(totalTokens) / Double(tokenSampleCount)).rounded())
    }

    func errorCount(for category: ChatErrorCategory) -> Int {
        errorCategoryCounts?[category.rawValue] ?? 0
    }
}
