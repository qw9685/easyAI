//
//  ChatEmptyStateView.swift
//  EasyAI
//
//  创建于 2026
//

import UIKit
import SnapKit

final class ChatEmptyStateView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        let icon = UIImageView(image: UIImage(systemName: "sparkles"))
        icon.tintColor = UIColor.systemBlue
        icon.contentMode = .scaleAspectFit
        icon.snp.makeConstraints { make in
            make.height.equalTo(60)
        }
        
        let title = UILabel()
        title.text = "开始与AI对话"
        title.font = UIFont.preferredFont(forTextStyle: .title2)
        title.textColor = .label
        
        let subtitle = UILabel()
        subtitle.text = "选择模型后，输入消息开始聊天"
        subtitle.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0
        subtitle.textAlignment = .center
        
        let stack = UIStackView(arrangedSubviews: [icon, title, subtitle])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().inset(24)
        }
    }
}
