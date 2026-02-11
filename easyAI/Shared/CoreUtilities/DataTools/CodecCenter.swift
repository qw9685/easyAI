//
//  CodecCenter.swift
//  easyAI
//
//  通用编解码配置中心
//

import Foundation

extension DataTools {
    enum CodecCenter {
        static var jsonEncoder: JSONEncoder {
            JSONEncoder()
        }

        static var jsonDecoder: JSONDecoder {
            JSONDecoder()
        }
    }
}
