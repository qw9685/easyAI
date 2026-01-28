//
//  ChatLoadingCell.swift
//  EasyAI
//
//  创建于 2026
//

import UIKit
import SnapKit

final class ChatLoadingCell: UITableViewCell {
    static let reuseIdentifier = "ChatLoadingCell"
    
    private let bubbleView = BubbleBackgroundView()
    private let typingDotsView = TypingDotsView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        typingDotsView.stopAnimating()
    }
    
    func configure() {
        bubbleView.isUser = false
        typingDotsView.startAnimating()
    }
    
    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(typingDotsView)
        bubbleView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().inset(16)
            make.top.equalToSuperview().offset(8)
            make.bottom.equalToSuperview().inset(8)
        }
        typingDotsView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(12)
            make.bottom.equalToSuperview().inset(8)
        }
    }
}
