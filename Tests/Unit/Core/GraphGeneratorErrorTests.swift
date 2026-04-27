import XCTest
@testable import ModelGraphGenerator

final class GraphGeneratorErrorTests: XCTestCase {
    
    // MARK: - Error Cases Tests
    
    func testIndexStoreNotFoundError() {
        let error = GraphGeneratorError.indexStoreNotFound("Test message")
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Index store not found") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Test message") ?? false)
    }
    
    func testFailedToOpenIndexError() {
        let error = GraphGeneratorError.failedToOpenIndex("Test message")
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Failed to open index") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Test message") ?? false)
    }
    
    func testSourceFileNotFoundError() {
        let error = GraphGeneratorError.sourceFileNotFound("Test message")
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Source file not found") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Test message") ?? false)
    }
    
    func testParsingFailedError() {
        let error = GraphGeneratorError.parsingFailed("Test message")
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Parsing failed") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Test message") ?? false)
    }
    
    // MARK: - LocalizedError Conformance
    
    func testAllErrors_HaveLocalizedDescription() {
        let errors: [GraphGeneratorError] = [
            .indexStoreNotFound("test"),
            .failedToOpenIndex("test"),
            .sourceFileNotFound("test"),
            .parsingFailed("test")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description: \\(error)")
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, "Description should not be empty: \\(error)")
        }
    }
    
    // MARK: - Error Throwing Tests
    
    func testIndexStoreNotFoundError_CanBeThrown() {
        XCTAssertThrowsError(try throwIndexStoreNotFoundError()) { error in
            XCTAssertTrue(error is GraphGeneratorError)
            if case .indexStoreNotFound = error as? GraphGeneratorError {
                XCTAssertTrue(true)
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    func testFailedToOpenIndexError_CanBeThrown() {
        XCTAssertThrowsError(try throwFailedToOpenIndexError()) { error in
            XCTAssertTrue(error is GraphGeneratorError)
            if case .failedToOpenIndex = error as? GraphGeneratorError {
                XCTAssertTrue(true)
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    func testSourceFileNotFoundError_CanBeThrown() {
        XCTAssertThrowsError(try throwSourceFileNotFoundError()) { error in
            XCTAssertTrue(error is GraphGeneratorError)
            if case .sourceFileNotFound = error as? GraphGeneratorError {
                XCTAssertTrue(true)
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    func testParsingFailedError_CanBeThrown() {
        XCTAssertThrowsError(try throwParsingFailedError()) { error in
            XCTAssertTrue(error is GraphGeneratorError)
            if case .parsingFailed = error as? GraphGeneratorError {
                XCTAssertTrue(true)
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func throwIndexStoreNotFoundError() throws {
        throw GraphGeneratorError.indexStoreNotFound("Test error")
    }
    
    private func throwFailedToOpenIndexError() throws {
        throw GraphGeneratorError.failedToOpenIndex("Test error")
    }
    
    private func throwSourceFileNotFoundError() throws {
        throw GraphGeneratorError.sourceFileNotFound("Test error")
    }
    
    private func throwParsingFailedError() throws {
        throw GraphGeneratorError.parsingFailed("Test error")
    }
    
    // MARK: - Edge Cases
    
    func testErrors_WithEmptyMessage() {
        let errors: [GraphGeneratorError] = [
            .indexStoreNotFound(""),
            .failedToOpenIndex(""),
            .sourceFileNotFound(""),
            .parsingFailed("")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
        }
    }
    
    func testErrors_WithLongMessage() {
        let longMessage = String(repeating: "a", count: 10000)
        
        let errors: [GraphGeneratorError] = [
            .indexStoreNotFound(longMessage),
            .failedToOpenIndex(longMessage),
            .sourceFileNotFound(longMessage),
            .parsingFailed(longMessage)
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertTrue(error.errorDescription?.contains(longMessage) ?? false)
        }
    }
    
    func testErrors_WithSpecialCharacters() {
        let specialMessage = "Error with\\nnewline and\\ttab and emoji 🚀"
        
        let error = GraphGeneratorError.parsingFailed(specialMessage)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains(specialMessage) ?? false)
    }
}
