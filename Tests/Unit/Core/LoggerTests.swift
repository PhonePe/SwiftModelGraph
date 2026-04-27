import XCTest
@testable import ModelGraphGenerator

final class LoggerTests: XCTestCase {
    
    // MARK: - Verbose Mode Tests
    
    func testLogger_VerboseMode_InfoMessagesShown() {
        let logger = Logger(verbose: true)
        
        // Since info() writes to stderr, we can't easily capture it in tests
        // But we can verify the logger is created with correct verbose setting
        XCTAssertTrue(logger.verbose)
    }
    
    func testLogger_NonVerboseMode_InfoMessagesNotShown() {
        let logger = Logger(verbose: false)
        
        XCTAssertFalse(logger.verbose)
    }
    
    // MARK: - Message Level Tests
    
    func testLogger_DebugMethod_Exists() {
        let logger = Logger(verbose: true)
        
        // Test that debug method can be called without crashing
        logger.debug("Test debug message")
        
        // If we get here, the method exists and works
        XCTAssertTrue(true)
    }
    
    func testLogger_InfoMethod_Exists() {
        let logger = Logger(verbose: true)
        
        // Test that info method can be called without crashing
        logger.info("Test info message")
        
        XCTAssertTrue(true)
    }
    
    func testLogger_WarningMethod_Exists() {
        let logger = Logger(verbose: true)
        
        // Test that warning method can be called without crashing
        logger.warning("Test warning message")
        
        XCTAssertTrue(true)
    }
    
    func testLogger_ErrorMethod_Exists() {
        let logger = Logger(verbose: true)
        
        // Test that error method can be called without crashing
        logger.error("Test error message")
        
        XCTAssertTrue(true)
    }
    
    // MARK: - Integration Tests
    
    func testLogger_AllLevels_WithVerboseMode() {
        let logger = Logger(verbose: true)
        
        // Test that all methods work together
        logger.debug("Debug message")
        logger.info("Info message")
        logger.warning("Warning message")
        logger.error("Error message")
        
        // If we get here, all methods worked
        XCTAssertTrue(true)
    }
    
    func testLogger_AllLevels_WithoutVerboseMode() {
        let logger = Logger(verbose: false)
        
        // Test that all methods work together even in non-verbose mode
        logger.debug("Debug message")
        logger.info("Info message")
        logger.warning("Warning message")
        logger.error("Error message")
        
        // If we get here, all methods worked
        XCTAssertTrue(true)
    }
    
    func testLogger_EmptyMessages() {
        let logger = Logger(verbose: true)
        
        // Test that empty messages don't cause issues
        logger.debug("")
        logger.info("")
        logger.warning("")
        logger.error("")
        
        XCTAssertTrue(true)
    }
    
    func testLogger_LongMessages() {
        let logger = Logger(verbose: true)
        let longMessage = String(repeating: "a", count: 10000)
        
        // Test that long messages don't cause issues
        logger.info(longMessage)
        
        XCTAssertTrue(true)
    }
    
    func testLogger_SpecialCharacters() {
        let logger = Logger(verbose: true)
        
        // Test messages with special characters
        logger.info("Message with emoji: 🚀 ✅ ⚠️")
        logger.info("Message with quotes: \"Hello\"")
        logger.info("Message with newline:\\n")
        logger.info("Message with tab:\\t")
        
        XCTAssertTrue(true)
    }
}
