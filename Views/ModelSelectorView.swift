//
//  ModelSelectorView.swift
//  EasyAI
//
//  Created on 2024
//

import SwiftUI

struct ModelSelectorView: View {
    @Binding var selectedModel: AIModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(AIModel.availableModels) { model in
                    ModelRow(
                        model: model,
                        isSelected: model.id == selectedModel.id
                    ) {
                        selectedModel = model
                        dismiss()
                    }
                }
            }
            .navigationTitle("选择AI模型")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ModelRow: View {
    let model: AIModel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ModelSelectorView(selectedModel: .constant(AIModel.defaultModel))
}

