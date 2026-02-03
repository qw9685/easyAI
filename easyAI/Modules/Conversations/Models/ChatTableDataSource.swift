//
//  ChatTableDataSource.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 配置 RxDataSources 数据源与 cell
//
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
                case .messageMarkdown(let message):
                    let cell = tableView.dequeueReusableCell(
                        withIdentifier: ChatMessageMarkdownCell.reuseIdentifier,
                        for: indexPath
                    ) as? ChatMessageMarkdownCell
                    let maxBubbleWidth = max(0, tableView.bounds.width - 32)
                    cell?.configure(with: message, maxBubbleWidth: maxBubbleWidth)
                    return cell ?? UITableViewCell()
                case .messageSend(let message):
                    let cell = tableView.dequeueReusableCell(
                        withIdentifier: ChatMessageSendCell.reuseIdentifier,
                        for: indexPath
                    ) as? ChatMessageSendCell
                    cell?.configure(with: message)
                    return cell ?? UITableViewCell()
                case .messageMedia(let message):
                    let cell = tableView.dequeueReusableCell(
                        withIdentifier: ChatMessageMediaCell.reuseIdentifier,
                        for: indexPath
                    ) as? ChatMessageMediaCell
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
