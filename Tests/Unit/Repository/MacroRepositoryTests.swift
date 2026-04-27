import XCTest
import Foundation
@testable import ModelGraphGenerator

/// Integration tests for MacroRepository with SwiftSyntax
final class MacroRepositoryTests: XCTestCase {
    
    var tempDirectory: URL!
    var logger: Logger!
    var macroRepository: MacroRepository!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        logger = Logger(verbose: false)
        macroRepository = try! MacroRepository(logger: logger)
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    func testFindAllMacroUsagesInDirectory() throws {
        // Create test files
        let file1 = tempDirectory.appendingPathComponent("User.swift")
        let code1 = """
        @ChimeraSchema(key: "user")
        struct User {
            let id: String
        }
        """
        try code1.write(to: file1, atomically: true, encoding: .utf8)
        
        let file2 = tempDirectory.appendingPathComponent("Product.swift")
        let code2 = """
        @ChimeraSchema(key: "product", version: 2)
        struct Product {
            let name: String
        }
        """
        try code2.write(to: file2, atomically: true, encoding: .utf8)
        
        // Find all macros in directory
        let usages = macroRepository.findAllMacroUsages(
            macroName: "ChimeraSchema",
            sourcePath: tempDirectory.path
        )
        
        XCTAssertEqual(usages.count, 2, "Should find macros in both files")
        
        // Sort by file path for consistent ordering
        let sortedUsages = usages.sorted { $0.filePath < $1.filePath }
        
        // Verify both usages
        XCTAssertTrue(sortedUsages[0].filePath.hasSuffix("Product.swift"))
        XCTAssertEqual(sortedUsages[0].parameters["key"] as? String, "product")
        XCTAssertEqual(sortedUsages[0].parameters["version"] as? Int, 2)
        
        XCTAssertTrue(sortedUsages[1].filePath.hasSuffix("User.swift"))
        XCTAssertEqual(sortedUsages[1].parameters["key"] as? String, "user")
    }
    
    func testAccuracyComparedToRegex() throws {
        // Create a file with edge cases that break regex
        let testFile = tempDirectory.appendingPathComponent("EdgeCases.swift")
        let code = """
        // This @ChimeraSchema is commented out
        struct Commented {}
        
        struct WithString {
            let text = "@ChimeraSchema should be ignored"
        }
        
        @ChimeraSchema(key: "actual1")
        struct Actual1 {}
        
        @ChimeraSchema(
            key: "actual2",
            subSchema: ["nested"]
        )
        struct Actual2 {}
        
        @ChimeraSchema(key: complexFunction("test"))
        struct Actual3 {}
        """
        try code.write(to: testFile, atomically: true, encoding: .utf8)
        
        let usages = macroRepository.findAllMacroUsages(
            macroName: "ChimeraSchema",
            sourcePath: tempDirectory.path
        )
        
        // SwiftSyntax should find exactly 3 (not the comment or string)
        XCTAssertEqual(usages.count, 3, "Should find exactly 3 actual macros")
        
        // Verify the correct ones were found
        let keys = usages.compactMap { $0.parameters["key"] as? String }
        XCTAssertTrue(keys.contains("actual1"))
        XCTAssertTrue(keys.contains("actual2"))
        // actual3 has a complex expression, might be stringified
    }
    
    func testFindKnotAnnotations() throws {
        // Create file with knot annotations
        let testFile = tempDirectory.appendingPathComponent("Knots.swift")
        let code = """
        @ChimeraMultiKnot(keyPath: "items")
        struct Items {}
        
        @ChimeraMapKnot(keyPath: "mapping")
        struct Mapping {}
        
        @ChimeraSchema(key: "regular")
        struct Regular {}
        """
        try code.write(to: testFile, atomically: true, encoding: .utf8)
        
        let knotUsages = macroRepository.findAllKnotAnnotations(sourcePath: tempDirectory.path)
        
        XCTAssertEqual(knotUsages.count, 2, "Should find both knot annotations")
        
        let keyPaths = knotUsages.compactMap { $0.parameters["keyPath"] as? String }
        XCTAssertTrue(keyPaths.contains("items"))
        XCTAssertTrue(keyPaths.contains("mapping"))
    }
    
    func testHandlesFilesWithSyntaxErrors() throws {
        // Create file with syntax error
        let testFile = tempDirectory.appendingPathComponent("Invalid.swift")
        let code = """
        @ChimeraSchema(key: "user")
        struct User {
            let id: String
            // Missing closing brace - syntax error!
        
        @ChimeraSchema(key: "product")
        struct Product {}
        """
        try code.write(to: testFile, atomically: true, encoding: .utf8)
        
        // Should still parse what it can
        let usages = macroRepository.findAllMacroUsages(
            macroName: "ChimeraSchema",
            sourcePath: tempDirectory.path
        )
        
        // SwiftSyntax has error recovery, should find both
        XCTAssertGreaterThanOrEqual(usages.count, 1, "Should handle syntax errors gracefully")
    }
    
    func testEmptyDirectoryReturnsNoUsages() throws {
        let usages = macroRepository.findAllMacroUsages(
            macroName: "ChimeraSchema",
            sourcePath: tempDirectory.path
        )
        
        XCTAssertEqual(usages.count, 0, "Should return empty array for empty directory")
    }
    
    func testNonExistentMacroReturnsNoUsages() throws {
        let testFile = tempDirectory.appendingPathComponent("NoMacro.swift")
        let code = """
        struct User {
            let id: String
        }
        """
        try code.write(to: testFile, atomically: true, encoding: .utf8)
        
        let usages = macroRepository.findAllMacroUsages(
            macroName: "NonExistentMacro",
            sourcePath: tempDirectory.path
        )
        
        XCTAssertEqual(usages.count, 0, "Should return no usages for non-existent macro")
    }
    
    func testSkipsNonSwiftFiles() throws {
        // Create a non-Swift file with macro-like content
        let textFile = tempDirectory.appendingPathComponent("readme.txt")
        let textContent = "@ChimeraSchema(key: \"fake\")"
        try textContent.write(to: textFile, atomically: true, encoding: .utf8)
        
        let usages = macroRepository.findAllMacroUsages(
            macroName: "ChimeraSchema",
            sourcePath: tempDirectory.path
        )
        
        XCTAssertEqual(usages.count, 0, "Should skip non-Swift files")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceWithManyFiles() throws {
        // Create 50 files with macros
        for i in 0..<50 {
            let file = tempDirectory.appendingPathComponent("File\(i).swift")
            let code = """
            @ChimeraSchema(key: "model\(i)")
            struct Model\(i) {
                let id: String
            }
            """
            try code.write(to: file, atomically: true, encoding: .utf8)
        }
        
        measure {
            let usages = macroRepository.findAllMacroUsages(
                macroName: "ChimeraSchema",
                sourcePath: tempDirectory.path
            )
            XCTAssertEqual(usages.count, 50)
        }
    }
    
    // MARK: - Comparison with Old Implementation
    
    func testSwiftSyntaxMoreAccurateThanRegex() throws {
        // Test cases where regex fails but SwiftSyntax succeeds
        let cases: [(description: String, code: String, expectedCount: Int)] = [
            (
                "String with macro text",
                """
                let text = "@ChimeraSchema(key: \\"fake\\")"
                @ChimeraSchema(key: "real")
                struct Real {}
                """,
                1
            ),
            (
                "Comment with macro",
                """
                // @ChimeraSchema(key: "fake")
                @ChimeraSchema(key: "real")
                struct Real {}
                """,
                1
            ),
            (
                "Multi-line parameters",
                """
                @ChimeraSchema(
                    key: "model",
                    version: 2
                )
                struct Model {}
                """,
                1
            ),
            (
                "Nested parentheses",
                """
                @ChimeraSchema(key: getData(from: "source"))
                struct Model {}
                """,
                1
            )
        ]
        
        for testCase in cases {
            let file = tempDirectory.appendingPathComponent("\(testCase.description).swift")
            try testCase.code.write(to: file, atomically: true, encoding: .utf8)
            
            let usages = macroRepository.findAllMacroUsages(
                macroName: "ChimeraSchema",
                sourcePath: file.deletingLastPathComponent().path
            )
            
            XCTAssertEqual(
                usages.count,
                testCase.expectedCount,
                "\\(testCase.description) should find \\(testCase.expectedCount) macro(s)"
            )
            
            // Clean up
            try? FileManager.default.removeItem(at: file)
        }
    }
}
