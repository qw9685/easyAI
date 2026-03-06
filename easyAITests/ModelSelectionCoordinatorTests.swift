import XCTest
@testable import easyAI

final class ModelSelectionCoordinatorTests: XCTestCase {

    func testValidateSendPrerequisitesRejectsMissingAPIKey() {
        let coordinator = ModelSelectionCoordinator(modelRepository: MockModelRepository())
        let result = coordinator.validateSendPrerequisites(
            apiKey: "   ",
            useMockData: false,
            selectedModel: nil,
            availableModels: [],
            userMessage: Message(content: "hello", role: .user)
        )

        switch result {
        case .ready:
            XCTFail("Expected missing api key error")
        case .error(let message, let reason):
            XCTAssertEqual(reason, .missingAPIKey)
            XCTAssertEqual(message, "请先在设置中填写有效的 OpenRouter API Key")
        }
    }

    func testValidateSendPrerequisitesUsesFirstAvailableModelWhenSelectionMissing() {
        let coordinator = ModelSelectionCoordinator(modelRepository: MockModelRepository())
        let fallbackModel = AIModel(
            id: "openrouter-test",
            name: "Test",
            description: "desc",
            provider: .openrouter,
            apiModel: "openrouter/test"
        )

        let result = coordinator.validateSendPrerequisites(
            apiKey: "sk-or-v1-test",
            useMockData: false,
            selectedModel: nil,
            availableModels: [fallbackModel],
            userMessage: Message(content: "hello", role: .user)
        )

        switch result {
        case .ready(let model):
            XCTAssertEqual(model.id, fallbackModel.id)
        case .error(let message, _):
            XCTFail("Unexpected error: \(message)")
        }
    }

    func testValidateSendPrerequisitesReportsModelUnavailableClearly() {
        let coordinator = ModelSelectionCoordinator(modelRepository: MockModelRepository())
        let result = coordinator.validateSendPrerequisites(
            apiKey: "sk-or-v1-test",
            useMockData: false,
            selectedModel: nil,
            availableModels: [],
            userMessage: Message(content: "hello", role: .user)
        )

        switch result {
        case .ready:
            XCTFail("Expected model unavailable error")
        case .error(let message, let reason):
            XCTAssertEqual(reason, .modelUnavailable)
            XCTAssertEqual(message, "当前没有可用模型，请检查 API Key、网络连接，或在设置中重新加载模型。")
        }
    }
}

private struct MockModelRepository: ModelRepositoryProtocol {
    func fetchModels(filter: ModelFilter, forceRefresh: Bool) async -> [AIModel] {
        []
    }
}
