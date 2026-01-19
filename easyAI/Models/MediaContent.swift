//
//  MediaContent.swift
//  EasyAI
//
//  Created on 2024
//

import Foundation
import UIKit

/// 媒体内容类型
enum MediaType: String, Codable {
    case image
    case video
    case audio
    case pdf
    case document
    
    /// 获取对应的 OpenRouter API content type
    var openRouterContentType: String {
        switch self {
        case .image:
            return "image_url"
        case .video:
            return "video_url"
        case .audio:
            return "audio_url"
        case .pdf, .document:
            return "document_url"
        }
    }
}

/// 媒体内容模型
/// 统一表示图片、视频、音频、PDF等媒体类型
struct MediaContent: Identifiable, Codable {
    let id: UUID
    let type: MediaType
    let data: Data
    let mimeType: String
    let fileName: String?
    
    init(id: UUID = UUID(), type: MediaType, data: Data, mimeType: String, fileName: String? = nil) {
        self.id = id
        self.type = type
        self.data = data
        self.mimeType = mimeType
        self.fileName = fileName
    }
    
    /// 获取 base64 编码的 data URL
    func getDataURL() -> String {
        let base64String = data.base64EncodedString()
        return "data:\(mimeType);base64,\(base64String)"
    }
    
    /// 获取文件大小（字节）
    var fileSize: Int {
        data.count
    }
    
    /// 获取文件大小（人类可读格式）
    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}

// MARK: - Media Content Helpers

extension MediaContent {
    /// 从 UIImage 创建图片媒体内容
    static func image(_ uiImage: UIImage, mimeType: String = "image/jpeg", quality: CGFloat = 0.8) -> MediaContent? {
        guard let imageData = uiImage.jpegData(compressionQuality: quality) ?? uiImage.pngData() else {
            return nil
        }
        
        // 根据实际数据判断 MIME 类型
        let detectedMimeType = detectImageMimeType(imageData) ?? mimeType
        
        return MediaContent(
            type: .image,
            data: imageData,
            mimeType: detectedMimeType
        )
    }
    
    /// 从 Data 创建媒体内容（自动检测类型）
    static func from(data: Data, fileName: String? = nil) -> MediaContent? {
        // 检测 MIME 类型
        if let mimeType = detectMimeType(data: data) {
            let mediaType: MediaType
            
            if mimeType.hasPrefix("image/") {
                mediaType = .image
            } else if mimeType.hasPrefix("video/") {
                mediaType = .video
            } else if mimeType.hasPrefix("audio/") {
                mediaType = .audio
            } else if mimeType == "application/pdf" {
                mediaType = .pdf
            } else {
                mediaType = .document
            }
            
            return MediaContent(
                type: mediaType,
                data: data,
                mimeType: mimeType,
                fileName: fileName
            )
        }
        
        return nil
    }
    
    /// 检测数据的 MIME 类型
    private static func detectMimeType(data: Data) -> String? {
        let header = data.prefix(12)
        
        guard header.count >= 3 else {
            return nil
        }
        
        // 图片类型
        if header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF {
            return "image/jpeg"
        }
        if header.count >= 4 && header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47 {
            return "image/png"
        }
        if header.count >= 3 && header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46 {
            return "image/gif"
        }
        if header.count >= 4 && header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 {
            // 可能是 WebP 或 RIFF 格式，需要进一步检查
            if data.count > 8 && String(data: data[4..<8], encoding: .ascii) == "WEBP" {
                return "image/webp"
            }
        }
        
        // PDF
        if header.count >= 4 && String(data: header.prefix(4), encoding: .ascii) == "%PDF" {
            return "application/pdf"
        }
        
        // 视频类型（MP4）
        if header.count >= 12 {
            let ftyp = String(data: header[4..<8], encoding: .ascii)
            if ftyp == "ftyp" {
                return "video/mp4"
            }
        }
        
        // 音频类型（MP3）
        if header.count >= 3 && header[0] == 0xFF && (header[1] & 0xE0) == 0xE0 {
            return "audio/mpeg"
        }
        
        return nil
    }
    
    /// 检测图片的 MIME 类型
    private static func detectImageMimeType(_ data: Data) -> String? {
        let header = data.prefix(12)
        
        guard header.count >= 3 else {
            return "image/jpeg"
        }
        
        if header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF {
            return "image/jpeg"
        }
        if header.count >= 4 && header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47 {
            return "image/png"
        }
        if header.count >= 3 && header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46 {
            return "image/gif"
        }
        if header.count >= 4 && header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 {
            if data.count > 8 && String(data: data[4..<8], encoding: .ascii) == "WEBP" {
                return "image/webp"
            }
        }
        
        return "image/jpeg" // 默认
    }
}


