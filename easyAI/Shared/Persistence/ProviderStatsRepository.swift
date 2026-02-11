//
//  ProviderStatsRepository.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - Provider 统计持久化（UserDefaults）
//

import Foundation

final class ProviderStatsRepository {
    static let shared = ProviderStatsRepository()

    private let key = "ProviderStats.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    private init() {}

    func fetchAll() -> [ProviderStats] {
        lock.lock()
        defer { lock.unlock() }
        return Array(readAllLocked().values)
            .sorted { $0.providerId.localizedCaseInsensitiveCompare($1.providerId) == .orderedAscending }
    }

    func recordRequest(providerId: String) {
        mutate(providerId: providerId) { stats in
            stats.requestCount += 1
            stats.lastUpdatedAt = Date()
        }
    }

    func recordSuccess(providerId: String, metrics: MessageMetrics?) {
        mutate(providerId: providerId) { stats in
            stats.successCount += 1
            if let latency = metrics?.latencyMs {
                stats.totalLatencyMs += max(0, latency)
                stats.latencySampleCount += 1
            }
            if let cost = metrics?.estimatedCostUSD, cost >= 0 {
                stats.totalCostUSD += cost
                stats.costSampleCount += 1
            }
            if let tokens = metrics?.totalTokens, tokens >= 0 {
                stats.totalTokens += tokens
                stats.tokenSampleCount += 1
            }
            stats.lastUpdatedAt = Date()
        }
    }

    func recordFailure(providerId: String) {
        mutate(providerId: providerId) { stats in
            stats.failureCount += 1
            stats.lastUpdatedAt = Date()
        }
    }

    func recordFailure(providerId: String, category: ChatErrorCategory?) {
        mutate(providerId: providerId) { stats in
            stats.failureCount += 1
            if let category {
                var counts = stats.errorCategoryCounts ?? [:]
                counts[category.rawValue, default: 0] += 1
                stats.errorCategoryCounts = counts
            }
            stats.lastUpdatedAt = Date()
        }
    }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func mutate(providerId: String, update: (inout ProviderStats) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        var all = readAllLocked()
        var stats = all[providerId] ?? ProviderStats(providerId: providerId)
        update(&stats)
        all[providerId] = stats
        writeAllLocked(all)
    }

    private func readAllLocked() -> [String: ProviderStats] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }
        return (try? decoder.decode([String: ProviderStats].self, from: data)) ?? [:]
    }

    private func writeAllLocked(_ value: [String: ProviderStats]) {
        guard let data = try? encoder.encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
