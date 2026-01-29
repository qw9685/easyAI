//
//  ChatMediaCacheKey.swift
//  EasyAI
//
//  创建于 2026
//

import Foundation

enum ChatMediaCacheKey {
    static func imageKey(for media: MediaContent) -> String {
        "media.image.\(media.id.uuidString)"
    }
}

