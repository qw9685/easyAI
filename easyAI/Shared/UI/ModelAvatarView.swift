//
//  ModelAvatarView.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 模型头像/徽标视图
//
//


import SwiftUI

struct ModelAvatarView: View {
    let name: String
    let provider: ModelProvider
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarColor)
            Text(initials)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }

    private var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "AI" }

        let parts = trimmed
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        if parts.count >= 2 {
            let first = parts[0].prefix(1)
            let second = parts[1].prefix(1)
            return "\(first)\(second)".uppercased()
        }

        let prefix = trimmed.prefix(2)
        return prefix.uppercased()
    }

    private var avatarColor: Color {
        let lowercased = name.lowercased()
        if lowercased.contains("gpt") || lowercased.contains("openai") {
            return Color(red: 0.25, green: 0.52, blue: 0.96) // 蓝色
        }
        if lowercased.contains("claude") || lowercased.contains("anthropic") {
            return Color(red: 0.96, green: 0.57, blue: 0.24) // 橙色
        }
        if lowercased.contains("gemini") {
            return Color(red: 0.20, green: 0.65, blue: 0.58) // 绿色
        }
        if lowercased.contains("llama") {
            return Color(red: 0.62, green: 0.45, blue: 0.28) // 棕色
        }
        if lowercased.contains("qwen") {
            return Color(red: 0.20, green: 0.60, blue: 0.75) // 青色
        }
        if lowercased.contains("mistral") {
            return Color(red: 0.58, green: 0.42, blue: 0.90) // 紫色
        }
        if lowercased.contains("deepseek") {
            return Color(red: 0.91, green: 0.30, blue: 0.40) // 红色
        }

        switch provider {
        case .openrouter:
            return Color(red: 0.33, green: 0.45, blue: 0.58) // 钢蓝
        }
    }
}
