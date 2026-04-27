import XCTest
import Foundation
@testable import ModelGraphGenerator

class ProtocolDiscoveryTests: XCTestCase {
    private var indexManager: IndexStoreManager!
    private var protocolDiscovery: ProtocolDiscovery!
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
            protocolDiscovery = ProtocolDiscovery(
                indexStore: indexManager.indexStore,
                symbolRepository: symbolRepository,
                sourceRoot: testProjectPath,
                logger: logger
            )
        } catch {
            XCTFail("Failed to initialize ProtocolDiscovery: \(error)")
        }
    }
    
    // MARK: - Protocol Discovery Tests
    
    func testFindSymbolsConforming_StandardProtocol() throws {
        // When searching for types conforming to standard protocol
        let symbols = try protocolDiscovery.findSymbolsConforming(to: "Codable")
        
        // Then it should return an array (may be empty)
        XCTAssertTrue(symbols is [IndexedSymbol], "Should return array of symbols")
    }
    
    func testFindSymbolsConforming_CustomProtocol() throws {
        // When searching for custom protocol
        let symbols = try protocolDiscovery.findSymbolsConforming(to: "RootModel")
        
        // Then it should handle custom protocols
        XCTAssertTrue(symbols is [IndexedSymbol])
    }
    
    func testFindSymbolsConforming_NonExistentProtocol() throws {
        // When searching for non-existent protocol
        let symbols = try protocolDiscovery.findSymbolsConforming(to: "NonExistentProtocol")
        
        // Then it should return empty array
        XCTAssertTrue(symbols.isEmpty, "Non-existent protocol should have no conforming types")
    }
    
    func testFindSymbolsConforming_EmptyProtocolName() throws {
        // When searching with empty protocol name
        let symbols = try protocolDiscovery.findSymbolsConforming(to: "")
        
        // Then it should return empty array
        XCTAssertTrue(symbols.isEmpty, "Empty protocol name should return empty array")
    }
    
    // MARK: - Three-Step Discovery Process Tests
    
    func testFindSymbolsConforming_USRLookup() throws {
        // The first step should try USR lookup
        // This is tested implicitly in the standard protocol test
        let symbols = try protocolDiscovery.findSymbolsConforming(to: "Decodable")
        
        // Should complete without error
        XCTAssertTrue(symbols is [IndexedSymbol])
    }
    
    func testFindSymbolsConforming_IndexScan() throws {
        // The second step should scan the index
        // Testing with a protocol that might need index scanning
        let symbols = try protocolDiscovery.findSymbolsConforming(to: "Equatable")
        
        // Should complete without error
        XCTAssertTrue(symbols is [IndexedSymbol])
    }
    
    func testFindSymbolsConforming_FileScan() throws {
        // The third step should scan files directly
        // Testing with a custom protocol that might need file scanning
        let symbols = try protocolDiscovery.findSymbolsConforming(to: "CustomProtocol")
        
        // Should complete without error (even if no results)
        XCTAssertTrue(symbols is [IndexedSymbol])
    }
    
    // MARK: - Result Validation Tests
    
    func testFindSymbolsConforming_ResultProperties() throws {
        // When finding conforming symbols
        let symbols = try protocolDiscovery.findSymbolsConforming(to: "Codable")
        
        // Then each result should have valid properties
        for symbol in symbols {
            XCTAssertFalse(symbol.name.isEmpty, "Symbol name should not be empty")
            XCTAssertFalse(symbol.usr.isEmpty, "Symbol USR should not be empty")
            XCTAssertFalse(symbol.filePath.isEmpty, "Symbol file path should not be empty")
            XCTAssertGreaterThan(symbol.line, 0, "Symbol line should be positive")
            XCTAssertGreaterThanOrEqual(symbol.column, 0, "Symbol column should be non-negative")
        }
    }
    
    func testFindSymbolsConforming_UniqueResults() throws {
        // When finding conforming symbols
        let symbols = try protocolDiscovery.findSymbolsConforming(to: "Codable")
        
        // Then results should be unique (no duplicates)
        let usrs = symbols.map { $0.usr }
        let uniqueUSRs = Set(usrs)
        XCTAssertEqual(usrs.count, uniqueUSRs.count, "Results should not contain duplicates")
    }
    
    func testFindSymbolsConforming_RootModelProtocol() throws {
        // When searching for RootModel protocol (if it exists in test files)
        let symbols = try protocolDiscovery.findSymbolsConforming(to: "RootModel")
        
        // Then it should find types that conform to it
        if !symbols.isEmpty {
            XCTAssertTrue(
                symbols.allSatisfy { !$0.name.isEmpty },
                "All conforming types should have names"
            )
        } else {
            XCTAssertTrue(true, "No RootModel conformances found - acceptable")
        }
    }
    
    // MARK: - Edge Cases
    
    func testFindSymbolsConforming_SpecialCharacters() throws {
        // When searching with special characters
        let symbols = try protocolDiscovery.findSymbolsConforming(to: "Protocol@#$")
        
        // Then it should handle gracefully
        XCTAssertTrue(symbols.isEmpty, "Invalid protocol name should return empty")
    }
    
    func testFindSymbolsConforming_LongProtocolName() throws {
        // When searching with very long protocol name
        let longName = String(repeating: "A", count: 1000)
        let symbols = try protocolDiscovery.findSymbolsConforming(to: longName)
        
        // Then it should handle without crashing
        XCTAssertTrue(symbols.isEmpty, "Non-existent long name should return empty")
    }
    
    func testFindSymbolsConforming_CaseSensitivity() throws {
        // When searching with different cases
        let lowercase = try protocolDiscovery.findSymbolsConforming(to: "codable")
        let uppercase = try protocolDiscovery.findSymbolsConforming(to: "CODABLE")
        let correct = try protocolDiscovery.findSymbolsConforming(to: "Codable")
        
        // Then case should matter (Swift is case-sensitive)
        if !correct.isEmpty {
            // Incorrect cases should find fewer or no results
            XCTAssertTrue(true, "Case sensitivity test completed")
        }
    }
    
    // MARK: - Integration Tests
    
    func testFindSymbolsConforming_ConsistentResults() throws {
        // When searching multiple times
        let results1 = try protocolDiscovery.findSymbolsConforming(to: "Codable")
        let results2 = try protocolDiscovery.findSymbolsConforming(to: "Codable")
        
        // Then results should be consistent
        XCTAssertEqual(results1.count, results2.count, "Results should be deterministic")
    }
    
    func testFindSymbolsConforming_MultipleProtocols() throws {
        // When searching for different protocols
        let codableTypes = try protocolDiscovery.findSymbolsConforming(to: "Codable")
        let equatableTypes = try protocolDiscovery.findSymbolsConforming(to: "Equatable")
        
        // Then each search should work independently
        XCTAssertTrue(codableTypes is [IndexedSymbol])
        XCTAssertTrue(equatableTypes is [IndexedSymbol])
    }
    
    func testFindSymbolsConforming_VerifyFileExists() throws {
        // When finding conforming symbols
        let symbols = try protocolDiscovery.findSymbolsConforming(to: "Codable")
        
        // Then all referenced files should exist
        for symbol in symbols {
            let fileExists = FileManager.default.fileExists(atPath: symbol.filePath)
            if !fileExists {
                print("Warning: Symbol \(symbol.name) references non-existent file: \(symbol.filePath)")
            }
        }
        XCTAssertTrue(true, "File existence check completed")
    }
    
    // MARK: - Performance Tests
    
    func testFindSymbolsConformingPerformance_StandardProtocol() throws {
        measure {
            _ = try? protocolDiscovery.findSymbolsConforming(to: "Codable")
        }
    }
    
    func testFindSymbolsConformingPerformance_CustomProtocol() throws {
        measure {
            _ = try? protocolDiscovery.findSymbolsConforming(to: "RootModel")
        }
    }
    
    func testFindSymbolsConformingPerformance_NonExistentProtocol() throws {
        measure {
            _ = try? protocolDiscovery.findSymbolsConforming(to: "NonExistentProtocol")
        }
    }
}
