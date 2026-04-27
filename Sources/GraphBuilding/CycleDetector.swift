import Foundation

/// Manages cycle detection and node caching during graph traversal
class CycleDetector {
    /// Set of USRs that have been visited in the current traversal path
    /// Prevents infinite loops from circular dependencies
    private var visitedUSRs: Set<String> = []
    
    /// Cache of already-processed nodes to avoid re-parsing
    private var nodeCache: [String: ModelNode] = [:]
    
    /// Check if a symbol has been visited in the current traversal path
    /// - Parameter usr: The USR (Unified Symbol Resolution) of the symbol
    /// - Returns: True if the symbol has been visited
    func isVisited(_ usr: String) -> Bool {
        return visitedUSRs.contains(usr)
    }
    
    /// Check if a node is cached
    /// - Parameter usr: The USR of the symbol
    /// - Returns: The cached node if available
    func getCachedNode(for usr: String) -> ModelNode? {
        return nodeCache[usr]
    }
    
    /// Mark a symbol as visited
    /// - Parameter usr: The USR of the symbol
    func markVisited(_ usr: String) {
        visitedUSRs.insert(usr)
    }
    
    /// Cache a processed node
    /// - Parameters:
    ///   - node: The node to cache
    ///   - usr: The USR of the symbol
    func cacheNode(_ node: ModelNode, for usr: String) {
        nodeCache[usr] = node
    }
    
    /// Reset the visited symbols set (typically called between processing different roots)
    func resetVisited() {
        visitedUSRs.removeAll()
    }
    
    /// Clear all caches (visited and node cache)
    func clearAll() {
        visitedUSRs.removeAll()
        nodeCache.removeAll()
    }
    
    /// Create a cyclic node placeholder
    /// - Parameters:
    ///   - symbol: The symbol that caused the cycle
    ///   - schemaId: Optional schema ID
    ///   - isPolymorphic: Whether this is a polymorphic variant
    /// - Returns: A ModelNode marked as cyclic
    func createCyclicNode(
        for symbol: IndexedSymbol,
        schemaId: String?,
        isPolymorphic: Bool
    ) -> ModelNode {
        let kindString: String
        switch symbol.kind {
        case .struct:
            kindString = "struct"
        case .class:
            kindString = "class"
        case .enum:
            kindString = "enum"
        default:
            kindString = "unknown"
        }
        
        return ModelNode(
            name: symbol.name,
            kind: kindString,
            filePath: symbol.filePath,
            line: symbol.line,
            schemaId: schemaId,
            properties: [],
            children: [],
            isCyclic: true,
            isPolymorphic: isPolymorphic
        )
    }
    
    /// Create a cyclic node from a cached node
    /// - Parameters:
    ///   - cachedNode: The cached node to mark as cyclic
    ///   - schemaId: Optional schema ID to override (for when cached node is also a root)
    /// - Returns: A copy of the cached node marked as cyclic with cleared children
    func createCyclicNodeFromCache(_ cachedNode: ModelNode, schemaId: String? = nil) -> ModelNode {
        var cyclicNode = cachedNode
        cyclicNode.isCyclic = true
        cyclicNode.children = []  // Clear children to avoid duplication
        // Override schemaId if provided (e.g., when this cached node is also a root)
        if let schemaId = schemaId {
            cyclicNode.schemaId = schemaId
        }
        return cyclicNode
    }
}
