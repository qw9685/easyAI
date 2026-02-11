//
//  AsyncExecutor.swift
//  easyAI
//
//  通用异步桥接执行器
//

import Foundation

extension RuntimeTools {
    enum AsyncExecutor {
        static func run<T>(
            qos: DispatchQoS.QoSClass = .userInitiated,
            _ work: @escaping () throws -> T
        ) async throws -> T {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: qos).async {
                    do {
                        continuation.resume(returning: try work())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        static func run<T>(
            qos: DispatchQoS.QoSClass = .userInitiated,
            _ work: @escaping () -> T
        ) async -> T {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: qos).async {
                    continuation.resume(returning: work())
                }
            }
        }

        static func run<T>(
            on queue: DispatchQueue,
            _ work: @escaping () throws -> T
        ) async throws -> T {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    do {
                        continuation.resume(returning: try work())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        static func run<T>(
            on queue: DispatchQueue,
            _ work: @escaping () -> T
        ) async -> T {
            await withCheckedContinuation { continuation in
                queue.async {
                    continuation.resume(returning: work())
                }
            }
        }
    }
}
