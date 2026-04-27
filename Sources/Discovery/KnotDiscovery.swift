import Foundation
import IndexStoreDB

/// Discovery service specifically for finding Knot-annotated types
class KnotDiscovery {
    private let macroDiscovery: MacroDiscovery
    private let logger: Logger
    
    /// Known Knot macro types in the codebase
    enum KnotType: String {
        case knot = "Knot"
        case componentKnot = "ComponentKnot"
        case apiKnot = "ApiKnot"
    }
    
    init(macroDiscovery: MacroDiscovery, logger: Logger) {
        self.macroDiscovery = macroDiscovery
        self.logger = logger
    }
    
    // MARK: - Knot Discovery
    
    /// Find all symbols annotated with @Knot
    /// - Returns: Array of indexed symbols with @Knot annotation
    func findKnotSymbols() throws -> [IndexedSymbol] {
        return try macroDiscovery.findSymbolsAnnotated(with: KnotType.knot.rawValue)
    }
    
    /// Find all symbols annotated with @ComponentKnot
    /// - Returns: Array of indexed symbols with @ComponentKnot annotation
    func findComponentKnotSymbols() throws -> [IndexedSymbol] {
        return try macroDiscovery.findSymbolsAnnotated(with: KnotType.componentKnot.rawValue)
    }
    
    /// Find all symbols annotated with @ApiKnot
    /// - Returns: Array of indexed symbols with @ApiKnot annotation
    func findApiKnotSymbols() throws -> [IndexedSymbol] {
        return try macroDiscovery.findSymbolsAnnotated(with: KnotType.apiKnot.rawValue)
    }
    
    /// Find all symbols annotated with any Knot-type macro
    /// - Returns: Dictionary mapping knot type to symbols
    func findAllKnotSymbols() throws -> [KnotType: [IndexedSymbol]] {
        var results: [KnotType: [IndexedSymbol]] = [:]
        
        logger.info("Discovering all Knot-annotated symbols...")
        
        for knotType in [KnotType.knot, .componentKnot, .apiKnot] {
            do {
                let symbols = try macroDiscovery.findSymbolsAnnotated(with: knotType.rawValue)
                if !symbols.isEmpty {
                    results[knotType] = symbols
                    logger.debug("  Found \(symbols.count) @\(knotType.rawValue) symbols")
                }
            } catch {
                logger.warning("Failed to find @\(knotType.rawValue) symbols: \(error)")
            }
        }
        
        logger.info("Total Knot symbols found: \(results.values.flatMap { $0 }.count)")
        return results
    }
    
    /// Find symbols annotated with a custom Knot-type macro
    /// - Parameter knotTypeName: The custom Knot macro name (without @ prefix)
    /// - Returns: Array of indexed symbols
    func findCustomKnotSymbols(macroName: String) throws -> [IndexedSymbol] {
        return try macroDiscovery.findSymbolsAnnotated(with: macroName)
    }
}
