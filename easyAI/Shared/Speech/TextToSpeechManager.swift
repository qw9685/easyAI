//
//  TextToSpeechManager.swift
//  easyAI
//
//  Minimal text-to-speech manager using AVSpeechSynthesizer.
//

import AVFoundation
import Foundation

@MainActor
final class TextToSpeechManager: NSObject {
    static let shared = TextToSpeechManager()

    private let synthesizer = AVSpeechSynthesizer()
    private var lastProgressLogTime: TimeInterval = 0
    private var lastStreamedText: String = ""
    private var pendingStreamBuffer: String = ""
    private var isStreamingSessionActive: Bool = false
    private struct QueuedSpeech {
        let text: String
        let language: String
    }
    private var speechQueue: [QueuedSpeech] = []
    private var isQueuePlaying: Bool = false

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: String = "zh-CN") {
        guard !AppConfig.ttsMuted else { return }
        let cleaned = sanitizeForSpeech(text)
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        prepareAudioSession()
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        enqueueSpeech(trimmed, language: language)
        log("tts start | chars=\(trimmed.count)")
    }

    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
            log("tts stop")
        }
        speechQueue.removeAll()
        isQueuePlaying = false
        pendingStreamBuffer.removeAll()
        lastStreamedText = ""
        isStreamingSessionActive = false
        deactivateAudioSession()
    }

    func handleMuteChanged() {
        if AppConfig.ttsMuted {
            if synthesizer.isSpeaking {
                synthesizer.pauseSpeaking(at: .word)
                log("tts mute")
            }
        } else {
            if synthesizer.isPaused {
                synthesizer.continueSpeaking()
                log("tts unmute")
            } else if !pendingStreamBuffer.isEmpty || !speechQueue.isEmpty {
                flushPendingStreamBuffer(force: true)
                playNextFromQueueIfNeeded()
            }
        }
    }

    func startStreamingSession() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isStreamingSessionActive = true
        lastStreamedText = ""
        pendingStreamBuffer = ""
        speechQueue.removeAll()
        isQueuePlaying = false
    }

    func updateStreamingText(_ fullText: String, language: String = "zh-CN") {
        guard isStreamingSessionActive else { return }

        let delta: String
        if fullText.hasPrefix(lastStreamedText) {
            delta = String(fullText.dropFirst(lastStreamedText.count))
        } else {
            delta = fullText
        }

        lastStreamedText = fullText
        if delta.isEmpty { return }

        pendingStreamBuffer.append(delta)

        if AppConfig.ttsMuted {
            return
        }

        flushPendingStreamBuffer(force: false, language: language)
    }

    func finishStreamingSession(language: String = "zh-CN") {
        guard isStreamingSessionActive else { return }
        isStreamingSessionActive = false
        if AppConfig.ttsMuted {
            return
        }
        flushPendingStreamBuffer(force: true, language: language)
    }
}

private extension TextToSpeechManager {
    func prepareAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            // Best effort; TTS can still work without a configured session.
        }
    }

    func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Best effort.
        }
    }

    func sanitizeForSpeech(_ text: String) -> String {
        var output = text

        // Drop fenced code blocks.
        output = replaceRegex(in: output, pattern: "```[\\s\\S]*?```", with: " ")

        // Replace images/links with their visible text.
        output = replaceRegex(in: output, pattern: "!\\[([^\\]]*)\\]\\([^\\)]*\\)", with: "$1")
        output = replaceRegex(in: output, pattern: "\\[([^\\]]+)\\]\\([^\\)]*\\)", with: "$1")

        // Strip inline code markers while keeping content.
        output = replaceRegex(in: output, pattern: "`([^`]*)`", with: "$1")

        // Remove basic markdown decorations and HTML tags.
        output = replaceRegex(in: output, pattern: "<[^>]+>", with: " ")
        output = replaceRegex(in: output, pattern: "(\\*\\*|__|~~)", with: "")

        // Remove list/quote/heading markers at line start.
        output = replaceRegex(in: output, pattern: "(?m)^\\s{0,3}([#>\\-\\*+]|\\d+\\.)\\s+", with: "")

        // Remove URLs.
        output = replaceRegex(in: output, pattern: "https?://\\S+", with: " ")

        // Remove emoji and joiner/variation selectors.
        output = String(output.unicodeScalars.filter { scalar in
            if scalar.value == 0x200D { return false } // ZWJ
            if scalar.value == 0xFE0E || scalar.value == 0xFE0F { return false } // variation selectors
            if scalar.properties.isEmoji || scalar.properties.isEmojiPresentation { return false }
            return !CharacterSet.controlCharacters.contains(scalar)
        })

        // Collapse whitespace.
        output = replaceRegex(in: output, pattern: "\\s+", with: " ")
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func replaceRegex(in text: String, pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }

    func enqueueSpeech(_ text: String, language: String) {
        speechQueue.append(QueuedSpeech(text: text, language: language))
        if !isQueuePlaying {
            playNextFromQueueIfNeeded()
        }
    }

    func shouldFlushStreamBuffer(_ text: String) -> Bool {
        return text.rangeOfCharacter(from: CharacterSet(charactersIn: "。！？.!?\n")) != nil
    }

    func flushPendingStreamBuffer(force: Bool, language: String = "zh-CN") {
        guard !pendingStreamBuffer.isEmpty else { return }
        if !force && !shouldFlushStreamBuffer(pendingStreamBuffer) {
            return
        }

        let flushText: String
        if force {
            flushText = pendingStreamBuffer
            pendingStreamBuffer.removeAll()
        } else {
            let boundarySet = CharacterSet(charactersIn: "。！？.!?\n")
            guard let lastBoundary = pendingStreamBuffer.rangeOfCharacter(from: boundarySet, options: .backwards) else {
                return
            }
            let head = String(pendingStreamBuffer[..<lastBoundary.upperBound])
            let tail = String(pendingStreamBuffer[lastBoundary.upperBound...])
            flushText = head
            pendingStreamBuffer = tail
        }

        let cleaned = sanitizeForSpeech(flushText)
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            enqueueSpeech(trimmed, language: language)
            if force {
                log("tts stream flush | chars=\(trimmed.count)")
            }
        }
    }

    func playNextFromQueueIfNeeded() {
        guard !AppConfig.ttsMuted else { return }
        guard !synthesizer.isSpeaking, !synthesizer.isPaused else { return }
        guard !speechQueue.isEmpty else {
            isQueuePlaying = false
            return
        }
        isQueuePlaying = true
        let next = speechQueue.removeFirst()
        prepareAudioSession()
        let utterance = AVSpeechUtterance(string: next.text)
        utterance.voice = resolvedVoice(language: next.language)
        utterance.rate = Float(clampedSpeechRate())
        utterance.pitchMultiplier = Float(clampedPitch())
        synthesizer.speak(utterance)
    }

    func resolvedVoice(language: String) -> AVSpeechSynthesisVoice? {
        if let id = AppConfig.ttsVoiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: id) {
            return voice
        }
        return AVSpeechSynthesisVoice(language: language)
    }

    func clampedSpeechRate() -> Double {
        let minRate = Double(AVSpeechUtteranceMinimumSpeechRate)
        let maxRate = Double(AVSpeechUtteranceMaximumSpeechRate)
        return min(max(AppConfig.ttsRate, minRate), maxRate)
    }

    func clampedPitch() -> Double {
        return min(max(AppConfig.ttsPitch, 0.5), 2.0)
    }
}

extension TextToSpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.handleSpeechStart()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        let total = utterance.speechString.count
        let current = min(characterRange.location, total)
        Task { @MainActor [weak self] in
            self?.handleSpeechProgress(current: current, total: total)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let isStillSpeaking = synthesizer.isSpeaking
        Task { @MainActor [weak self] in
            self?.handleSpeechFinish(isStillSpeaking: isStillSpeaking)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.handleSpeechCancel()
        }
    }
}

private extension TextToSpeechManager {
    func handleSpeechStart() {
        lastProgressLogTime = 0
    }

    func handleSpeechProgress(current: Int, total: Int) {
        let now = Date().timeIntervalSince1970
        if now - lastProgressLogTime < 0.5 { return }
        lastProgressLogTime = now

        let percent = total > 0 ? Int((Double(current) / Double(total)) * 100) : 0
        log("tts progress | \(current)/\(total) (\(percent)%)")
    }

    func handleSpeechFinish(isStillSpeaking: Bool) {
        log("tts finish")
        playNextFromQueueIfNeeded()
        if !isStillSpeaking && speechQueue.isEmpty {
            deactivateAudioSession()
        }
    }

    func handleSpeechCancel() {
        log("tts cancel")
        deactivateAudioSession()
        isQueuePlaying = false
    }

    func log(_ message: String) {
        if AppConfig.enablephaseLogs {
            print(message)
        }
    }
}
