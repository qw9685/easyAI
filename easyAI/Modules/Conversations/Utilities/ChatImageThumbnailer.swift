//
//  ChatImageThumbnailer.swift
//  EasyAI
//
//  创建于 2026
//

import Foundation
import UIKit
import ImageIO
import CryptoKit

enum ChatImageThumbnailer {
    private static let cache = NSCache<NSString, UIImage>()

    static func cachedThumbnail(for data: Data, maxPixelSize: Int) -> UIImage? {
        cache.object(forKey: cacheKey(for: data, maxPixelSize: maxPixelSize))
    }

    static func setCachedThumbnail(_ image: UIImage, for data: Data, maxPixelSize: Int) {
        cache.setObject(image, forKey: cacheKey(for: data, maxPixelSize: maxPixelSize))
    }

    static func makeThumbnail(from data: Data, maxPixelSize: Int) -> UIImage? {
        let cfData = data as CFData
        guard let source = CGImageSourceCreateWithData(cfData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func cacheKey(for data: Data, maxPixelSize: Int) -> NSString {
        let digest = SHA256.hash(data: data)
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return NSString(string: "\(maxPixelSize)|\(hex)")
    }
}

