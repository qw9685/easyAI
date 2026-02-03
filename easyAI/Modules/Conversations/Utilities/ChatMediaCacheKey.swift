//
//  ChatMediaCacheKey.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 生成媒体缓存 Key
//
//

import Foundation

enum ChatMediaCacheKey {
    static func imageKey(for media: MediaContent) -> String {
        "media.image.\(media.id.uuidString)"
    }
}

