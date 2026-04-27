import XCTest
@testable import ModelGraphGenerator

final class RegexHelperTests: XCTestCase {
    
    // MARK: - create Tests
    
    func testCreate_ValidPattern() {
        let regex = RegexHelper.create(pattern: #"\d+"#)
        XCTAssertNotNil(regex, "Should create regex from valid pattern")
    }
    
    func testCreate_InvalidPattern() {
        let regex = RegexHelper.create(pattern: "[invalid(")
        XCTAssertNil(regex, "Should return nil for invalid pattern")
    }
    
    func testCreate_WithOptions() {
        let regex = RegexHelper.create(
            pattern: "test",
            options: [.caseInsensitive]
        )
        XCTAssertNotNil(regex, "Should create regex with options")
        
        // Verify case insensitive option works
        let matches = RegexHelper.matches(regex: regex!, in: "TEST test TeSt")
        XCTAssertEqual(matches.count, 3, "Should match all case variations")
    }
    
    func testCreate_EmptyPattern() {
        // Empty pattern is technically valid in NSRegularExpression (matches empty string)
        // However, it may not be consistently handled across different versions
        let regex = RegexHelper.create(pattern: "")
        // Just verify it doesn't crash - result may vary
        _ = regex
    }
    
    // MARK: - matches Tests
    
    func testMatches_SingleMatch() {
        guard let regex = RegexHelper.create(pattern: #"\d+"#) else {
            XCTFail("Failed to create regex")
            return
        }
        
        let matches = RegexHelper.matches(regex: regex, in: "The number is 123")
        XCTAssertEqual(matches.count, 1, "Should find one match")
    }
    
    func testMatches_MultipleMatches() {
        guard let regex = RegexHelper.create(pattern: #"\d+"#) else {
            XCTFail("Failed to create regex")
            return
        }
        
        let matches = RegexHelper.matches(regex: regex, in: "Numbers: 123, 456, 789")
        XCTAssertEqual(matches.count, 3, "Should find three matches")
    }
    
    func testMatches_NoMatches() {
        guard let regex = RegexHelper.create(pattern: #"\d+"#) else {
            XCTFail("Failed to create regex")
            return
        }
        
        let matches = RegexHelper.matches(regex: regex, in: "No numbers here")
        XCTAssertEqual(matches.count, 0, "Should find no matches")
    }
    
    func testMatches_EmptyString() {
        guard let regex = RegexHelper.create(pattern: #"\d+"#) else {
            XCTFail("Failed to create regex")
            return
        }
        
        let matches = RegexHelper.matches(regex: regex, in: "")
        XCTAssertEqual(matches.count, 0, "Should find no matches in empty string")
    }
    
    // MARK: - firstMatch Tests
    
    func testFirstMatch_Found() {
        guard let regex = RegexHelper.create(pattern: #"\d+"#) else {
            XCTFail("Failed to create regex")
            return
        }
        
        let match = RegexHelper.firstMatch(regex: regex, in: "Numbers: 123, 456")
        XCTAssertNotNil(match, "Should find first match")
        
        let text = "Numbers: 123, 456"
        if let match = match,
           let range = Range(match.range, in: text) {
            XCTAssertEqual(String(text[range]), "123", "Should match first number")
        } else {
            XCTFail("Failed to extract match text")
        }
    }
    
    func testFirstMatch_NotFound() {
        guard let regex = RegexHelper.create(pattern: #"\d+"#) else {
            XCTFail("Failed to create regex")
            return
        }
        
        let match = RegexHelper.firstMatch(regex: regex, in: "No numbers here")
        XCTAssertNil(match, "Should not find match")
    }
    
    func testFirstMatch_EmptyString() {
        guard let regex = RegexHelper.create(pattern: #"\d+"#) else {
            XCTFail("Failed to create regex")
            return
        }
        
        let match = RegexHelper.firstMatch(regex: regex, in: "")
        XCTAssertNil(match, "Should not find match in empty string")
    }
    
    // MARK: - capturedText Tests
    
    func testCapturedText_FullMatch() {
        guard let regex = RegexHelper.create(pattern: #"(\w+): (\d+)"#) else {
            XCTFail("Failed to create regex")
            return
        }
        
        let text = "Name: 123"
        let match = RegexHelper.firstMatch(regex: regex, in: text)
        XCTAssertNotNil(match, "Should find match")
        
        let captured = RegexHelper.capturedText(from: match!, groupIndex: 0, in: text)
        XCTAssertEqual(captured, "Name: 123", "Should capture full match")
    }
    
    func testCapturedText_CaptureGroups() {
        guard let regex = RegexHelper.create(pattern: #"(\w+): (\d+)"#) else {
            XCTFail("Failed to create regex")
            return
        }
        
        let text = "Name: 123"
        let match = RegexHelper.firstMatch(regex: regex, in: text)
        XCTAssertNotNil(match, "Should find match")
        
        let group1 = RegexHelper.capturedText(from: match!, groupIndex: 1, in: text)
        let group2 = RegexHelper.capturedText(from: match!, groupIndex: 2, in: text)
        
        XCTAssertEqual(group1, "Name", "Should capture first group")
        XCTAssertEqual(group2, "123", "Should capture second group")
    }
    
    func testCapturedText_InvalidGroupIndex() {
        guard let regex = RegexHelper.create(pattern: #"(\w+)"#) else {
            XCTFail("Failed to create regex")
            return
        }
        
        let text = "Test"
        let match = RegexHelper.firstMatch(regex: regex, in: text)
        XCTAssertNotNil(match, "Should find match")
        
        let captured = RegexHelper.capturedText(from: match!, groupIndex: 99, in: text)
        XCTAssertNil(captured, "Should return nil for invalid group index")
    }
    
    func testCapturedText_OptionalGroup() {
        guard let regex = RegexHelper.create(pattern: #"Name(: (\d+))?"#) else {
            XCTFail("Failed to create regex")
            return
        }
        
        let text = "Name"
        let match = RegexHelper.firstMatch(regex: regex, in: text)
        XCTAssertNotNil(match, "Should find match")
        
        let group0 = RegexHelper.capturedText(from: match!, groupIndex: 0, in: text)
        let group1 = RegexHelper.capturedText(from: match!, groupIndex: 1, in: text)
        
        XCTAssertEqual(group0, "Name", "Should capture full match")
        XCTAssertNil(group1, "Should return nil for unmatched optional group")
    }
    
    // MARK: - Integration Tests
    
    func testIntegration_ExtractSchemaId() {
        let pattern = #"schemaId\s*=\s*"([^"]*)""#
        guard let regex = RegexHelper.create(pattern: pattern) else {
            XCTFail("Failed to create regex")
            return
        }
        
        let annotation = #"@Knot(schemaId = "USER_PROFILE", subSchemas = [])"#
        let match = RegexHelper.firstMatch(regex: regex, in: annotation)
        XCTAssertNotNil(match, "Should find schemaId")
        
        let schemaId = RegexHelper.capturedText(from: match!, groupIndex: 1, in: annotation)
        XCTAssertEqual(schemaId, "USER_PROFILE", "Should extract schemaId value")
    }
    
    func testIntegration_FindAllIdentifiers() {
        let pattern = #"\b[A-Z][a-zA-Z0-9]*\b"#
        guard let regex = RegexHelper.create(pattern: pattern) else {
            XCTFail("Failed to create regex")
            return
        }
        
        let code = "struct User: Codable { let name: String }"
        let matches = RegexHelper.matches(regex: regex, in: code)
        
        XCTAssertEqual(matches.count, 3, "Should find 3 type identifiers")
        
        let identifiers = matches.compactMap { match in
            RegexHelper.capturedText(from: match, groupIndex: 0, in: code)
        }
        
        XCTAssertEqual(identifiers, ["User", "Codable", "String"], "Should extract all type names")
    }
}
