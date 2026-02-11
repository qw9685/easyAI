//
//  SSEParser.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 解析 SSE 流式数据
//
//


import Foundation

struct SSEParser {
    private let streamInactivityTimeoutSeconds: TimeInterval = 120

    private enum Event {
        case delta(String)
        case done
    }

    func parse(asyncBytes: URLSession.AsyncBytes) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let parseTask = Task {
                do {
                    var buffer = Data()
                    var lastMeaningfulEventTime = Date()
                    for try await byte in asyncBytes {
                        buffer.append(byte)
                        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                            var lineData = buffer[..<newlineIndex]
                            buffer = buffer[buffer.index(after: newlineIndex)...]

                            if lineData.last == 0x0D {
                                lineData = lineData.dropLast()
                            }

                            guard let line = String(data: lineData, encoding: .utf8) else {
                                continue
                            }

                            let hasLineContent = !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            if hasLineContent {
                                lastMeaningfulEventTime = Date()
                            }

                            switch parseLine(line) {
                            case .delta(let delta):
                                continuation.yield(delta)
                            case .done:
                                continuation.finish()
                                return
                            case .none:
                                break
                            }

                            if Date().timeIntervalSince(lastMeaningfulEventTime) >= streamInactivityTimeoutSeconds {
                                continuation.finish(throwing: URLError(.timedOut))
                                return
                            }
                        }
                    }

                    if !buffer.isEmpty, let remainingString = String(data: buffer, encoding: .utf8) {
                        switch parseLine(remainingString) {
                        case .delta(let delta):
                            continuation.yield(delta)
                        case .done:
                            continuation.finish()
                            return
                        case .none:
                            break
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                parseTask.cancel()
            }
        }
    }

    private func parseLine(_ line: String) -> Event? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty else { return nil }

        let lowercased = trimmedLine.lowercased()
        if lowercased.hasPrefix("event:") || lowercased.hasPrefix(":") {
            return nil
        }

        guard lowercased.hasPrefix("data:") else { return nil }
        let payloadStart = trimmedLine.index(trimmedLine.startIndex, offsetBy: 5)
        let jsonString = String(trimmedLine[payloadStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !jsonString.isEmpty else { return nil }
        if jsonString.uppercased() == "[DONE]" {
            return .done
        }

        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        do {
            let streamResponse = try DataTools.CodecCenter.jsonDecoder.decode(OpenRouterStreamResponse.self, from: jsonData)
            if let choice = streamResponse.choices.first {
                if let content = choice.delta.content, !content.isEmpty {
                    return .delta(content)
                }
                if let reasoning = choice.delta.reasoning, !reasoning.isEmpty {
                    return .delta(reasoning)
                }
            }
        } catch {
            if let jsonPreview = String(data: jsonData.prefix(200), encoding: .utf8) {
                RuntimeTools.AppDiagnostics.warn("SSEParser", "Failed to parse SSE data: \(error)")
                RuntimeTools.AppDiagnostics.debug("SSEParser", "JSON preview: \(jsonPreview)")
            }
        }
        return nil
    }
}
