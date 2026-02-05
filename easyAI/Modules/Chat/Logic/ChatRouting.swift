//
//  ChatRouting.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - Chat 模块的 UIKit 路由协议
//

import UIKit

protocol ChatRouting: AnyObject {
    func showSettings(from presenter: UIViewController)
    func showConversations(from presenter: UIViewController)
}
