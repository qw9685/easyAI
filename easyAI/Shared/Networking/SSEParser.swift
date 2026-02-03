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
    private enum Event {
        case delta(String)
        case done
    }

    func parse(asyncBytes: URLSession.AsyncBytes) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var buffer = Data()
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

                            switch parseLine(line) {
                            case .delta(let delta):
                                continuation.yield(delta)
                            case .done:
                                continuation.finish()
                                return
                            case .none:
                                break
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
        }
    }

    private func parseLine(_ line: String) -> Event? {
        guard line.hasPrefix("data: ") else { return nil }
        let jsonString = String(line.dropFirst(6))
        if jsonString.trimmingCharacters(in: .whitespaces) == "[DONE]" {
            return .done
        }

        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        do {
            let decoder = JSONDecoder()
            let streamResponse = try decoder.decode(OpenRouterStreamResponse.self, from: jsonData)
            if let delta = streamResponse.choices.first?.delta.content, !delta.isEmpty {
                return .delta(delta)
            }
        } catch {
            if let jsonPreview = String(data: jsonData.prefix(200), encoding: .utf8) {
                print("[SSEParser] ⚠️ Failed to parse SSE data: \(error)")
                print("  JSON preview: \(jsonPreview)")
            }
        }
        return nil
    }
}
