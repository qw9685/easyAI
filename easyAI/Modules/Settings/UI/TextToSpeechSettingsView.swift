//
//  TextToSpeechSettingsView.swift
//  easyAI
//
//  语音朗读增强设置
//

import SwiftUI
import AVFoundation

struct TextToSpeechSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var configManager = ConfigManager.shared

    private var voiceSelection: Binding<String> {
        Binding(
            get: { configManager.ttsVoiceIdentifier ?? "" },
            set: { newValue in
                configManager.ttsVoiceIdentifier = newValue.isEmpty ? nil : newValue
            }
        )
    }

    private var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .sorted { lhs, rhs in
                if lhs.language == rhs.language {
                    return lhs.name < rhs.name
                }
                return lhs.language < rhs.language
            }
    }

    private var minRate: Double { Double(AVSpeechUtteranceMinimumSpeechRate) }
    private var maxRate: Double { Double(AVSpeechUtteranceMaximumSpeechRate) }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("音色")) {
                    Picker("音色", selection: voiceSelection) {
                        Text("系统默认").tag("")
                        ForEach(availableVoices, id: \.identifier) { voice in
                            Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(header: Text("语速")) {
                    HStack {
                        Text("语速")
                        Spacer()
                        Text(String(format: "%.2f", configManager.ttsRate))
                            .foregroundColor(AppThemeSwift.textSecondary)
                    }
                    Slider(value: $configManager.ttsRate, in: minRate...maxRate)
                        .tint(AppThemeSwift.accent)
                }

                Section(header: Text("音高")) {
                    HStack {
                        Text("音高")
                        Spacer()
                        Text(String(format: "%.2f", configManager.ttsPitch))
                            .foregroundColor(AppThemeSwift.textSecondary)
                    }
                    Slider(value: $configManager.ttsPitch, in: 0.5...2.0, step: 0.1)
                        .tint(AppThemeSwift.accent)
                }

            }
            .navigationTitle("语音朗读设置")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppThemeSwift.backgroundGradient)
            .tint(AppThemeSwift.accent)
            .listRowBackground(AppThemeSwift.surface)
            .listRowSeparatorTint(AppThemeSwift.border)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.light)
    }

    static func displayName(for voiceIdentifier: String?) -> String {
        guard let voiceIdentifier,
              let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) else {
            return "系统默认"
        }
        return voice.name
    }
}

#Preview {
    TextToSpeechSettingsView()
        .environmentObject(ThemeManager.shared)
}
