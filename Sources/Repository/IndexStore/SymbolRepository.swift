import Foundation
import IndexStoreDB

/// Repository for basic symbol lookup operations in IndexStoreDB
class SymbolRepository {
    private let indexStore: IndexStoreDB
    private let logger: Logger
    
    init(indexStore: IndexStoreDB, logger: Logger) {
        self.indexStore = indexStore
        self.logger = logger
    }
    
    // MARK: - Basic Symbol Queries
    
    /// Find a symbol by name and return its indexed information
    /// - Parameters:
    ///   - name: The symbol name to search for
    ///   - inFile: Optional file path to restrict search to specific file
    /// - Returns: IndexedSymbol if found, nil otherwise
    func findSymbol(byName name: String, inFile filePath: String? = nil) -> IndexedSymbol? {
        var result: IndexedSymbol?
        
        indexStore.forEachCanonicalSymbolOccurrence(
            containing: name,
            anchorStart: true,
            anchorEnd: true,
            subsequence: false,
            ignoreCase: false
        ) { occurrence in
            let symbol = occurrence.symbol
            
            // Must match name and be a type definition
            guard symbol.name == name,
                  (symbol.kind == .struct || symbol.kind == .class || symbol.kind == .enum),
                  occurrence.roles.contains(.definition) else {
                return true
            }
            
            // If file path specified, must match exactly
            if let filePath = filePath {
                if occurrence.location.path == filePath {
                    result = IndexedSymbol(
                        name: symbol.name,
                        usr: symbol.usr,
                        kind: symbol.kind,
                        filePath: occurrence.location.path,
                        line: occurrence.location.line,
                        column: occurrence.location.utf8Column
                    )
                    return false // Found exact match in specified file
                }
                return true // Continue searching in other files
            }
            
            // No file filter - take first definition
            if result == nil {
                result = IndexedSymbol(
                    name: symbol.name,
                    usr: symbol.usr,
                    kind: symbol.kind,
                    filePath: occurrence.location.path,
                    line: occurrence.location.line,
                    column: occurrence.location.utf8Column
                )
            }
            
            return true
        }
        
        return result
    }
    
    /// Find a symbol by its USR (Unified Symbol Resolution identifier)
    /// - Parameter usr: The USR of the symbol
    /// - Returns: IndexedSymbol if found, nil otherwise
    func findSymbol(byUSR usr: String) -> IndexedSymbol? {
        var result: IndexedSymbol?
        
        indexStore.forEachSymbolOccurrence(byUSR: usr, roles: .definition) { occurrence in
            let symbol = occurrence.symbol
            result = IndexedSymbol(
                name: symbol.name,
                usr: symbol.usr,
                kind: symbol.kind,
                filePath: occurrence.location.path,
                line: occurrence.location.line,
                column: occurrence.location.utf8Column
            )
            return false // stop after first definition
        }
        
        return result
    }
    
    /// Find a symbol near the given location by searching all symbols in the same file
    /// Useful for finding types adjacent to macro annotations
    /// - Parameters:
    ///   - filePath: The file path to search in
    ///   - line: The line number to search near
    /// - Returns: The closest IndexedSymbol within 3 lines, or nil if none found
    func findSymbolNearLocation(filePath: String, line: Int) -> IndexedSymbol? {
        var result: IndexedSymbol?
        var bestDistance = Int.max
        
        // Search for all struct/class definitions and find the closest one to our line
        indexStore.forEachCanonicalSymbolOccurrence(
            containing: "",
            anchorStart: false,
            anchorEnd: false,
            subsequence: true,
            ignoreCase: false
        ) { occurrence in
            let symbol = occurrence.symbol
            
            // We want struct, class, or enum definitions in the same file
            guard (symbol.kind == .struct || symbol.kind == .class || symbol.kind == .enum),
                  occurrence.roles.contains(.definition),
                  occurrence.location.path == filePath else {
                return true
            }
            
            // Find the symbol closest to (but after) the macro line
            let distance = occurrence.location.line - line
            if distance >= 0 && distance < bestDistance && distance <= 3 {
                bestDistance = distance
                result = IndexedSymbol(
                    name: symbol.name,
                    usr: symbol.usr,
                    kind: symbol.kind,
                    filePath: occurrence.location.path,
                    line: occurrence.location.line,
                    column: occurrence.location.utf8Column
                )
            }
            
            return true // continue
        }
        
        return result
    }
    
    /// Find a type definition at or near the given location
    /// - Parameters:
    ///   - filePath: The file path containing the type
    ///   - line: The line number where the type is defined
    /// - Returns: IndexedSymbol if found, nil otherwise
    func findTypeAtLocation(filePath: String, line: Int) -> IndexedSymbol? {
        var result: IndexedSymbol?
        var bestDistance = Int.max
        
        // Try IndexStore first
        indexStore.forEachCanonicalSymbolOccurrence(
            containing: "",
            anchorStart: false,
            anchorEnd: false,
            subsequence: true,
            ignoreCase: false
        ) { occurrence in
            guard occurrence.location.path == filePath else {
                return true
            }
            
            let symbol = occurrence.symbol
            if (symbol.kind == .struct || symbol.kind == .class),
               occurrence.roles.contains(.definition) {
                let distance = abs(occurrence.location.line - line)
                if distance < bestDistance {
                    bestDistance = distance
                    result = IndexedSymbol(
                        name: symbol.name,
                        usr: symbol.usr,
                        kind: symbol.kind,
                        filePath: occurrence.location.path,
                        line: occurrence.location.line,
                        column: occurrence.location.utf8Column
                    )
                }
            }
            return true
        }
        
        // Fallback: read the file and extract struct/class name, then look it up in the index
        if result == nil {
            if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines)
                let searchStart = max(0, line - 2)
                let searchEnd = min(lines.count, line + 3)
                
                for i in searchStart..<searchEnd{
                    let currentLine = lines[i]
                    if let typeName = extractTypeNameFromDeclaration(currentLine) {
                        if let indexed = findSymbol(byName: typeName) {
                            result = indexed
                            logger.debug("    → Found via fallback: \(typeName)")
                            break
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    // MARK: - Helper Methods
    
    /// Extract type name from a struct/class declaration line
    /// - Parameter line: A line of Swift code
    /// - Returns: The type name if found, nil otherwise
    private func extractTypeNameFromDeclaration(_ line: String) -> String? {
        let pattern = #"(struct|class)\s+(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        if let match = regex.firstMatch(in: line, range: range),
           match.numberOfRanges >= 3,
           let nameRange = Range(match.range(at: 2), in: line) {
            return String(line[nameRange])
        }
        return nil
    }
}
