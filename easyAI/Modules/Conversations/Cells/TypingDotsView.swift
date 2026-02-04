//
//  TypingDotsView.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 输入中点点动画视图
//
//

import UIKit
import SnapKit

final class TypingDotsView: UIView {
    private let stack = UIStackView()
    private let dotViews: [UIView] = (0..<3).map { _ in UIView() }
    private var isAnimating = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        let baseTime = CACurrentMediaTime()
        
        for (index, dot) in dotViews.enumerated() {
            let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
            animation.values = [0, -4, 0]
            animation.keyTimes = [0, 0.5, 1]
            animation.duration = 0.6
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.beginTime = baseTime + Double(index) * 0.12
            dot.layer.add(animation, forKey: "typingBounce")
        }
    }
    
    func stopAnimating() {
        guard isAnimating else { return }
        isAnimating = false
        dotViews.forEach { $0.layer.removeAnimation(forKey: "typingBounce") }
    }
    
    private func setup() {
        stack.axis = .horizontal
        stack.spacing = 4
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        for dot in dotViews {
            dot.backgroundColor = AppTheme.textTertiary.withAlphaComponent(0.8)
            dot.layer.cornerRadius = 4
            dot.snp.makeConstraints { make in
                make.size.equalTo(CGSize(width: 8, height: 8))
            }
            stack.addArrangedSubview(dot)
        }
    }
}
