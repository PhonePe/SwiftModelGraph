import XCTest
import SwiftSyntax
import SwiftParser
@testable import ModelGraphGenerator

/// Tests for MacroDiscoveryVisitor using SwiftSyntax
/// Verifies that macro detection handles all Swift syntax edge cases
final class MacroDiscoveryVisitorTests: XCTestCase {
    
    // MARK: - Basic Detection Tests
    
    func testDetectsMacroOnStruct() {
        let code = """
        @ChimeraSchema(key: "user")
        struct User {
            let id: String
        }
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages.count, 1, "Should find exactly one macro")
        XCTAssertEqual(usages[0].parameters["key"] as? String, "user")
    }
    
    func testDetectsMacroOnClass() {
        let code = """
        @ChimeraSchema(key: "product")
        class Product {
            var name: String = ""
        }
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages.count, 1)
        XCTAssertEqual(usages[0].parameters["key"] as? String, "product")
    }
    
    func testDetectsMacroOnEnum() {
        let code = """
        @ChimeraSchema(key: "status")
        enum Status {
            case active
            case inactive
        }
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages.count, 1)
        XCTAssertEqual(usages[0].parameters["key"] as? String, "status")
    }
    
    func testDetectsMacroOnActor() {
        let code = """
        @ChimeraSchema(key: "worker")
        actor Worker {
            var tasks: [String] = []
        }
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages.count, 1)
        XCTAssertEqual(usages[0].parameters["key"] as? String, "worker")
    }
    
    // MARK: - Edge Case Tests (The Key Improvements!)
    
    func testIgnoresMacroInStringLiteral() {
        let code = """
        struct User {
            let description = "This @ChimeraSchema is in a string"
        }
        
        @ChimeraSchema(key: "order")
        struct Order {}
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages.count, 1, "Should only find actual attribute, not string content")
        XCTAssertEqual(usages[0].parameters["key"] as? String, "order")
    }
    
    func testIgnoresMacroInSingleLineComment() {
        let code = """
        // @ChimeraSchema(key: "commented")
        // struct Commented {}
        
        @ChimeraSchema(key: "actual")
        struct Actual {}
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages.count, 1, "Should ignore commented macro")
        XCTAssertEqual(usages[0].parameters["key"] as? String, "actual")
    }
    
    func testIgnoresMacroInMultiLineComment() {
        let code = """
        /*
         @ChimeraSchema(key: "commented")
         struct Commented {}
         */
        
        @ChimeraSchema(key: "actual")
        struct Actual {}
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages.count, 1, "Should ignore multi-line commented macro")
        XCTAssertEqual(usages[0].parameters["key"] as? String, "actual")
    }
    
    func testHandlesMultiLineMacroAttributes() {
        let code = """
        @ChimeraSchema(
            key: "product",
            subSchema: ["variant", "price"]
        )
        struct Product {
            let id: String
        }
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages.count, 1, "Should detect multi-line attribute")
        XCTAssertEqual(usages[0].parameters["key"] as? String, "product")
        
        let subSchemas = usages[0].parameters["subSchema"] as? [Any]
        XCTAssertNotNil(subSchemas, "Should extract array parameter")
        XCTAssertEqual(subSchemas?.count, 2)
    }
    
    func testHandlesNestedParenthesesInParameters() {
        let code = """
        @ChimeraSchema(key: getData(from: "config"))
        struct Config {}
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages.count, 1, "Should handle nested parentheses")
        // The parameter value will be the expression as a string
        XCTAssertNotNil(usages[0].parameters["key"])
    }
    
    // MARK: - Parameter Extraction Tests
    
    func testExtractsStringParameter() {
        let code = """
        @ChimeraSchema(key: "userId")
        struct User {}
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages[0].parameters["key"] as? String, "userId")
    }
    
    func testExtractsIntegerParameter() {
        let code = """
        @ChimeraSchema(version: 42)
        struct User {}
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages[0].parameters["version"] as? Int, 42)
    }
    
    func testExtractsBooleanParameter() {
        let code = """
        @ChimeraSchema(required: true)
        struct User {}
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages[0].parameters["required"] as? Bool, true)
    }
    
    func testExtractsArrayParameter() {
        let code = """
        @ChimeraSchema(subSchema: ["address", "profile"])
        struct User {}
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        let subSchemas = usages[0].parameters["subSchema"] as? [Any]
        XCTAssertNotNil(subSchemas)
        XCTAssertEqual(subSchemas?.count, 2)
    }
    
    func testExtractsMultipleParameters() {
        let code = """
        @ChimeraSchema(key: "user", version: 2, required: true, subSchema: ["profile"])
        struct User {}
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages[0].parameters["key"] as? String, "user")
        XCTAssertEqual(usages[0].parameters["version"] as? Int, 2)
        XCTAssertEqual(usages[0].parameters["required"] as? Bool, true)
        XCTAssertNotNil(usages[0].parameters["subSchema"] as? [Any])
    }
    
    func testHandlesMacroWithoutParameters() {
        let code = """
        @ChimeraSchema
        struct User {}
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages.count, 1, "Should detect macro without parameters")
        XCTAssertTrue(usages[0].parameters.isEmpty, "Should have empty parameters")
    }
    
    // MARK: - Multiple Macros Tests
    
    func testDetectsMultipleMacrosInSameFile() {
        let code = """
        @ChimeraSchema(key: "user")
        struct User {}
        
        @ChimeraSchema(key: "order")
        struct Order {}
        
        @ChimeraSchema(key: "product")
        struct Product {}
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages.count, 3, "Should find all three macros")
        XCTAssertEqual(usages[0].parameters["key"] as? String, "user")
        XCTAssertEqual(usages[1].parameters["key"] as? String, "order")
        XCTAssertEqual(usages[2].parameters["key"] as? String, "product")
    }
    
    func testIgnoresDifferentMacroName() {
        let code = """
        @OtherMacro(key: "should-ignore")
        struct Ignored {}
        
        @ChimeraSchema(key: "actual")
        struct Actual {}
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages.count, 1, "Should only find ChimeraSchema")
        XCTAssertEqual(usages[0].parameters["key"] as? String, "actual")
    }
    
    // MARK: - Knot Macros Tests
    
    func testDetectsMultiKnotMacro() {
        let code = """
        @ChimeraMultiKnot(keyPath: "items")
        struct Items {}
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraMultiKnot")
        
        XCTAssertEqual(usages.count, 1)
        XCTAssertEqual(usages[0].parameters["keyPath"] as? String, "items")
    }
    
    func testDetectsMapKnotMacro() {
        let code = """
        @ChimeraMapKnot(keyPath: "mapping")
        struct Mapping {}
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraMapKnot")
        
        XCTAssertEqual(usages.count, 1)
        XCTAssertEqual(usages[0].parameters["keyPath"] as? String, "mapping")
    }
    
    // MARK: - Real-World Scenarios
    
    func testComplexRealWorldScenario() {
        let code = """
        import Foundation
        
        // User model with schema
        @ChimeraSchema(
            key: "user",
            version: 2,
            subSchema: ["profile", "settings"]
        )
        struct User: Codable {
            let id: String
            let name: String
            let profile: Profile
            let settings: Settings
            
            // This string mentions @ChimeraSchema but should be ignored
            let description = "Uses @ChimeraSchema macro"
        }
        
        @ChimeraSchema(key: "profile")
        struct Profile: Codable {
            let bio: String
        }
        
        /* Commented out old version
        @ChimeraSchema(key: "oldSettings")
        struct OldSettings {}
        */
        
        @ChimeraSchema(key: "settings")
        struct Settings: Codable {
            let theme: String
        }
        """
        
        let usages = findMacros(in: code, macroName: "ChimeraSchema")
        
        XCTAssertEqual(usages.count, 3, "Should find exactly 3 macros (ignoring string and comment)")
        
        // Verify first macro (User)
        XCTAssertEqual(usages[0].parameters["key"] as? String, "user")
        XCTAssertEqual(usages[0].parameters["version"] as? Int, 2)
        XCTAssertNotNil(usages[0].parameters["subSchema"])
        
        // Verify second macro (Profile)
        XCTAssertEqual(usages[1].parameters["key"] as? String, "profile")
        
        // Verify third macro (Settings)
        XCTAssertEqual(usages[2].parameters["key"] as? String, "settings")
    }
    
    // MARK: - Helper Methods
    
    /// Helper to parse code and find macros
    private func findMacros(in code: String, macroName: String) -> [MacroUsage] {
        let sourceFile = Parser.parse(source: code)
        let visitor = MacroDiscoveryVisitor(targetMacro: macroName, filePath: "/test.swift")
        visitor.walk(sourceFile)
        return visitor.discoveries
    }
}
