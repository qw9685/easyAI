//
//  ModelListState.swift
//  EasyAI
//
//  创建于 2026
//

import Foundation

struct ModelListState: Equatable {
    var models: [AIModel]
    var selectedModel: AIModel?
    var isLoading: Bool
    var errorMessage: String?

    static let idle = ModelListState(models: [], selectedModel: nil, isLoading: false, errorMessage: nil)
}

