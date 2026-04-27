import Foundation
import IndexStoreDB

/// Discovery service for finding types that conform to specific protocols
class ProtocolDiscovery {
    private let indexStore: IndexStoreDB
    private let symbolRepository: SymbolRepository
    private let sourceRoot: String
    private let logger: Logger
    
    init(indexStore: IndexStoreDB, symbolRepository: SymbolRepository, sourceRoot: String, logger: Logger) {
        self.indexStore = indexStore
        self.symbolRepository = symbolRepository
        self.sourceRoot = sourceRoot
        self.logger = logger
    }
    
    // MARK: - Protocol Discovery
    
    /// Find all symbols that conform to a specific protocol
    /// - Parameters:
    ///   - protocolName: The protocol name to search for (e.g., "RootModel")
    ///   - excludedDirs: Set of directory names to exclude from file scanning
    /// - Returns: Array of indexed symbols that conform to the protocol
    func findSymbolsConforming(to protocolName: String, excludedDirs: Set<String> = []) throws -> [IndexedSymbol] {
        guard !protocolName.isEmpty else {
            return []
        }
        
        var foundSymbols: [IndexedSymbol] = []
        
        logger.debug("=== Starting protocol conformance search for: \(protocolName) ===")
        logger.debug("Source root: \(sourceRoot)")
        
        // Step 1: Find the protocol's USR
        logger.debug("Step 1: Finding protocol USR...")
        var protocolUSR: String?
        
        indexStore.forEachCanonicalSymbolOccurrence(
            containing: protocolName,
            anchorStart: true,
            anchorEnd: true,
            subsequence: false,
            ignoreCase: false
        ) { occurrence in
            let symbol = occurrence.symbol
            if symbol.kind == .protocol && symbol.name == protocolName {
                protocolUSR = symbol.usr
                self.logger.debug("  Found protocol: \(symbol.name) USR=\(symbol.usr)")
                return false // stop iteration
            }
            return true
        }
        
        // Step 2: Find all types that reference this protocol (conformance)
        if let usr = protocolUSR {
            logger.debug("Step 2: Finding types conforming to protocol (USR: \(usr.prefix(30))...)")
            
            indexStore.forEachSymbolOccurrence(byUSR: usr, roles: .baseOf) { occurrence in
                // .baseOf role means this protocol is a base of another type
                self.logger.debug("  Found conformance reference at: \(occurrence.location.path):\(occurrence.location.line)")
                
                // Find the type that conforms at this location
                if let conformingType = self.symbolRepository.findTypeAtLocation(
                    filePath: occurrence.location.path,
                    line: occurrence.location.line
                ) {
                    self.logger.debug("    -> Conforming type: \(conformingType.name)")
                    foundSymbols.append(conformingType)
                }
                return true
            }
            logger.debug("Step 2 result: Found \(foundSymbols.count) conforming types via index")
        } else {
            logger.debug("  Protocol '\(protocolName)' not found in index")
        }
        
        // Step 3: Fallback - direct file scan for protocol conformance
        if foundSymbols.isEmpty {
            logger.debug("Step 3: Direct file scan for protocol conformance...")
            foundSymbols = try scanFilesForProtocolConformance(protocolName: protocolName, excludedDirs: excludedDirs)
            logger.debug("Step 3 result: Found \(foundSymbols.count) symbols")
        }
        
        // Remove duplicates based on USR
        var seenUSRs = Set<String>()
        foundSymbols = foundSymbols.filter { symbol in
            if seenUSRs.contains(symbol.usr) {
                return false
            }
            seenUSRs.insert(symbol.usr)
            return true
        }
        
        logger.debug("=== Total unique symbols found: \(foundSymbols.count) ===")
        return foundSymbols
    }
    
    // MARK: - File System Scanning (Fallback)
    
    /// Direct file system scan for protocol conformance
    /// - Parameters:
    ///   - protocolName: The protocol name to search for
    ///   - excludedDirs: Set of directory names to exclude from scanning
    /// - Returns: Array of symbols found via file scanning
    private func scanFilesForProtocolConformance(protocolName: String, excludedDirs: Set<String> = []) throws -> [IndexedSymbol] {
        var symbols: [IndexedSymbol] = []
        let fileManager = FileManager.default
        
        logger.debug("  Scanning directory: \(sourceRoot)")
        
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: sourceRoot),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            logger.warning("  Could not enumerate directory: \(sourceRoot)")
            return symbols
        }
        
        var swiftFiles: [URL] = []
        for case let fileURL as URL in enumerator {
            // Skip excluded directories
            if !excludedDirs.isEmpty {
                let pathComponents = fileURL.pathComponents
                if pathComponents.contains(where: { excludedDirs.contains($0) }) {
                    continue
                }
            }
            if fileURL.pathExtension == "swift" {
                swiftFiles.append(fileURL)
            }
        }
        
        logger.debug("  Found \(swiftFiles.count) Swift files to scan")
        
        // Regex to find struct/class that conforms to the protocol
        // Matches: struct/class Name: Protocol or struct/class Name: OtherProtocol, Protocol
        let pattern = #"(struct|class)\s+(\w+)\s*:\s*[^{]*\b\#(protocolName)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            logger.warning("  Failed to compile regex pattern")
            return symbols
        }
        
        for fileURL in swiftFiles {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }
            
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            let matches = regex.matches(in: content, options: [], range: range)
            
            for match in matches {
                guard match.numberOfRanges >= 3,
                      let kindRange = Range(match.range(at: 1), in: content),
                      let nameRange = Range(match.range(at: 2), in: content) else {
                    continue
                }
                
                let kind = String(content[kindRange])
                let typeName = String(content[nameRange])
                
                // Calculate line number
                let matchStart = match.range.location
                let prefixContent = String(content.prefix(matchStart))
                let lineNumber = prefixContent.components(separatedBy: .newlines).count
                
                logger.debug("  Found \(kind) \(typeName): \(protocolName) at \(fileURL.path):\(lineNumber)")
                
                // Try to find this symbol in the index for USR
                if let indexedSymbol = symbolRepository.findSymbol(byName: typeName) {
                    symbols.append(indexedSymbol)
                    logger.debug("    -> Matched with indexed symbol")
                } else {
                    let symbol = IndexedSymbol(
                        name: typeName,
                        usr: "file://\(fileURL.path)#\(typeName)",
                        kind: kind == "struct" ? .struct : .class,
                        filePath: fileURL.path,
                        line: lineNumber,
                        column: 1
                    )
                    symbols.append(symbol)
                    logger.debug("    -> Created synthetic symbol")
                }
            }
        }
        
        return symbols
    }
}
