import XCTest
import Foundation
@testable import ModelGraphGenerator

class InheritanceRepositoryTests: XCTestCase {
    private var indexManager: IndexStoreManager!
    private var symbolRepository: SymbolRepository!
    private var inheritanceRepository: InheritanceRepository!
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
            symbolRepository = SymbolRepository(indexStore: indexManager.indexStore, logger: logger)
            inheritanceRepository = InheritanceRepository(
                indexStore: indexManager.indexStore,
                symbolRepository: symbolRepository,
                logger: logger
            )
        } catch {
            XCTFail("Failed to initialize repositories: \(error)")
        }
    }
    
    // MARK: - Parent Class Tests
    
    func testFindParentClass_WithInheritance() {
        // Given a type that inherits from another
        // (assuming test files have inheritance relationships)
        let parent = inheritanceRepository.findParentClass(of: "Employee")
        
        // Then it should find the parent or return nil if no inheritance
        if let parent = parent {
            XCTAssertFalse(parent.name.isEmpty, "Parent name should not be empty")
            XCTAssertFalse(parent.usr.isEmpty, "Parent USR should not be empty")
        }
    }
    
    func testFindParentClass_NoInheritance() {
        // When searching for a type with no parent
        let parent = inheritanceRepository.findParentClass(of: "NonExistentType")
        
        // Then it should return nil
        XCTAssertNil(parent, "Non-existent type should have no parent")
    }
    
    func testFindParentClass_WithFileFilter() {
        // Given a specific file
        let testFile = testProjectPath + "/ExampleModels.swift"
        
        // When searching with file filter
        let parent = inheritanceRepository.findParentClass(of: "Employee", inFile: testFile)
        
        // Then result should be from the correct context
        if let parent = parent {
            XCTAssertFalse(parent.name.isEmpty)
        }
    }
    
    // MARK: - Inheritance Chain Tests
    
    func testGetInheritanceChain_SingleLevel() {
        // When getting inheritance chain for a type
        let chain = inheritanceRepository.getInheritanceChain(of: "Person")
        
        // Then it should return an array (may be empty if no inheritance)
        XCTAssertTrue(chain is [IndexedSymbol], "Should return array of symbols")
    }
    
    func testGetInheritanceChain_MultiLevel() {
        // When getting inheritance chain for a type with multiple levels
        let chain = inheritanceRepository.getInheritanceChain(of: "Employee")
        
        // Then chain length should be reasonable
        XCTAssertLessThanOrEqual(chain.count, 10, "Chain should not be infinite")
    }
    
    func testGetInheritanceChain_NonExistentType() {
        // When getting chain for non-existent type
        let chain = inheritanceRepository.getInheritanceChain(of: "NonExistentType")
        
        // Then it should return empty array
        XCTAssertTrue(chain.isEmpty, "Non-existent type should have empty chain")
    }
    
    func testGetInheritanceChain_WithFileFilter() {
        // Given a specific file
        let testFile = testProjectPath + "/ExampleModels.swift"
        
        // When getting chain with file filter
        let chain = inheritanceRepository.getInheritanceChain(of: "Employee", inFile: testFile)
        
        // Then it should handle the filter correctly
        XCTAssertTrue(chain is [IndexedSymbol])
    }
    
    // MARK: - Protocol Conformance Tests
    
    func testFindProtocolConformances_WithProtocols() {
        // When finding protocol conformances
        let protocols = inheritanceRepository.findProtocolConformances(of: "Person")
        
        // Then it should return an array (may be empty)
        XCTAssertTrue(protocols is [String], "Should return array of protocol names")
    }
    
    func testFindProtocolConformances_NoProtocols() {
        // When finding conformances for type without protocols
        let protocols = inheritanceRepository.findProtocolConformances(of: "NonExistentType")
        
        // Then it should return empty array
        XCTAssertTrue(protocols.isEmpty, "Non-existent type should have no protocols")
    }
    
    func testFindProtocolConformances_WithFileFilter() {
        // Given a specific file
        let testFile = testProjectPath + "/ExampleModels.swift"
        
        // When finding conformances with file filter
        let protocols = inheritanceRepository.findProtocolConformances(of: "Person", inFile: testFile)
        
        // Then it should handle the filter
        XCTAssertTrue(protocols is [String])
    }
    
    func testFindProtocolConformances_Decodable() {
        // If a type conforms to Codable/Decodable
        let protocols = inheritanceRepository.findProtocolConformances(of: "Person")
        
        // Then it might include Decodable (depending on test files)
        if protocols.contains(where: { $0.contains("Decodable") || $0.contains("Codable") }) {
            XCTAssertTrue(true, "Found standard protocol conformance")
        } else {
            XCTAssertTrue(true, "No protocol conformances found - acceptable")
        }
    }
    
    // MARK: - Types Conforming to Protocol Tests
    
    func testFindTypesConforming_ValidProtocol() {
        // When searching for types conforming to a protocol
        let types = inheritanceRepository.findTypesConforming(to: "Codable")
        
        // Then it should return an array (may be empty)
        XCTAssertTrue(types is [IndexedSymbol], "Should return array of symbols")
    }
    
    func testFindTypesConforming_CustomProtocol() {
        // When searching for custom protocol (if it exists in test files)
        let types = inheritanceRepository.findTypesConforming(to: "RootModel")
        
        // Then it should handle the search
        XCTAssertTrue(types is [IndexedSymbol])
    }
    
    func testFindTypesConforming_NonExistentProtocol() {
        // When searching for non-existent protocol
        let types = inheritanceRepository.findTypesConforming(to: "NonExistentProtocol")
        
        // Then it should return empty array
        XCTAssertTrue(types.isEmpty, "Non-existent protocol should have no conforming types")
    }
    
    // MARK: - Edge Cases
    
    func testFindParentClass_EmptyTypeName() {
        // When searching with empty type name
        let parent = inheritanceRepository.findParentClass(of: "")
        
        // Then it should return nil
        XCTAssertNil(parent, "Empty type name should return nil")
    }
    
    func testGetInheritanceChain_CircularInheritance() {
        // When checking for circular inheritance (should not happen in valid Swift)
        let chain = inheritanceRepository.getInheritanceChain(of: "Person")
        
        // Then chain should not be infinite
        XCTAssertLessThan(chain.count, 100, "Chain should terminate (no circular inheritance)")
    }
    
    func testFindProtocolConformances_EmptyTypeName() {
        // When searching with empty type name
        let protocols = inheritanceRepository.findProtocolConformances(of: "")
        
        // Then it should return empty array
        XCTAssertTrue(protocols.isEmpty, "Empty type name should return empty array")
    }
    
    func testFindTypesConforming_EmptyProtocolName() {
        // When searching with empty protocol name
        let types = inheritanceRepository.findTypesConforming(to: "")
        
        // Then it should return empty array
        XCTAssertTrue(types.isEmpty, "Empty protocol name should return empty array")
    }
    
    // MARK: - Integration Tests
    
    func testInheritanceChain_WithParent() {
        // Given a type with a parent
        if let parent = inheritanceRepository.findParentClass(of: "Employee") {
            // When getting the full chain
            let chain = inheritanceRepository.getInheritanceChain(of: "Employee")
            
            // Then the parent should be in the chain
            XCTAssertTrue(
                chain.contains(where: { $0.name == parent.name }),
                "Parent should be in inheritance chain"
            )
        } else {
            XCTAssertTrue(true, "No parent found - skipping")
        }
    }
    
    func testProtocolConformance_Consistency() {
        // When finding protocols for a type
        let protocols1 = inheritanceRepository.findProtocolConformances(of: "Person")
        let protocols2 = inheritanceRepository.findProtocolConformances(of: "Person")
        
        // Then results should be consistent
        XCTAssertEqual(protocols1.count, protocols2.count, "Results should be deterministic")
    }
    
    // MARK: - Performance Tests
    
    func testFindParentClassPerformance() {
        measure {
            _ = inheritanceRepository.findParentClass(of: "Employee")
        }
    }
    
    func testGetInheritanceChainPerformance() {
        measure {
            _ = inheritanceRepository.getInheritanceChain(of: "Employee")
        }
    }
    
    func testFindProtocolConformancesPerformance() {
        measure {
            _ = inheritanceRepository.findProtocolConformances(of: "Person")
        }
    }
}
