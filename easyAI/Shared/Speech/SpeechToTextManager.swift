//
//  SpeechToTextManager.swift
//  easyAI
//
//  Minimal speech-to-text manager using Apple's Speech framework.
//

import Foundation
import Speech
import AVFoundation

final class SpeechToTextManager: NSObject {
    static let shared = SpeechToTextManager()

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private(set) var isRecognizing: Bool = false

    private override init() {
        super.init()
    }

    func requestPermissions() async -> Bool {
#if targetEnvironment(simulator)
        return false
#else
        let speechAllowed = await requestSpeechAuthorization()
        let micAllowed = await requestMicAuthorization()
        return speechAllowed && micAllowed
#endif
    }

    func startRecognition(
        baseText: String,
        onUpdate: @escaping (_ transcript: String, _ isFinal: Bool) -> Void,
        onError: @escaping (_ message: String) -> Void
    ) {
        stopRecognition()

#if targetEnvironment(simulator)
        onError("模拟器不支持录音，请在真机测试语音输入。")
        return
#else
        guard let recognizer, recognizer.isAvailable else {
            onError("语音识别不可用")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            onError("无法启动录音")
            return
        }

        guard audioSession.isInputAvailable else {
            onError("当前设备麦克风不可用")
            recognitionRequest = nil
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            return
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            recognitionRequest = nil
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            onError("无法开始录音")
            return
        }

        isRecognizing = true
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                let transcript = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                DispatchQueue.main.async {
                    onUpdate(transcript, isFinal)
                }
            }
            if let error {
                DispatchQueue.main.async {
                    self?.stopRecognition()
                    onError(error.localizedDescription)
                }
            }
        }
#endif
    }

    func stopRecognition() {
        isRecognizing = false

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionTask = nil
        recognitionRequest = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private extension SpeechToTextManager {
    func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func requestMicAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                continuation.resume(returning: true)
            case .denied:
                continuation.resume(returning: false)
            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            @unknown default:
                continuation.resume(returning: false)
            }
        }
    }
}
