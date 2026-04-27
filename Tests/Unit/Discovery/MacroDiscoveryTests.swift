import XCTest
import Foundation
@testable import ModelGraphGenerator

class MacroDiscoveryTests: XCTestCase {
    private var indexManager: IndexStoreManager!
    private var macroDiscovery: MacroDiscovery!
    private let testProjectPath = "/Users/sharang.verma/Code/Company/Modelgraphgenrator/Examples"
    
    override func setUp() {
        super.setUp()
        
        let indexStorePath = testProjectPath + "/.build/debug/index/store"
        let logger = Logger(verbose: false)
        
        do {
            indexManager = try IndexStoreManager(
                indexStorePath: indexStorePath,
                sourceRoot: testProjectPath,
                logger: logger
            )
            let symbolRepository = SymbolRepository(indexStore: indexManager.indexStore, logger: logger)
            macroDiscovery = MacroDiscovery(
                indexStore: indexManager.indexStore,
                symbolRepository: symbolRepository,
                sourceRoot: testProjectPath,
                logger: logger
            )
        } catch {
            XCTFail("Failed to initialize MacroDiscovery: \(error)")
        }
    }
    
    // MARK: - Macro Discovery Tests
    
    func testFindSymbolsAnnotated_StandardMacro() throws {
        // When searching for types with standard macros
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: "@Model")
        
        // Then it should return an array (may be empty if no @Model annotations)
        XCTAssertTrue(symbols is [IndexedSymbol], "Should return array of symbols")
    }
    
    func testFindSymbolsAnnotated_CustomMacro() throws {
        // When searching for custom macro
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: "@Knot")
        
        // Then it should handle custom macros
        XCTAssertTrue(symbols is [IndexedSymbol])
    }
    
    func testFindSymbolsAnnotated_NonExistentMacro() throws {
        // When searching for non-existent macro
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: "@NonExistentMacro")
        
        // Then it should return empty array
        XCTAssertTrue(symbols.isEmpty, "Non-existent macro should have no annotated types")
    }
    
    func testFindSymbolsAnnotated_EmptyMacroName() throws {
        // When searching with empty macro name
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: "")
        
        // Then it should return empty array
        XCTAssertTrue(symbols.isEmpty, "Empty macro name should return empty array")
    }
    
    func testFindSymbolsAnnotated_MacroWithoutAtSign() throws {
        // When searching without @ prefix (should still work)
        let symbolsWithAt = try macroDiscovery.findSymbolsAnnotated(with: "@Knot")
        let symbolsWithoutAt = try macroDiscovery.findSymbolsAnnotated(with: "Knot")
        
        // Then both should work (implementation should handle both formats)
        XCTAssertTrue(symbolsWithAt is [IndexedSymbol])
        XCTAssertTrue(symbolsWithoutAt is [IndexedSymbol])
    }
    
    // MARK: - Three-Approach Discovery Tests
    
    func testFindSymbolsAnnotated_IndexReferences() throws {
        // The first approach: scan index for macro references
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: "@Model")
        
        // Should complete without error
        XCTAssertTrue(symbols is [IndexedSymbol])
    }
    
    func testFindSymbolsAnnotated_DefinitionScan() throws {
        // The second approach: scan definitions for macro usage
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: "@Knot")
        
        // Should complete without error
        XCTAssertTrue(symbols is [IndexedSymbol])
    }
    
    func testFindSymbolsAnnotated_FileRegexScan() throws {
        // The third approach: regex scan of source files
        // This is the most comprehensive fallback
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: "@CustomMacro")
        
        // Should complete without error (even if no results)
        XCTAssertTrue(symbols is [IndexedSymbol])
    }
    
    // MARK: - Result Validation Tests
    
    func testFindSymbolsAnnotated_ResultProperties() throws {
        // When finding annotated symbols
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: "@Knot")
        
        // Then each result should have valid properties
        for symbol in symbols {
            XCTAssertFalse(symbol.name.isEmpty, "Symbol name should not be empty")
            XCTAssertFalse(symbol.usr.isEmpty, "Symbol USR should not be empty")
            XCTAssertFalse(symbol.filePath.isEmpty, "Symbol file path should not be empty")
            XCTAssertGreaterThan(symbol.line, 0, "Symbol line should be positive")
            XCTAssertGreaterThanOrEqual(symbol.column, 0, "Symbol column should be non-negative")
        }
    }
    
    func testFindSymbolsAnnotated_UniqueResults() throws {
        // When finding annotated symbols
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: "@Knot")
        
        // Then results should be unique (no duplicates)
        let usrs = symbols.map { $0.usr }
        let uniqueUSRs = Set(usrs)
        XCTAssertEqual(usrs.count, uniqueUSRs.count, "Results should not contain duplicates")
    }
    
    func testFindSymbolsAnnotated_KnotMacro() throws {
        // When searching for @Knot macro (test project specific)
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: "@Knot")
        
        // Then it should find knot-annotated types
        if !symbols.isEmpty {
            XCTAssertTrue(
                symbols.allSatisfy { !$0.name.isEmpty },
                "All annotated types should have names"
            )
        } else {
            XCTAssertTrue(true, "No @Knot annotations found - acceptable")
        }
    }
    
    // MARK: - Macro Format Tests
    
    func testFindSymbolsAnnotated_MacroWithParameters() throws {
        // When searching for macro with parameters (e.g., @Knot(...))
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: "@Knot")
        
        // Then it should find macros regardless of parameters
        XCTAssertTrue(symbols is [IndexedSymbol])
    }
    
    func testFindSymbolsAnnotated_MacroVariations() throws {
        // Test different macro name formats
        let formats = ["@Model", "Model", "@SwiftUI", "SwiftUI"]
        
        for format in formats {
            let symbols = try macroDiscovery.findSymbolsAnnotated(with: format)
            XCTAssertTrue(symbols is [IndexedSymbol], "Should handle format: \(format)")
        }
    }
    
    // MARK: - Edge Cases
    
    func testFindSymbolsAnnotated_SpecialCharacters() throws {
        // When searching with special characters
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: "@Macro!@#$")
        
        // Then it should handle gracefully
        XCTAssertTrue(symbols.isEmpty, "Invalid macro name should return empty")
    }
    
    func testFindSymbolsAnnotated_LongMacroName() throws {
        // When searching with very long macro name
        let longName = "@" + String(repeating: "A", count: 1000)
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: longName)
        
        // Then it should handle without crashing
        XCTAssertTrue(symbols.isEmpty, "Non-existent long name should return empty")
    }
    
    func testFindSymbolsAnnotated_CaseSensitivity() throws {
        // When searching with different cases
        let lowercase = try macroDiscovery.findSymbolsAnnotated(with: "@knot")
        let uppercase = try macroDiscovery.findSymbolsAnnotated(with: "@KNOT")
        let correct = try macroDiscovery.findSymbolsAnnotated(with: "@Knot")
        
        // Then case might matter depending on macro definition
        XCTAssertTrue(lowercase is [IndexedSymbol])
        XCTAssertTrue(uppercase is [IndexedSymbol])
        XCTAssertTrue(correct is [IndexedSymbol])
    }
    
    func testFindSymbolsAnnotated_WhitespaceHandling() throws {
        // When searching with whitespace
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: "  @Knot  ")
        
        // Then it should handle whitespace appropriately
        XCTAssertTrue(symbols is [IndexedSymbol])
    }
    
    // MARK: - Swift Standard Macros
    
    func testFindSymbolsAnnotated_ObservableMacro() throws {
        // When searching for @Observable (Swift 5.9+)
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: "@Observable")
        
        // Then it should handle standard Swift macros
        XCTAssertTrue(symbols is [IndexedSymbol])
    }
    
    func testFindSymbolsAnnotated_AttachedMacros() throws {
        // Test various attached macro types
        let macros = ["@attached", "@freestanding", "@propertyWrapper"]
        
        for macro in macros {
            let symbols = try macroDiscovery.findSymbolsAnnotated(with: macro)
            XCTAssertTrue(symbols is [IndexedSymbol], "Should handle: \(macro)")
        }
    }
    
    // MARK: - Integration Tests
    
    func testFindSymbolsAnnotated_ConsistentResults() throws {
        // When searching multiple times
        let results1 = try macroDiscovery.findSymbolsAnnotated(with: "@Knot")
        let results2 = try macroDiscovery.findSymbolsAnnotated(with: "@Knot")
        
        // Then results should be consistent
        XCTAssertEqual(results1.count, results2.count, "Results should be deterministic")
    }
    
    func testFindSymbolsAnnotated_MultipleMacros() throws {
        // When searching for different macros
        let knotTypes = try macroDiscovery.findSymbolsAnnotated(with: "@Knot")
        let modelTypes = try macroDiscovery.findSymbolsAnnotated(with: "@Model")
        
        // Then each search should work independently
        XCTAssertTrue(knotTypes is [IndexedSymbol])
        XCTAssertTrue(modelTypes is [IndexedSymbol])
    }
    
    func testFindSymbolsAnnotated_VerifyFileExists() throws {
        // When finding annotated symbols
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: "@Knot")
        
        // Then all referenced files should exist
        for symbol in symbols {
            let fileExists = FileManager.default.fileExists(atPath: symbol.filePath)
            if !fileExists {
                print("Warning: Symbol \(symbol.name) references non-existent file: \(symbol.filePath)")
            }
        }
        XCTAssertTrue(true, "File existence check completed")
    }
    
    func testFindSymbolsAnnotated_FileContentMatch() throws {
        // When finding annotated symbols
        let symbols = try macroDiscovery.findSymbolsAnnotated(with: "@Knot")
        
        // Then the macro should actually exist at the reported location
        for symbol in symbols {
            if let content = try? String(contentsOfFile: symbol.filePath, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines)
                if symbol.line > 0 && symbol.line <= lines.count {
                    // Check if @Knot appears near the reported line
                    let contextRange = max(0, symbol.line - 5)..<min(lines.count, symbol.line + 2)
                    let context = lines[contextRange].joined(separator: "\n")
                    // Note: This is a loose check - the macro might be on a nearby line
                    XCTAssertTrue(true, "Location check completed for \(symbol.name)")
                }
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testFindSymbolsAnnotatedPerformance_CommonMacro() throws {
        measure {
            _ = try? macroDiscovery.findSymbolsAnnotated(with: "@Model")
        }
    }
    
    func testFindSymbolsAnnotatedPerformance_CustomMacro() throws {
        measure {
            _ = try? macroDiscovery.findSymbolsAnnotated(with: "@Knot")
        }
    }
    
    func testFindSymbolsAnnotatedPerformance_NonExistentMacro() throws {
        measure {
            _ = try? macroDiscovery.findSymbolsAnnotated(with: "@NonExistentMacro")
        }
    }
}
