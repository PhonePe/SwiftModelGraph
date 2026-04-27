import Foundation
import IndexStoreDB

/// Coordinates all discovery strategies for finding symbols in the codebase
class DiscoveryCoordinator {
    let protocolDiscovery: ProtocolDiscovery
    let macroDiscovery: MacroDiscovery
    let knotDiscovery: KnotDiscovery
    private let logger: Logger
    
    init(
        indexStore: IndexStoreDB,
        symbolRepository: SymbolRepository,
        sourceRoot: String,
        logger: Logger
    ) {
        self.logger = logger
        self.protocolDiscovery = ProtocolDiscovery(
            indexStore: indexStore,
            symbolRepository: symbolRepository,
            sourceRoot: sourceRoot,
            logger: logger
        )
        self.macroDiscovery = MacroDiscovery(
            indexStore: indexStore,
            symbolRepository: symbolRepository,
            sourceRoot: sourceRoot,
            logger: logger
        )
        self.knotDiscovery = KnotDiscovery(
            macroDiscovery: macroDiscovery,
            logger: logger
        )
    }
    
    // MARK: - Unified Discovery Interface
    
    /// Find root model symbols using all available strategies
    /// - Returns: Array of symbols identified as root models
    func findRootModels() throws -> [IndexedSymbol] {
        logger.info("Discovering root models...")
        var rootSymbols: [IndexedSymbol] = []
        
        // Strategy 1: Protocol conformance (@RootModel protocol)
        logger.debug("  Strategy 1: Searching for RootModel protocol conformance...")
        do {
            let protocolSymbols = try protocolDiscovery.findSymbolsConforming(to: "RootModel")
            logger.debug("    Found \(protocolSymbols.count) symbols via protocol")
            rootSymbols.append(contentsOf: protocolSymbols)
        } catch {
            logger.warning("    Protocol discovery failed: \(error)")
        }
        
        // Strategy 2: Macro annotation (@RootModel macro)
        logger.debug("  Strategy 2: Searching for @RootModel macro...")
        do {
            let macroSymbols = try macroDiscovery.findSymbolsAnnotated(with: "RootModel")
            logger.debug("    Found \(macroSymbols.count) symbols via macro")
            
            // Merge without duplicates (based on USR)
            let existingUSRs = Set(rootSymbols.map { $0.usr })
            for symbol in macroSymbols where !existingUSRs.contains(symbol.usr) {
                rootSymbols.append(symbol)
            }
        } catch {
            logger.warning("    Macro discovery failed: \(error)")
        }
        
        logger.info("Total root models found: \(rootSymbols.count)")
        return rootSymbols
    }
    
    /// Find all Knot-annotated symbols
    /// - Returns: Dictionary mapping Knot types to symbols
    func findAllKnots() throws -> [KnotDiscovery.KnotType: [IndexedSymbol]] {
        return try knotDiscovery.findAllKnotSymbols()
    }
    
    /// Find types annotated with @ChimeraPolymorphic
    /// - Returns: Array of tuples containing (symbol, schemaId)
    func findChimeraPolymorphicTypes() throws -> [(symbol: IndexedSymbol, schemaId: String)] {
        logger.info("Discovering @ChimeraPolymorphic types...")
        let result = try macroDiscovery.discoverChimeraPolymorphicTypes()
        logger.info("Found \(result.count) @ChimeraPolymorphic types")
        return result
    }
    
    /// Find symbols by protocol conformance
    /// - Parameter protocolName: The protocol name
    /// - Returns: Array of conforming symbols
    func findByProtocol(_ protocolName: String) throws -> [IndexedSymbol] {
        return try protocolDiscovery.findSymbolsConforming(to: protocolName)
    }
    
    /// Find symbols by macro annotation
    /// - Parameter macroName: The macro name (without @ prefix)
    /// - Returns: Array of annotated symbols
    func findByMacro(_ macroName: String) throws -> [IndexedSymbol] {
        var symbols = try macroDiscovery.findSymbolsAnnotated(with: macroName)
        
        // For @ChimeraSchema, also find types with property-level schemas
        if macroName == "ChimeraSchema" {
            logger.debug("  Also searching for types with property-level @ChimeraSchema...")
            let propertyLevelTypes = try macroDiscovery.findTypesWithPropertyLevelSchemas()
            
            // Merge without duplicates (based on USR)
            let existingUSRs = Set(symbols.map { $0.usr })
            for symbol in propertyLevelTypes where !existingUSRs.contains(symbol.usr) {
                symbols.append(symbol)
                logger.debug("    Added type with property-level schema: \(symbol.name)")
            }
        }
        
        return symbols
    }
    
    /// Discover symbols using multiple strategies and merge results
    /// - Parameters:
    ///   - protocolName: Optional protocol name to search for
    ///   - macroName: Optional macro name to search for
    /// - Returns: Merged array of unique symbols (de-duplicated by USR)
    func discover(
        protocol protocolName: String? = nil,
        macro macroName: String? = nil
    ) throws -> [IndexedSymbol] {
        var symbols: [IndexedSymbol] = []
        var usrSet: Set<String> = []
        
        if let protocolName = protocolName {
            logger.debug("Discovering via protocol: \(protocolName)")
            let protocolSymbols = try protocolDiscovery.findSymbolsConforming(to: protocolName)
            for symbol in protocolSymbols {
                if !usrSet.contains(symbol.usr) {
                    symbols.append(symbol)
                    usrSet.insert(symbol.usr)
                }
            }
        }
        
        if let macroName = macroName {
            logger.debug("Discovering via macro: @\(macroName)")
            let macroSymbols = try macroDiscovery.findSymbolsAnnotated(with: macroName)
            for symbol in macroSymbols {
                if !usrSet.contains(symbol.usr) {
                    symbols.append(symbol)
                    usrSet.insert(symbol.usr)
                }
            }
        }
        
        return symbols
    }
    
    /// Check if a specific symbol has a macro annotation
    /// - Parameters:
    ///   - symbol: The symbol to check
    ///   - macroName: The macro name to look for
    /// - Returns: True if the symbol has the annotation
    func symbolHasMacro(_ symbol: IndexedSymbol, macroName: String) -> Bool {
        // Use MacroDiscovery to verify if the symbol at this location has the macro
        do {
            let symbols = try macroDiscovery.findSymbolsAnnotated(with: macroName)
            return symbols.contains { $0.usr == symbol.usr }
        } catch {
            logger.debug("Failed to check macro for symbol: \(error)")
            return false
        }
    }
}
