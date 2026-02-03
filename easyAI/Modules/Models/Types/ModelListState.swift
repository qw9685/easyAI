//
//  ModelListState.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 模型列表状态结构
//
//

import Foundation

struct ModelListState: Equatable {
    var models: [AIModel]
    var selectedModel: AIModel?
    var isLoading: Bool
    var errorMessage: String?

    static let idle = ModelListState(models: [], selectedModel: nil, isLoading: false, errorMessage: nil)
}

