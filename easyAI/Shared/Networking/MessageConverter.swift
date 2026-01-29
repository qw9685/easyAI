//
//  MessageConverter.swift
//  EasyAI
//
//  创建于 2026
//


import Foundation

/// 消息转换工具
/// 负责将 Message 模型转换为 OpenRouter API 所需的格式
struct MessageConverter {
    /// 将 Message 转换为 OpenRouter API 格式
    /// 符合 OpenRouter 多模态消息格式：https://openrouter.ai/docs/guides/overview/multimodal/images
    static func toOpenRouterFormat(_ message: Message) -> [String: Any] {
        var messageDict: [String: Any] = [
            "role": message.role.rawValue
        ]
        
        // 如果消息包含媒体内容，使用多模态格式
        if message.hasMedia {
            var contentArray: [[String: Any]] = []
            
            // 根据 OpenRouter 文档建议：先发送文本，再发送媒体
            if !message.content.isEmpty {
                contentArray.append([
                    "type": "text",
                    "text": message.content
                ])
            }
            
            // 添加所有媒体内容
            for media in message.mediaContents {
                let mediaContent: [String: Any] = [
                    "type": media.type.openRouterContentType,
                    media.type.openRouterContentType: [
                        "url": media.getDataURL()
                    ]
                ]
                contentArray.append(mediaContent)
            }
            
            messageDict["content"] = contentArray
        } else {
            // 普通文本消息
            messageDict["content"] = message.content
        }
        
        return messageDict
    }
    
    /// 批量转换消息列表
    static func toOpenRouterFormat(_ messages: [Message]) -> [[String: Any]] {
        messages.map { toOpenRouterFormat($0) }
    }
    
    /// 获取消息的调试信息
    static func getDebugInfo(_ message: Message) -> String {
        guard message.hasMedia else {
            return "text only"
        }
        
        let mediaInfo = message.mediaContents.map { media in
            "\(media.type.rawValue): \(media.mimeType) (\(media.fileSizeFormatted))"
        }.joined(separator: ", ")
        
        let hasText = !message.content.isEmpty
        return "\(hasText ? "text + " : "")\(mediaInfo)"
    }
}


