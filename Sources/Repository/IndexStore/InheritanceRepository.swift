import Foundation
import IndexStoreDB

/// Repository for inheritance and protocol conformance queries
class InheritanceRepository {
    private let indexStore: IndexStoreDB
    private let symbolRepository: SymbolRepository
    private let logger: Logger
    
    init(indexStore: IndexStoreDB, symbolRepository: SymbolRepository, logger: Logger) {
        self.indexStore = indexStore
        self.symbolRepository = symbolRepository
        self.logger = logger
    }
    
    // MARK: - Inheritance Queries
    
    /// Find the parent class of a given type
    /// - Parameters:
    ///   - typeName: Name of the type to find parent for
    ///   - inFile: Optional file path to scope the search
    /// - Returns: IndexedSymbol of the parent class, or nil if no parent exists
    func findParentClass(of typeName: String, inFile filePath: String? = nil) -> IndexedSymbol? {
        // First find the symbol for this type
        guard let typeSymbol = symbolRepository.findSymbol(byName: typeName, inFile: filePath) else {
            return nil
        }
        
        // Query IndexStore for base class relationships
        var parentSymbol: IndexedSymbol?
        
        // Use forEachSymbolOccurrence to find where this type references a base class
        indexStore.forEachSymbolOccurrence(byUSR: typeSymbol.usr, roles: .baseOf) { occurrence in
            // The occurrence points to the base type
            let baseSymbolName = occurrence.symbol.name
            
            // Filter out system types (Foundation, UIKit, etc.)
            if !TypeUtilities.isSystemType(baseSymbolName) && occurrence.symbol.kind != .protocol {
                // Get the location of this parent symbol
                parentSymbol = IndexedSymbol(
                    name: occurrence.symbol.name,
                    usr: occurrence.symbol.usr,
                    kind: occurrence.symbol.kind,
                    filePath: occurrence.location.path,
                    line: occurrence.location.line,
                    column: occurrence.location.utf8Column
                )
                return false // Stop after finding first custom parent
            }
            return true // Continue searching
        }
        
        return parentSymbol
    }
    
    /// Get the full inheritance chain for a type
    /// - Parameters:
    ///   - typeName: Name of the type
    ///   - inFile: Optional file path to scope the search
    /// - Returns: Array of IndexedSymbols representing the inheritance chain (immediate parent first)
    func getInheritanceChain(of typeName: String, inFile filePath: String? = nil) -> [IndexedSymbol] {
        var chain: [IndexedSymbol] = []
        var currentType = typeName
        var currentFile = filePath
        var visitedTypes = Set<String>() // Prevent infinite loops
        
        while let parent = findParentClass(of: currentType, inFile: currentFile) {
            // Prevent cycles
            if visitedTypes.contains(parent.usr) {
                break
            }
            visitedTypes.insert(parent.usr)
            
            chain.append(parent)
            currentType = parent.name
            currentFile = parent.filePath // Update file context for next lookup
        }
        
        return chain
    }
    
    // MARK: - Protocol Conformance Queries
    
    /// Find all protocol conformances for a type
    /// - Parameters:
    ///   - typeName: Name of the type
    ///   - inFile: Optional file path to scope the search
    /// - Returns: Array of protocol names this type conforms to
    func findProtocolConformances(of typeName: String, inFile filePath: String? = nil) -> [String] {
        guard let typeSymbol = symbolRepository.findSymbol(byName: typeName, inFile: filePath) else {
            return []
        }
        
        var protocols: [String] = []
        
        // Use forEachSymbolOccurrence to find protocol conformances
        indexStore.forEachSymbolOccurrence(byUSR: typeSymbol.usr, roles: .baseOf) { occurrence in
            // Check if this is a protocol (not a class)
            if occurrence.symbol.kind == .protocol {
                protocols.append(occurrence.symbol.name)
            }
            return true // Continue to find all protocols
        }
        
        return protocols
    }
    
    /// Find all types that conform to a given protocol
    /// - Parameter protocolName: Name of the protocol
    /// - Returns: Array of IndexedSymbols for all conforming types
    func findTypesConforming(to protocolName: String) -> [IndexedSymbol] {
        var conformingTypes: [IndexedSymbol] = []
        
        // First find the protocol symbol
        guard let protocolSymbol = symbolRepository.findSymbol(byName: protocolName) else {
            return []
        }
        
        // Find all types that have this protocol as a base
        var seenUSRs = Set<String>()
        
        indexStore.forEachSymbolOccurrence(byUSR: protocolSymbol.usr, roles: .baseOf) { occurrence in
            // The location where the protocol is referenced as a base
            // We need to find the type at this location
            if let conformingType = self.symbolRepository.findTypeAtLocation(filePath: occurrence.location.path, line: occurrence.location.line) {
                if !seenUSRs.contains(conformingType.usr) {
                    seenUSRs.insert(conformingType.usr)
                    conformingTypes.append(conformingType)
                }
            }
            return true
        }
        
        return conformingTypes
    }
}
