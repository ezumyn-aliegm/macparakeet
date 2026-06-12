import XCTest
@testable import MacParakeetCore

final class OllamaEndpointResolverTests: XCTestCase {
    func testPreferredBaseURLUsesExampleHostByDefault() {
        XCTAssertEqual(
            OllamaEndpointResolver.preferredBaseURL(),
            "http://192.168.1.100:11434/v1"
        )
    }

    func testNormalizeBaseURLAddsV1Suffix() {
        XCTAssertEqual(
            OllamaEndpointResolver.normalizeBaseURL("http://192.168.1.100:11434"),
            "http://192.168.1.100:11434/v1"
        )
        XCTAssertEqual(
            OllamaEndpointResolver.normalizeBaseURL("http://192.168.1.100:11434/v1/"),
            "http://192.168.1.100:11434/v1"
        )
    }

    func testOllamaFactoryUsesConfiguredEndpoint() {
        XCTAssertEqual(
            LLMProviderConfig.ollama().baseURL.absoluteString,
            "http://192.168.1.100:11434/v1"
        )
        XCTAssertEqual(LLMProviderConfig.ollama().modelName, "qwen3:8b")
    }
}