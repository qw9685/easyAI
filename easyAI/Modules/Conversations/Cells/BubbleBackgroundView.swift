//
//  BubbleBackgroundView.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 气泡背景绘制视图
//
//

import UIKit

final class BubbleBackgroundView: UIView {
    private let gradientLayer = CAGradientLayer()
    
    var isUser: Bool = false {
        didSet { updateAppearance() }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    private func setup() {
        layer.cornerRadius = 12
        layer.masksToBounds = true
        updateAppearance()
    }
    
    private func updateAppearance() {
        if isUser {
            if gradientLayer.superlayer == nil {
                layer.insertSublayer(gradientLayer, at: 0)
            }
            gradientLayer.colors = [
                UIColor.systemBlue.cgColor,
                UIColor.systemPurple.cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
            backgroundColor = .clear
        } else {
            gradientLayer.removeFromSuperlayer()
            backgroundColor = UIColor.systemGray6
        }
    }
}
