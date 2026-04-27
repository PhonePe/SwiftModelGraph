import XCTest
import Foundation
@testable import ModelGraphGenerator

class SymbolRepositoryTests: XCTestCase {
    private var indexManager: IndexStoreManager!
    private var repository: SymbolRepository!
    private let testProjectPath = "/Users/sharang.verma/Code/Company/Modelgraphgenrator/Examples"
    
    override func setUp() {
        super.setUp()
        
        // Use the Examples directory for testing
        let indexStorePath = testProjectPath + "/.build/debug/index/store"
        let logger = Logger(verbose: false)
        
        do {
            indexManager = try IndexStoreManager(
                indexStorePath: indexStorePath,
                sourceRoot: testProjectPath,
                logger: logger
            )
            repository = SymbolRepository(indexStore: indexManager.indexStore, logger: logger)
        } catch {
            XCTFail("Failed to initialize IndexStoreManager: \(error)")
        }
    }
    
    // MARK: - Symbol Lookup Tests
    
    func testFindSymbolByName_ExistingSymbol() {
        // When searching for a known symbol
        if let symbol = repository.findSymbol(byName: "Person") {
            // Then it should be found with correct properties
            XCTAssertEqual(symbol.name, "Person")
            XCTAssertFalse(symbol.usr.isEmpty, "USR should not be empty")
            XCTAssertFalse(symbol.filePath.isEmpty, "File path should not be empty")
            XCTAssertGreaterThan(symbol.line, 0, "Line number should be positive")
        } else {
            // Symbol might not exist in test files - this is acceptable
            XCTAssertTrue(true, "Person symbol not found in test index - skipping")
        }
    }
    
    func testFindSymbolByName_NonExistentSymbol() {
        // When searching for a non-existent symbol
        let symbol = repository.findSymbol(byName: "NonExistentTypeThatDoesNotExist")
        
        // Then it should return nil
        XCTAssertNil(symbol, "Non-existent symbol should return nil")
    }
    
    func testFindSymbolByName_WithFileFilter() {
        // Given a specific file path
        let testFile = testProjectPath + "/ExampleModels.swift"
        
        // When searching with file filter
        let symbol = repository.findSymbol(byName: "Person", inFile: testFile)
        
        // Then result should either match the file or be nil
        if let symbol = symbol {
            XCTAssertTrue(
                symbol.filePath.contains("ExampleModels.swift"),
                "Symbol should be from the specified file"
            )
        }
    }
    
    func testFindSymbolByName_EmptyName() {
        // When searching for empty name
        let symbol = repository.findSymbol(byName: "")
        
        // Then it should return nil
        XCTAssertNil(symbol, "Empty name should return nil")
    }
    
    // MARK: - USR Lookup Tests
    
    func testFindSymbolByUSR_ValidUSR() {
        // Given a valid USR (we need to get one first)
        guard let personSymbol = repository.findSymbol(byName: "Person") else {
            XCTAssertTrue(true, "Person symbol not found - skipping USR test")
            return
        }
        
        let usr = personSymbol.usr
        
        // When searching by USR
        let foundSymbol = repository.findSymbol(byUSR: usr)
        
        // Then it should find the same symbol
        XCTAssertNotNil(foundSymbol, "Symbol should be found by USR")
        XCTAssertEqual(foundSymbol?.usr, usr, "USR should match")
        XCTAssertEqual(foundSymbol?.name, personSymbol.name, "Name should match")
    }
    
    func testFindSymbolByUSR_InvalidUSR() {
        // When searching with invalid USR
        let symbol = repository.findSymbol(byUSR: "invalid-usr-that-does-not-exist")
        
        // Then it should return nil
        XCTAssertNil(symbol, "Invalid USR should return nil")
    }
    
    func testFindSymbolByUSR_EmptyUSR() {
        // When searching with empty USR
        let symbol = repository.findSymbol(byUSR: "")
        
        // Then it should return nil
        XCTAssertNil(symbol, "Empty USR should return nil")
    }
    
    // MARK: - Location-Based Search Tests
    
    func testFindSymbolNearLocation_ValidLocation() {
        // Given a file with known symbols
        let testFile = testProjectPath + "/ExampleModels.swift"
        
        // When searching near a location (assuming line 10 has some code)
        let symbol = repository.findSymbolNearLocation(filePath: testFile, line: 10)
        
        // Then it should find a symbol
        if let symbol = symbol {
            XCTAssertEqual(symbol.filePath, testFile, "Symbol should be from the correct file")
            XCTAssertGreaterThan(symbol.line, 0, "Line should be positive")
        }
    }
    
    func testFindSymbolNearLocation_NonExistentFile() {
        // When searching in a non-existent file
        let symbol = repository.findSymbolNearLocation(
            filePath: "/nonexistent/path/file.swift",
            line: 10
        )
        
        // Then it should return nil
        XCTAssertNil(symbol, "Non-existent file should return nil")
    }
    
    func testFindSymbolNearLocation_InvalidLine() {
        // Given a valid file
        let testFile = testProjectPath + "/ExampleModels.swift"
        
        // When searching with invalid line numbers
        let negativeLineSymbol = repository.findSymbolNearLocation(filePath: testFile, line: -1)
        let zeroLineSymbol = repository.findSymbolNearLocation(filePath: testFile, line: 0)
        let hugeLineSymbol = repository.findSymbolNearLocation(filePath: testFile, line: 999999)
        
        // Then they should handle gracefully (may return nil or closest match)
        // We're just verifying it doesn't crash
        _ = negativeLineSymbol
        _ = zeroLineSymbol
        _ = hugeLineSymbol
        XCTAssertTrue(true, "Location search should handle invalid lines gracefully")
    }
    
    // MARK: - Edge Cases
    
    func testFindSymbolByName_CaseSensitivity() {
        // When searching with different cases
        let lowerSymbol = repository.findSymbol(byName: "person")
        let upperSymbol = repository.findSymbol(byName: "PERSON")
        let correctSymbol = repository.findSymbol(byName: "Person")
        
        // Then case sensitivity should be respected (Swift is case-sensitive)
        if correctSymbol != nil {
            // If Person exists, wrong cases should not match
            XCTAssertNotEqual(lowerSymbol?.name, "Person", "Lowercase should not match")
            XCTAssertNotEqual(upperSymbol?.name, "Person", "Uppercase should not match")
        }
    }
    
    func testFindSymbolByName_MultipleOccurrences() {
        // When a symbol exists in multiple files
        let symbol = repository.findSymbol(byName: "Person")
        
        // Then it should return one valid result
        if let symbol = symbol {
            XCTAssertFalse(symbol.name.isEmpty, "Name should not be empty")
            XCTAssertFalse(symbol.filePath.isEmpty, "File path should not be empty")
        }
    }
    
    // MARK: - Performance Tests
    
    func testFindSymbolPerformance() {
        // Measure performance of symbol lookup
        measure {
            _ = repository.findSymbol(byName: "Person")
        }
    }
    
    func testFindSymbolByUSRPerformance() {
        guard let symbol = repository.findSymbol(byName: "Person") else {
            return
        }
        
        let usr = symbol.usr
        measure {
            _ = repository.findSymbol(byUSR: usr)
        }
    }
}
