import XCTest
@testable import easyAI

final class ChatTurnRunnerTests: XCTestCase {

    func testRunStreamThrowsInvalidResponseWhenNoContentReturned() async {
        let runner = ChatTurnRunner(chatService: EmptyStreamChatService())

        do {
            _ = try await runner.runStream(messages: [], model: "test") { _ in }
            XCTFail("Expected invalid response")
        } catch let error as OpenRouterError {
            guard case .invalidResponse = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private struct EmptyStreamChatService: ChatServiceProtocol {
    func sendMessage(messages: [Message], model: String, fallbackModelIDs: [String]) async throws -> ChatServiceResponse {
        ChatServiceResponse(content: "", usage: nil)
    }

    func sendMessageStream(messages: [Message], model: String, fallbackModelIDs: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func fetchModels() async throws -> [OpenRouterModelInfo] {
        []
    }
}
