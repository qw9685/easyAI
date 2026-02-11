import XCTest
@testable import easyAI

final class BusinessUtilitiesKitTests: XCTestCase {

    func testConversationFlowKitDecideEnsureConversation() {
        let blocked = ConversationFlowKit.decideEnsureConversation(
            isResettingPersistence: true,
            currentConversationId: nil
        )
        switch blocked {
        case .blocked(let errorMessage):
            XCTAssertFalse(errorMessage.isEmpty)
        default:
            XCTFail("Expected blocked decision when resetting persistence")
        }

        let ready = ConversationFlowKit.decideEnsureConversation(
            isResettingPersistence: false,
            currentConversationId: "c-1"
        )
        guard case .ready = ready else {
            return XCTFail("Expected ready decision when conversation exists")
        }

        let createNew = ConversationFlowKit.decideEnsureConversation(
            isResettingPersistence: false,
            currentConversationId: nil
        )
        guard case .createNew = createNew else {
            return XCTFail("Expected createNew decision when no conversation exists")
        }
    }

    func testConversationFlowKitTransitionAndTouchDecision() {
        let snapshotConversationId = UUID()
        let turnId = UUID()
        let snapshot = ChatSessionSnapshot(
            currentConversationId: "conversation-A",
            messages: [Message(content: "hi", role: .user)],
            conversationId: snapshotConversationId,
            currentTurnId: turnId
        )

        let transition = ConversationFlowKit.makeTransition(from: snapshot)
        XCTAssertEqual(transition.currentConversationId, "conversation-A")
        XCTAssertEqual(transition.messages.count, 1)
        XCTAssertEqual(transition.conversationId, snapshotConversationId)
        XCTAssertEqual(transition.currentTurnId, turnId)
        XCTAssertTrue(transition.shouldClearPendingMessageUpdates)
        XCTAssertTrue(transition.shouldClearStopNotices)

        let now = Date()
        let record = ConversationRecord(
            id: "conversation-A",
            title: "A",
            isPinned: false,
            createdAt: now,
            updatedAt: now
        )

        let updated = ConversationFlowKit.decideConversationTouch(.updated([record]))
        switch updated {
        case .update(let records):
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records.first?.id, "conversation-A")
        default:
            XCTFail("Expected update decision for updated result")
        }

        let reload = ConversationFlowKit.decideConversationTouch(.needsReload, fallbackDebounceMs: 200)
        switch reload {
        case .reload(let debounceMs):
            XCTAssertEqual(debounceMs, 200)
        default:
            XCTFail("Expected reload decision for needsReload result")
        }
    }

    func testChatExecutionPolicyKitMakeMetricsUsesUsageWhenProvided() {
        let model = makeModel(promptPrice: "0.000001", completionPrice: "0.000002")
        let usage = ChatTokenUsage(promptTokens: 20, completionTokens: 10, totalTokens: 30)

        let metrics = ChatExecutionPolicyKit.makeMetrics(
            requestMessages: [Message(content: "hello", role: .user)],
            responseText: "world",
            model: model,
            latencyMs: 123,
            usage: usage
        )

        XCTAssertEqual(metrics.promptTokens, 20)
        XCTAssertEqual(metrics.completionTokens, 10)
        XCTAssertEqual(metrics.totalTokens, 30)
        XCTAssertEqual(metrics.latencyMs, 123)
        XCTAssertEqual(metrics.estimatedCostUSD ?? -1, 0.00004, accuracy: 0.0000001)
        XCTAssertFalse(metrics.isEstimated)
    }

    func testChatExecutionPolicyKitMakeMetricsEstimatesWhenNoUsage() {
        let model = makeModel(promptPrice: "0.000001", completionPrice: "0.000002")
        let message = Message(content: "hello", role: .user)

        let metrics = ChatExecutionPolicyKit.makeMetrics(
            requestMessages: [message],
            responseText: "world!",
            model: model,
            latencyMs: 88
        )

        XCTAssertEqual(metrics.promptTokens, 4)
        XCTAssertEqual(metrics.completionTokens, 2)
        XCTAssertEqual(metrics.totalTokens, 6)
        XCTAssertEqual(metrics.latencyMs, 88)
        XCTAssertEqual(metrics.estimatedCostUSD ?? -1, 0.000008, accuracy: 0.0000001)
        XCTAssertTrue(metrics.isEstimated)
    }

    func testChatExecutionPolicyKitTypewriterConfigFollowsSpeedTier() {
        let originalSpeed = AppConfig.typewriterSpeed
        defer { AppConfig.typewriterSpeed = originalSpeed }
        AppConfig.typewriterSpeed = 5.0

        let config = ChatExecutionPolicyKit.makeTypewriterConfig()
        XCTAssertEqual(config.tickInterval, 0.02, accuracy: 0.000001)
        XCTAssertEqual(config.minCharsPerTick, AppConfig.typewriterMinCharsPerTick(for: 5.0))
        XCTAssertEqual(config.maxCharsPerTick, AppConfig.typewriterMaxCharsPerTick(for: 5.0))
    }

    func testConversationMutationKitRenameAndPinnedKeepOrdering() {
        let old = Date(timeIntervalSince1970: 100)
        let mid = Date(timeIntervalSince1970: 200)
        let now = Date(timeIntervalSince1970: 300)

        let records = [
            ConversationRecord(id: "a", title: "A", isPinned: false, createdAt: old, updatedAt: old),
            ConversationRecord(id: "b", title: "B", isPinned: true, createdAt: mid, updatedAt: mid)
        ]

        let renamed = ConversationMutationKit.applyRename(
            id: "a",
            title: "A-New",
            touchedAt: now,
            conversations: records
        )
        XCTAssertEqual(renamed.first?.id, "b")
        XCTAssertEqual(renamed.last?.title, "A-New")
        XCTAssertEqual(renamed.last?.updatedAt, now)

        let pinned = ConversationMutationKit.applyPinned(
            id: "a",
            isPinned: true,
            touchedAt: now,
            conversations: records
        )
        XCTAssertEqual(pinned.first?.id, "a")
        XCTAssertTrue(pinned.first?.isPinned ?? false)
        XCTAssertEqual(pinned.first?.updatedAt, now)
    }

    func testConversationMutationKitRemoveConversation() {
        let now = Date(timeIntervalSince1970: 100)
        let records = [
            ConversationRecord(id: "a", title: "A", isPinned: false, createdAt: now, updatedAt: now),
            ConversationRecord(id: "b", title: "B", isPinned: false, createdAt: now, updatedAt: now)
        ]

        let removed = ConversationMutationKit.removeConversation(id: "a", conversations: records)
        XCTAssertEqual(removed.count, 1)
        XCTAssertEqual(removed.first?.id, "b")
    }

    func testConversationMutationKitApplyTouchWithTitle() {
        let old = Date(timeIntervalSince1970: 100)
        let now = Date(timeIntervalSince1970: 200)
        let records = [
            ConversationRecord(id: "a", title: "Old", isPinned: false, createdAt: old, updatedAt: old),
            ConversationRecord(id: "b", title: "B", isPinned: false, createdAt: old, updatedAt: old.addingTimeInterval(10))
        ]

        let touched = ConversationMutationKit.applyTouch(
            conversationId: "a",
            touchedAt: now,
            title: "New",
            conversations: records
        )
        XCTAssertEqual(touched?.first?.id, "a")
        XCTAssertEqual(touched?.first?.title, "New")
        XCTAssertEqual(touched?.first?.updatedAt, now)
    }

    private func makeModel(promptPrice: String, completionPrice: String) -> AIModel {
        AIModel(
            id: "model-1",
            name: "Model 1",
            description: "test",
            provider: .openrouter,
            apiModel: "openrouter/model-1",
            supportsMultimodal: false,
            pricing: ModelPricing(prompt: promptPrice, completion: completionPrice)
        )
    }
}
