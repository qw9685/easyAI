import Foundation

enum TaskType: String {
    case general
    case coding
    case translation
    case summarization
    case writing
    case vision
}

struct TaskIntent {
    let type: TaskType
    let requiresVision: Bool
    let estimatedContextChars: Int
    let inputLength: Int
}
