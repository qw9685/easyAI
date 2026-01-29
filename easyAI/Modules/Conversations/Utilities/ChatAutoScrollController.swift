//
//  ChatAutoScrollController.swift
//  EasyAI
//
//  创建于 2026
//

import UIKit

final class ChatAutoScrollController {
    private(set) var pinnedToBottom: Bool = true
    private var lastPinnedContentHeight: CGFloat = 0
    private var needsFlushAfterUserScroll: Bool = false

    func recordPinnedContentHeight(_ height: CGFloat) {
        lastPinnedContentHeight = height
    }

    func onConversationChanged() {
        pinnedToBottom = true
        lastPinnedContentHeight = 0
        needsFlushAfterUserScroll = false
    }

    func onForceScrollRequested() {
        pinnedToBottom = true
    }

    func onUserScroll(isNearBottom: Bool) {
        pinnedToBottom = isNearBottom
    }

    func markNeedsFlushAfterUserScroll() {
        needsFlushAfterUserScroll = true
    }

    func consumeNeedsFlushAfterUserScroll() -> Bool {
        let value = needsFlushAfterUserScroll
        needsFlushAfterUserScroll = false
        return value
    }

    func shouldAutoScrollAfterStateApply(
        userIsInteracting: Bool,
        forceScroll: Bool,
        isNearBottom: Bool
    ) -> Bool {
        if forceScroll {
            pinnedToBottom = true
        } else if !userIsInteracting {
            pinnedToBottom = pinnedToBottom || isNearBottom
        }

        return !userIsInteracting && (forceScroll || pinnedToBottom)
    }

    func shouldAutoScrollForStreaming() -> Bool {
        pinnedToBottom
    }

    func computePinnedDelta(beforeHeight: CGFloat, afterHeight: CGFloat) -> CGFloat {
        afterHeight - max(lastPinnedContentHeight, beforeHeight)
    }
}

