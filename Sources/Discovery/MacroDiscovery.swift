import Foundation
import IndexStoreDB

/// Discovery service for finding types annotated with specific macros
class MacroDiscovery {
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
    
    // MARK: - Macro Discovery
    
    /// Find all symbols annotated with a specific macro
    /// - Parameter macroName: The macro name to search for (e.g., "RootModel")
    /// - Returns: Array of indexed symbols with the macro annotation
    func findSymbolsAnnotated(with macroName: String) throws -> [IndexedSymbol] {
        var foundSymbols: [IndexedSymbol] = []
        
        logger.debug("=== Starting macro search for: @\(macroName) ===")
        logger.debug("Source root: \(sourceRoot)")
        
        // Approach 1: Search for the macro symbol in the index
        logger.debug("Approach 1: Searching index for macro references...")
        var macroOccurrenceCount = 0
        
        indexStore.forEachCanonicalSymbolOccurrence(
            containing: macroName,
            anchorStart: true,
            anchorEnd: true,
            subsequence: false,
            ignoreCase: false
        ) { [self] occurrence in
            macroOccurrenceCount += 1
            let symbol = occurrence.symbol
            self.logger.debug("  Found occurrence: '\(symbol.name)' kind=\(symbol.kind) roles=\(occurrence.roles) at \(occurrence.location.path):\(occurrence.location.line)")
            
            // We're looking for references to the macro (where it's applied)
            if occurrence.roles.contains(.reference) {
                self.logger.debug("    -> This is a macro reference!")
                
                // Now we need to find what symbol this macro is attached to
                if let annotatedSymbol = self.symbolRepository.findSymbolNearLocation(
                    filePath: occurrence.location.path,
                    line: occurrence.location.line
                ) {
                    self.logger.debug("    -> Found annotated symbol: \(annotatedSymbol.name)")
                    foundSymbols.append(annotatedSymbol)
                }
            }
            return true // continue iteration
        }
        logger.debug("Approach 1 result: Found \(macroOccurrenceCount) occurrences, \(foundSymbols.count) symbols")
        
        // Approach 2: Search for all class/struct definitions and check their source
        if foundSymbols.isEmpty {
            logger.debug("Approach 2: Scanning all struct/class definitions in index...")
            foundSymbols = try scanIndexForMacro(macroName: macroName)
            logger.debug("Approach 2 result: Found \(foundSymbols.count) symbols")
        }
        
        // Approach 3: Direct file system scan (most reliable for macros)
        if foundSymbols.isEmpty {
            logger.debug("Approach 3: Direct file system scan for @\(macroName)...")
            foundSymbols = try scanFilesForMacro(macroName: macroName)
            logger.debug("Approach 3 result: Found \(foundSymbols.count) symbols")
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
        
        return foundSymbols
    }
    
    // MARK: - Approach 2: Scan Index for Macro
    
    /// Scan all struct/class definitions and check their source for the macro
    /// - Parameter macroName: The macro name to search for
    /// - Returns: Array of symbols found with the macro
    private func scanIndexForMacro(macroName: String) throws -> [IndexedSymbol] {
        var symbols: [IndexedSymbol] = []
        
        // Get all symbols and check their source for the macro
        indexStore.forEachCanonicalSymbolOccurrence(
            containing: "",
            anchorStart: false,
            anchorEnd: false,
            subsequence: true,
            ignoreCase: false
        ) { [self] occurrence in
            let symbol = occurrence.symbol
            
            // Only interested in struct/class/enum definitions
            guard (symbol.kind == .struct || symbol.kind == .class || symbol.kind == .enum),
                  occurrence.roles.contains(.definition) else {
                return true
            }
            
            // Check if the source file contains the macro annotation for this symbol
            let filePath = occurrence.location.path
            if self.fileContainsMacroNearSymbol(
                filePath: filePath,
                symbolName: symbol.name,
                macroName: macroName,
                nearLine: occurrence.location.line
            ) {
                symbols.append(IndexedSymbol(
                    name: symbol.name,
                    usr: symbol.usr,
                    kind: symbol.kind,
                    filePath: filePath,
                    line: occurrence.location.line,
                    column: occurrence.location.utf8Column
                ))
            }
            
            return true
        }
        
        return symbols
    }
    
    /// Quick check if a source file contains a macro annotation near a symbol
    /// - Parameters:
    ///   - filePath: Path to the source file
    ///   - symbolName: Name of the symbol to check
    ///   - macroName: Name of the macro to search for
    ///   - nearLine: Line number where the symbol is defined
    /// - Returns: True if the macro is found near the symbol
    private func fileContainsMacroNearSymbol(
        filePath: String,
        symbolName: String,
        macroName: String,
        nearLine: Int
    ) -> Bool {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return false
        }
        
        let lines = content.components(separatedBy: .newlines)
        
        // Look a few lines before the symbol definition
        let searchStart = max(0, nearLine - 5)
        let searchEnd = min(lines.count, nearLine + 1)
        
        for i in searchStart..<searchEnd {
            let line = lines[i]
            if line.contains("@\(macroName)") {
                // Also verify the symbol name is nearby
                for j in i..<min(lines.count, i + 3) {
                    if lines[j].contains(symbolName) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    // MARK: - Approach 3: Direct File Scan
    
    /// Direct file system scan for macro annotations - most reliable method
    /// This doesn't rely on IndexStoreDB indexing the macro correctly
    /// - Parameter macroName: The macro name to search for
    /// - Returns: Array of symbols found with the macro
    private func scanFilesForMacro(macroName: String) throws -> [IndexedSymbol] {
        var symbols: [IndexedSymbol] = []
        
        logger.debug("  Scanning path: \(sourceRoot)")
        
        // Collect all Swift files (handles both single files and directories)
        let swiftFiles = collectSwiftFiles(from: sourceRoot)
        
        logger.debug("  Found \(swiftFiles.count) Swift files to scan")
        logger.debug("  Pattern: @\(macroName)(...)? followed by struct/class/enum")
        
        // Regex to find @MacroName (with optional parameters) followed by struct/class declaration
        // Matches: @MacroName or @MacroName("param") or @MacroName(arg1, arg2)
        let pattern = #"@\#(macroName)(\([^)]*\))?\s*\n?\s*(public\s+|private\s+|internal\s+|fileprivate\s+|open\s+)?(struct|class|enum)\s+(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .dotMatchesLineSeparators]) else {
            logger.warning("  Failed to compile regex pattern")
            return symbols
        }
        
        var filesScanned = 0
        var totalMatches = 0
        
        for fileURL in swiftFiles {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }
            
            filesScanned += 1
            
            // Quick check: does this file even contain the macro?
            if !content.contains("@\(macroName)") {
                continue
            }
            
            logger.debug("  Scanning file with @\(macroName): \(fileURL.lastPathComponent)")
            
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            let matches = regex.matches(in: content, options: [], range: range)
            
            totalMatches += matches.count
            if matches.count > 0 {
                logger.debug("    Found \(matches.count) matches in this file")
            }
            
            for match in matches {
                logger.debug("    Processing match with \(match.numberOfRanges) groups")
                
                // Group 0: full match
                // Group 1: optional parameters like ("test")
                // Group 2: optional access modifier
                // Group 3: struct/class/enum
                // Group 4: type name
                guard match.numberOfRanges >= 5 else {
                    logger.debug("      Skipping: not enough groups (\(match.numberOfRanges))")
                    continue
                }
                
                // Try to extract struct/class/enum (group 3)
                guard let kindRange = Range(match.range(at: 3), in: content) else {
                    logger.debug("      Skipping: could not extract kind range")
                    continue
                }
                let kind = String(content[kindRange])
                logger.debug("      Found kind: \(kind)")
                
                // Try to extract type name (group 4)
                guard let nameRange = Range(match.range(at: 4), in: content) else {
                    logger.debug("      Skipping: could not extract name range")
                    continue
                }
                let typeName = String(content[nameRange])
                logger.debug("      Found name: \(typeName)")
                
                // Calculate line number
                let matchStart = match.range.location
                let prefixContent = String(content.prefix(matchStart))
                let lineNumber = prefixContent.components(separatedBy: .newlines).count
                
                logger.debug("  Found @\(macroName) \(kind) \(typeName) at \(fileURL.path):\(lineNumber)")
                
                // Try to find this symbol in the index for USR
                if let indexedSymbol = symbolRepository.findSymbol(byName: typeName) {
                    symbols.append(indexedSymbol)
                    logger.debug("    -> Matched with indexed symbol (USR: \(indexedSymbol.usr.prefix(20))...)")
                } else {
                    // Create a symbol without USR from index
                    let symbol = IndexedSymbol(
                        name: typeName,
                        usr: "file://\(fileURL.path)#\(typeName)", // Synthetic USR
                        kind: kind == "struct" ? .struct : .class,
                        filePath: fileURL.path,
                        line: lineNumber,
                        column: 1
                    )
                    symbols.append(symbol)
                    logger.debug("    -> Created synthetic symbol (not found in index)")
                }
            }
        }
        
        logger.debug("  Scanned \(filesScanned) files, found \(totalMatches) total matches, extracted \(symbols.count) symbols")
        
        return symbols
    }
    
    // MARK: - ChimeraPolymorphic Discovery
    
    /// Discover types annotated with @ChimeraPolymorphic and extract their schema IDs
    /// - Returns: Array of tuples containing (symbol, schemaId)
    func discoverChimeraPolymorphicTypes() throws -> [(symbol: IndexedSymbol, schemaId: String)] {
        logger.debug("=== Discovering @ChimeraPolymorphic types ===")
        
        // Find all symbols with @ChimeraPolymorphic annotation
        let symbols = try findSymbolsAnnotated(with: "ChimeraPolymorphic")
        
        var result: [(symbol: IndexedSymbol, schemaId: String)] = []
        
        // For each symbol, extract its schemaID parameter
        for symbol in symbols {
            if let mapping = PolymorphicParser.extractChimeraPolymorphicMapping(
                from: symbol.filePath,
                typeName: symbol.name
            ), let schemaId = mapping.schemaId {
                logger.debug("  Found @ChimeraPolymorphic type: \(symbol.name) with schemaID: \(schemaId)")
                result.append((symbol: symbol, schemaId: schemaId))
            } else {
                logger.warning("  Found @ChimeraPolymorphic on \(symbol.name) but failed to extract schemaID")
            }
        }
        
        logger.debug("=== Discovered \(result.count) @ChimeraPolymorphic types ===")
        return result
    }
    
    /// Discover types that contain property-level @ChimeraSchema annotations
    /// Scans Swift files directly to find structs/classes with properties annotated with @ChimeraSchema
    /// - Returns: Array of indexed symbols representing types containing property-level schemas
    func findTypesWithPropertyLevelSchemas() throws -> [IndexedSymbol] {
        var symbols: [IndexedSymbol] = []
        
        logger.debug("=== Discovering types with property-level @ChimeraSchema ===")
        logger.debug("  Scanning path: \(sourceRoot)")
        
        // Collect all Swift files (handles both single files and directories)
        let swiftFiles = collectSwiftFiles(from: sourceRoot)
        
        logger.debug("  Found \(swiftFiles.count) Swift files to scan")
        
        for fileURL in swiftFiles {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }
            
            // Quick check: does this file contain @ChimeraSchema inside a type body?
            if !content.contains("@ChimeraSchema") {
                continue
            }
            
            // Parse the file to find property-level @ChimeraSchema annotations
            // Use a simple regex to detect patterns like:
            // struct/class TypeName {
            //     ...
            //     @ChimeraSchema(key: "...")
            //     var property: Type
            // }
            
            // Pattern to match struct/class definitions
            let typePattern = #"(struct|class)\s+(\w+)[^{]*\{"#
            guard let typeRegex = try? NSRegularExpression(pattern: typePattern, options: []) else {
                continue
            }
            
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            let typeMatches = typeRegex.matches(in: content, options: [], range: range)
            
            for typeMatch in typeMatches {
                guard typeMatch.numberOfRanges >= 3 else { continue }
                
                guard let kindRange = Range(typeMatch.range(at: 1), in: content),
                      let nameRange = Range(typeMatch.range(at: 2), in: content) else {
                    continue
                }
                
                let kind = String(content[kindRange])
                let typeName = String(content[nameRange])
                let typeBodyStart = typeMatch.range.location + typeMatch.range.length
                
                // Find the end of the type body (matching closing brace)
                // This is simplified - doesn't handle nested braces perfectly
                guard let typeBodyEndIndex = findMatchingBrace(in: content, startOffset: typeBodyStart) else {
                    continue
                }
                
                let typeBodyStartIndex = content.index(content.startIndex, offsetBy: typeBodyStart)
                let typeBodyEndPosition = content.index(content.startIndex, offsetBy: typeBodyEndIndex)
                let typeBody = String(content[typeBodyStartIndex..<typeBodyEndPosition])
                
                // Check if there's a property-level @ChimeraSchema in this type body
                // Look for @ChimeraSchema followed by var/let declaration (not at struct/class level)
                let propertyPattern = #"@ChimeraSchema\([^)]*\)\s*\n?\s*(var|let)\s+\w+"#
                if let propertyRegex = try? NSRegularExpression(pattern: propertyPattern, options: []),
                   propertyRegex.firstMatch(in: typeBody, options: [], range: NSRange(typeBody.startIndex..<typeBody.endIndex, in: typeBody)) != nil {
                    
                    // Calculate line number
                    let prefixContent = String(content.prefix(typeMatch.range.location))
                    let lineNumber = prefixContent.components(separatedBy: .newlines).count
                    
                    logger.debug("  Found type with property-level @ChimeraSchema: \(kind) \(typeName) at \(fileURL.path):\(lineNumber)")
                    
                    // Try to find this symbol in the index
                    if let indexedSymbol = symbolRepository.findSymbol(byName: typeName) {
                        symbols.append(indexedSymbol)
                        logger.debug("    -> Matched with indexed symbol")
                    } else {
                        // Create a synthetic symbol
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
        }
        
        logger.debug("=== Found \(symbols.count) types with property-level @ChimeraSchema ===")
        return symbols
    }
    
    /// Find the matching closing brace for an opening brace
    private func findMatchingBrace(in content: String, startOffset: Int) -> Int? {
        var braceCount = 1
        var offset = startOffset
        
        while offset < content.count && braceCount > 0 {
            let index = content.index(content.startIndex, offsetBy: offset)
            let char = content[index]
            
            if char == "{" {
                braceCount += 1
            } else if char == "}" {
                braceCount -= 1
                if braceCount == 0 {
                    return offset
                }
            }
            
            offset += 1
        }
        
        return nil
    }
    
    /// Collect all Swift files from a path (handles both single files and directories)
    private func collectSwiftFiles(from path: String) -> [URL] {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)
        var swiftFiles: [URL] = []
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            logger.warning("  Path does not exist: \(path)")
            return swiftFiles
        }
        
        if isDirectory.boolValue {
            // It's a directory - enumerate all Swift files
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                logger.warning("  Could not enumerate directory: \(path)")
                return swiftFiles
            }
            
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "swift" {
                    swiftFiles.append(fileURL)
                }
            }
        } else {
            // It's a single file - check if it's a Swift file
            if url.pathExtension == "swift" {
                swiftFiles.append(url)
            } else {
                logger.warning("  Not a Swift file: \(path)")
            }
        }
        
        return swiftFiles
    }
}
