import Foundation

/// Builds the relationship graph by coordinating between IndexStoreDB and SwiftSyntax
class GraphBuilder {
    private let indexManager: IndexStoreManager
    private let sourceRoot: String
    private let parser: SwiftFileParser
    private let logger: Logger
    private let cycleDetector: CycleDetector
    private let symbolProcessor: SymbolProcessor
    
    init(indexManager: IndexStoreManager, sourceRoot: String, logger: Logger) {
        self.indexManager = indexManager
        self.sourceRoot = sourceRoot
        self.parser = SwiftFileParser(logger: logger)
        self.logger = logger
        self.cycleDetector = CycleDetector()
        self.symbolProcessor = SymbolProcessor(
            indexManager: indexManager,
            sourceRoot: sourceRoot,
            parser: parser,
            cycleDetector: cycleDetector,
            logger: logger
        )
    }
    
    /// Build the complete relationship graph starting from root symbols with their parameters
    /// - Parameter rootSymbolsWithParams: Symbols annotated with the root macro and their parameters
    /// - Returns: The complete model graph
    func buildGraph(from rootSymbolsWithParams: [(symbol: IndexedSymbol, parameters: [String: Any])]) throws -> ModelGraph {
        var rootNodes: [ModelNode] = []
        
        for (symbol, parameters) in rootSymbolsWithParams {
            logger.info("Processing root symbol: \(symbol.name)")
            
            // Extract schema ID from parameters
            let schemaId = parameters["key"] as? String
            if let schemaId = schemaId {
                logger.debug("  Schema ID: \(schemaId)")
            }
            
            // Reset visited set for each root (they can share types)
            cycleDetector.resetVisited()
            
            if let node = try symbolProcessor.processSymbol(symbol, schemaId: schemaId, depth: 0) {
                rootNodes.append(node)
                
                // Collect property-level schema nodes from the tree and add them as roots
                let propertyLevelSchemas = collectPropertyLevelSchemas(from: node)
                if !propertyLevelSchemas.isEmpty {
                    logger.info("  Found \(propertyLevelSchemas.count) property-level schema(s) in \(symbol.name)")
                    rootNodes.append(contentsOf: propertyLevelSchemas)
                }
            }
        }
        
        return ModelGraph(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            roots: rootNodes
        )
    }
    
    /// Recursively collect all property-level schema nodes from a node tree
    private func collectPropertyLevelSchemas(from node: ModelNode) -> [ModelNode] {
        var schemas: [ModelNode] = []
        
        // Check children for property-level schemas
        for child in node.children {
            if child.sourceProperty != nil {
                schemas.append(child)
                logger.debug("    Extracted property-level schema: \(child.schemaId ?? "unknown")")
            }
            
            // Recursively collect from nested children
            schemas.append(contentsOf: collectPropertyLevelSchemas(from: child))
        }
        
        return schemas
    }
    
    /// Process a single symbol (exposed for knot processing and other advanced use cases)
    func processSymbol(
        _ symbol: IndexedSymbol,
        schemaId: String? = nil,
        depth: Int,
        isPolymorphic: Bool = false,
        polymorphicDepth: Int = 0
    ) throws -> ModelNode? {
        return try symbolProcessor.processSymbol(
            symbol,
            schemaId: schemaId,
            depth: depth,
            isPolymorphic: isPolymorphic,
            polymorphicDepth: polymorphicDepth
        )
    }
}
