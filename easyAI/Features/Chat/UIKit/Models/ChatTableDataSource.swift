//
//  ChatTableDataSource.swift
//  EasyAI
//
//  创建于 2026
//

import UIKit
import RxDataSources

enum ChatTableDataSourceFactory { 
    static func make() -> RxTableViewSectionedAnimatedDataSource<ChatSection> {
        RxTableViewSectionedAnimatedDataSource<ChatSection>(
            animationConfiguration: AnimationConfiguration(
                insertAnimation: .none,
                reloadAnimation: .none,
                deleteAnimation: .none
            ),
            configureCell: { _, tableView, indexPath, item in
                switch item {
                case .message(let message):
                    let cell = tableView.dequeueReusableCell(
                        withIdentifier: ChatMessageCell.reuseIdentifier,
                        for: indexPath
                    ) as? ChatMessageCell
                    cell?.configure(with: message)
                    return cell ?? UITableViewCell()
                case .loading:
                    let cell = tableView.dequeueReusableCell(
                        withIdentifier: ChatLoadingCell.reuseIdentifier,
                        for: indexPath
                    ) as? ChatLoadingCell
                    cell?.configure()
                    return cell ?? UITableViewCell()
                }
            }
        )
    }
}
