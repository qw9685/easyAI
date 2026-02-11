//
//  PromptTemplate.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - Prompt 模板定义
//

import Foundation

struct PromptTemplate: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let promptTemplate: String
    let recommendedModelId: String
    let defaultParams: [String: String]
}

