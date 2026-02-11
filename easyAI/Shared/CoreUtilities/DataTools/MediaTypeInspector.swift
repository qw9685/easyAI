//
//  MediaTypeInspector.swift
//  easyAI
//
//  通用媒体类型检测工具
//

import Foundation

extension DataTools {
    enum MediaTypeInspector {
        static func detectImageMimeType(_ data: Data) -> String {
            let header = data.prefix(12)

            guard header.count >= 3 else {
                return "image/jpeg"
            }

            if header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF {
                return "image/jpeg"
            }

            guard header.count >= 4 else {
                return "image/jpeg"
            }

            if header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47 {
                return "image/png"
            }

            if header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46 {
                return "image/gif"
            }

            if header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 {
                if header.count >= 12,
                   let webpMark = String(data: header[8..<12], encoding: .ascii)?.uppercased(),
                   webpMark == "WEBP" {
                    return "image/webp"
                }
                return "image/jpeg"
            }

            if isHEICHeader(header) {
                return "image/heic"
            }

            return "image/jpeg"
        }

        static func isHEICHeader(_ header: Data) -> Bool {
            guard header.count >= 12,
                  header[4] == 0x66,
                  header[5] == 0x74,
                  header[6] == 0x79,
                  header[7] == 0x70,
                  let brand = String(data: header[8..<12], encoding: .ascii)?.lowercased()
            else {
                return false
            }
            return ["heic", "heix", "hevc", "hevx", "mif1", "msf1"].contains(brand)
        }
    }
}
