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
                case .messageMarkdown(let message):
                    let cell = tableView.dequeueReusableCell(
                        withIdentifier: ChatMessageMarkdownCell.reuseIdentifier,
                        for: indexPath
                    ) as? ChatMessageMarkdownCell
                    cell?.configure(with: message)
                    return cell ?? UITableViewCell()
                case .messageSend(_, _, _):
                    let cell = tableView.dequeueReusableCell(
                        withIdentifier: ChatMessageSendCell.reuseIdentifier,
                        for: indexPath
                    ) as? ChatMessageSendCell
                    if case .messageSend(_, let text, let timestamp) = item { cell?.configure(text: text, timestamp: timestamp) }
                    return cell ?? UITableViewCell()
                case .messageMedia(let messageId, let role, let mediaContents):
                    let cell = tableView.dequeueReusableCell(
                        withIdentifier: ChatMessageMediaCell.reuseIdentifier,
                        for: indexPath
                    ) as? ChatMessageMediaCell
                    cell?.configure(messageId: messageId, role: role, mediaContents: mediaContents)
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
