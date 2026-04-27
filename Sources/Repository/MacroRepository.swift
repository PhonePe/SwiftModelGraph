import Foundation
import IndexStoreDB
import SwiftSyntax
import SwiftParser

/// Macro usage information including location and parameters
struct MacroUsage {
    let filePath: String
    let line: Int
    let column: Int
    let parameters: [String: Any] // Parameters extracted from @Macro(key: "value", ...)
}

/// Repository for discovering macro annotations in Swift source files
/// Uses SwiftSyntax AST parsing to accurately detect @macro annotations
/// Avoids regex pitfalls: strings, comments, multi-line, nested parentheses
class MacroRepository {
    private let logger: Logger
    private weak var indexManager: IndexStoreManager?
    
    init(logger: Logger, indexManager: IndexStoreManager? = nil) throws {
        self.logger = logger
        self.indexManager = indexManager
    }
    
    /// Find all locations where a macro is used by scanning source files
    /// - Parameters:
    ///   - macroName: The macro name (e.g., "ChimeraSchema")
    ///   - sourcePath: Root path to search (can be a file or directory)
    ///   - excludedDirs: Set of directory names to exclude from scanning
    /// - Returns: Array of MacroUsage with location and parameters
    func findAllMacroUsages(macroName: String, sourcePath: String, excludedDirs: Set<String> = []) -> [MacroUsage] {
        logger.info("Searching for @\(macroName) annotations in source files...")
        logger.info("Scanning directory: \(sourcePath)")
        
        var usages: [MacroUsage] = []
        
        // Collect Swift files (handles both single files and directories)
        let swiftFiles = collectSwiftFiles(from: sourcePath, excludedDirs: excludedDirs)
        
        var filesChecked = 0
        var lastLoggedCount = 0
        
        for fileURL in swiftFiles {
            filesChecked += 1
            
            // Log progress every 100 files
            if filesChecked - lastLoggedCount >= 100 {
                logger.info("  Progress: Scanned \(filesChecked) files, found \(usages.count) @\(macroName) usages so far...")
                lastLoggedCount = filesChecked
            }
            
            let fileUsages = findMacroUsagesInFile(
                filePath: fileURL.path,
                macroName: macroName
            )
            usages.append(contentsOf: fileUsages)
        }
        
        logger.info("✓ Scanned \(filesChecked) Swift files, found \(usages.count) @\(macroName) usages total")
        return usages
    }
    
    /// Collect all Swift files from a path (handles both single files and directories)
    private func collectSwiftFiles(from path: String, excludedDirs: Set<String> = []) -> [URL] {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)
        var swiftFiles: [URL] = []
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            logger.warning("Path does not exist: \(path)")
            return swiftFiles
        }
        
        if isDirectory.boolValue {
            // It's a directory - enumerate all Swift files
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                logger.warning("Could not enumerate directory: \(path)")
                return swiftFiles
            }
            
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
        } else {
            // It's a single file - check if it's a Swift file
            if url.pathExtension == "swift" {
                swiftFiles.append(url)
            } else {
                logger.warning("Not a Swift file: \(path)")
            }
        }
        
        return swiftFiles
    }
    
    
    /// Find macro usages in a specific file using SwiftSyntax AST parsing
    /// This approach is more accurate than regex, handling:
    /// - Strings containing "@MacroName" (ignored as non-code)
    /// - Comments with "@MacroName" (ignored as non-code)
    /// - Multi-line attribute parameters
    /// - Nested parentheses in parameter expressions
    private func findMacroUsagesInFile(filePath: String, macroName: String) -> [MacroUsage] {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return []
        }
        
        // Quick pre-check: does the file even contain the macro name?
        // This speeds up scanning by skipping files that definitely don't have it
        if !content.contains("@\(macroName)") {
            return []
        }
        
        logger.debug("  Parsing (contains @\(macroName)): \(filePath.split(separator: "/").suffix(2).joined(separator: "/"))")
        
        // Parse source code into AST
        let sourceFile = Parser.parse(source: content)
        
        // Use visitor to find macro attributes (pass logger for verbose debugging)
        let visitor = MacroDiscoveryVisitor(targetMacro: macroName, filePath: filePath, logger: logger)
        visitor.walk(sourceFile)
        
        if !visitor.discoveries.isEmpty {
            logger.info("  ✓ Found \(visitor.discoveries.count) @\(macroName) usage(s) in: \(filePath.split(separator: "/").suffix(3).joined(separator: "/"))")
        } else {
            logger.debug("    (no matches after AST parsing)")
        }
        
        return visitor.discoveries
    }

    
    /// Find all knot annotations (@ChimeraMultiKnot and @ChimeraMapKnot)
    /// - Parameters:
    ///   - sourcePath: Root path to search
    ///   - excludedDirs: Set of directory names to exclude from scanning
    /// - Returns: Array of MacroUsage for knot annotations
    func findAllKnotAnnotations(sourcePath: String, excludedDirs: Set<String> = []) -> [MacroUsage] {
        let multiKnots = findAllMacroUsages(macroName: "ChimeraMultiKnot", sourcePath: sourcePath, excludedDirs: excludedDirs)
        let mapKnots = findAllMacroUsages(macroName: "ChimeraMapKnot", sourcePath: sourcePath, excludedDirs: excludedDirs)
        return multiKnots + mapKnots
    }
    
    /// Find symbols with macro using SwiftSyntax for location discovery and IndexStore for symbol resolution
    /// Phase 1: SwiftSyntax parses source files to find WHERE macros are used
    /// Phase 2: IndexStore resolves WHAT symbols they annotate (with full USR and relationships)
    /// - Parameters:
    ///   - macroName: The macro name to search for
    ///   - sourcePath: Root path to search
    /// - Returns: Array of symbols with their macro parameters
    func findSymbolsWithMacro(
        macroName: String,
        sourcePath: String
    ) throws -> [(symbol: IndexedSymbol, parameters: [String: Any])] {
        logger.info("=== Phase 1: Scanning for @\(macroName) locations ===")
        
        // Find all @macro locations using SwiftSyntax
        let usages = findAllMacroUsages(macroName: macroName, sourcePath: sourcePath)
        logger.info("Found \(usages.count) @\(macroName) annotations")
        
        return try resolveUsagesToSymbols(usages)
    }
    
    /// Resolve macro usages to symbols using IndexStore
    /// Takes already-found macro usages and resolves them to proper symbols
    /// - Parameter usages: Array of MacroUsage locations
    /// - Returns: Array of symbols with their macro parameters
    func resolveUsagesToSymbols(_ usages: [MacroUsage]) throws -> [(symbol: IndexedSymbol, parameters: [String: Any])] {
        var foundSymbols: [(IndexedSymbol, [String: Any])] = []
        
        if !usages.isEmpty, let indexManager = indexManager {
            logger.info("=== Resolving \\(usages.count) macro annotations to symbols ===")
            
            for usage in usages {
                logger.debug("Processing @macro at \\(usage.filePath):\\(usage.line):\\(usage.column)")
                
                // Log parameters if present
                if !usage.parameters.isEmpty {
                    logger.debug("  Parameters: \\(usage.parameters)")
                }
                
                // Use IndexStore to find the symbol this macro annotates
                if let symbol = findSymbolAnnotatedByMacro(atFile: usage.filePath, line: usage.line, using: indexManager) {
                    foundSymbols.append((symbol, usage.parameters))
                    logger.info("  ✓ Resolved: \\(symbol.kind) \\(symbol.name)")
                } else {
                    logger.warning("  ✗ Could not resolve symbol")
                }
            }
            
            logger.info("Resolved \\(foundSymbols.count) of \\(usages.count) annotations")
        }
        
        // Fallback to full IndexStore scan if nothing found
        if foundSymbols.isEmpty, let indexManager = indexManager {
            logger.info("=== Falling back to IndexStore-only scan ===")
            let symbols = try indexManager.findSymbolsWithMacro(macroName: "todo")
            foundSymbols = symbols.map { ($0, [:]) } // No parameters in fallback
        }
        
        // Remove duplicates
        var seenUSRs = Set<String>()
        return foundSymbols.filter { (symbol, _) in
            guard !seenUSRs.contains(symbol.usr) else { return false }
            seenUSRs.insert(symbol.usr)
            return true
        }
    }
    
    // MARK: - Private Symbol Resolution Helpers
    
    /// Find the symbol annotated by a macro at a specific location
    /// Uses IndexStore to get proper USR and symbol information
    private func findSymbolAnnotatedByMacro(atFile filePath: String, line: Int, using indexManager: IndexStoreManager) -> IndexedSymbol? {
        // Strategy 1: Query IndexStore for symbols in this file near this line
        var bestMatch: IndexedSymbol?
        var bestDistance = Int.max
        
        indexManager.indexStore.forEachCanonicalSymbolOccurrence(
            containing: "",
            anchorStart: false,
            anchorEnd: false,
            subsequence: true,
            ignoreCase: false
        ) { occurrence in
            // Only look at struct/class/enum definitions in the same file
            guard occurrence.location.path == filePath,
                  occurrence.roles.contains(.definition),
                  (occurrence.symbol.kind == .struct ||
                   occurrence.symbol.kind == .class ||
                   occurrence.symbol.kind == .enum) else {
                return true
            }
            
            // Type should be defined within a few lines after the macro
            let distance = occurrence.location.line - line
            if distance >= 0 && distance < bestDistance && distance <= 5 {
                bestDistance = distance
                bestMatch = IndexedSymbol(
                    name: occurrence.symbol.name,
                    usr: occurrence.symbol.usr,
                    kind: occurrence.symbol.kind,
                    filePath: occurrence.location.path,
                    line: occurrence.location.line,
                    column: occurrence.location.utf8Column
                )
            }
            
            return true
        }
        
        if let match = bestMatch {
            logger.debug("    IndexStore found: \(match.kind) \(match.name) at line \(match.line)")
            return match
        }
        
        // Strategy 2: Parse file if IndexStore doesn't have the symbol
        logger.debug("    Parsing file directly...")
        return parseFileForSymbol(at: filePath, afterLine: line, using: indexManager)
    }
    
    /// Parse file to find type declaration after a specific line
    private func parseFileForSymbol(at filePath: String, afterLine: Int, using indexManager: IndexStoreManager) -> IndexedSymbol? {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return nil
        }
        
        let lines = content.components(separatedBy: .newlines)
        guard afterLine > 0 && afterLine <= lines.count else {
            return nil
        }
        
        // Search next few lines for type declaration
        for i in (afterLine - 1)..<min(afterLine + 5, lines.count) {
            let line = lines[i]
            
            let pattern = #"(?:public\s+|private\s+|internal\s+|fileprivate\s+|open\s+)?(struct|class|enum)\s+(\w+)"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)),
                  match.numberOfRanges >= 3,
                  let kindRange = Range(match.range(at: 1), in: line),
                  let nameRange = Range(match.range(at: 2), in: line) else {
                continue
            }
            
            let kindStr = String(line[kindRange])
            let name = String(line[nameRange])
            
            let kind: IndexSymbolKind
            switch kindStr {
            case "struct": kind = .struct
            case "class": kind = .class
            case "enum": kind = .enum
            default: continue
            }
            
            logger.debug("    Parsed: \(kind) \(name) at line \(i + 1)")
            
            // Try to get USR from IndexStore using the name AND file path
            // This ensures we get the right symbol if there are multiple with the same name
            if let indexed = indexManager.findSymbolByName(name, inFile: filePath) {
                logger.debug("    Matched with IndexStore symbol in same file")
                return indexed
            }
            
            logger.debug("    Creating synthetic symbol (not in IndexStore)")
            // Create synthetic symbol
            return IndexedSymbol(
                name: name,
                usr: "file://\(filePath)#\(name)",
                kind: kind,
                filePath: filePath,
                line: i + 1,
                column: 1
            )
        }
        
        return nil
    }
}