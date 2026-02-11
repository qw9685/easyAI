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

    static func infer(content: String, hasMedia: Bool, requestMessages: [Message]) -> TaskIntent {
        let normalized = content.lowercased()
        let type: TaskType

        if hasMedia {
            type = .vision
        } else if normalized.contains("翻译") || normalized.contains("translate") {
            type = .translation
        } else if normalized.contains("总结") || normalized.contains("摘要") || normalized.contains("summary") {
            type = .summarization
        } else if normalized.contains("代码")
                    || normalized.contains("报错")
                    || normalized.contains("debug")
                    || normalized.contains("bug")
                    || normalized.contains("swift")
                    || normalized.contains("python")
                    || normalized.contains("javascript") {
            type = .coding
        } else if normalized.contains("写") || normalized.contains("文案") || normalized.contains("润色") {
            type = .writing
        } else {
            type = .general
        }

        let estimatedContextChars = requestMessages.reduce(0) { partial, message in
            partial + message.content.count
        }

        return TaskIntent(
            type: type,
            requiresVision: hasMedia,
            estimatedContextChars: estimatedContextChars,
            inputLength: content.count
        )
    }
}
