import Foundation
import IndexStoreDB

/// Represents a symbol found in the index with its location
struct IndexedSymbol {
    let name: String
    let usr: String  // Unified Symbol Resolution - unique identifier
    let kind: IndexSymbolKind
    let filePath: String
    let line: Int
    let column: Int
    
    var locationDescription: String {
        return "\(filePath):\(line):\(column)"
    }
}

/// Facade for IndexStoreDB operations
/// Delegates to specialized repositories and discovery services
class IndexStoreManager {
    let indexStore: IndexStoreDB
    private let sourceRoot: String
    let logger: Logger
    
    // Repository layer
    let symbolRepository: SymbolRepository
    private let inheritanceRepository: InheritanceRepository
    
    //Discovery layer
    private let protocolDiscovery: ProtocolDiscovery
    private let macroDiscovery: MacroDiscovery
    
    /// Initialize IndexStoreDB with the given paths
    /// - Parameters:
    ///   - indexStorePath: Path to Index.noindex/DataStore
    ///   - sourceRoot: Root path for source files
    ///   - logger: Logger instance
    init(indexStorePath: String, sourceRoot: String, logger: Logger) throws {
        // Convert relative path to absolute path
        let absoluteSourceRoot: String
        if sourceRoot.hasPrefix("/") {
            absoluteSourceRoot = sourceRoot
        } else {
            let currentDir = FileManager.default.currentDirectoryPath
            let url = URL(fileURLWithPath: sourceRoot, relativeTo: URL(fileURLWithPath: currentDir))
            absoluteSourceRoot = url.standardizedFileURL.path
        }
        
        self.sourceRoot = absoluteSourceRoot
        self.logger = logger
        
        logger.debug("Initializing IndexStoreManager...")
        logger.debug("  Index store path: \(indexStorePath)")
        logger.debug("  Source root (relative): \(sourceRoot)")
        logger.debug("  Source root (absolute): \(absoluteSourceRoot)")
        
        // Verify index store path exists
        let indexStoreExists = FileManager.default.fileExists(atPath: indexStorePath)
        logger.debug("  Index store exists: \(indexStoreExists)")
        if !indexStoreExists {
            logger.warning("Index store path does not exist: \(indexStorePath)")
        }
        
        let databasePath = NSTemporaryDirectory() + "model-graph-db-\(UUID().uuidString)"
        logger.debug("  Database path (temp): \(databasePath)")
        
        // Find the indexstore library path
        let libIndexStorePath = try Self.findIndexStoreLibrary()
        logger.debug("  IndexStore library: \(libIndexStorePath)")
        
        guard let library = try? IndexStoreLibrary(dylibPath: libIndexStorePath) else {
            logger.error("Failed to load IndexStoreLibrary from: \(libIndexStorePath)")
            throw GraphGeneratorError.failedToOpenIndex(
                "Could not load indexstore library at: \(libIndexStorePath)"
            )
        }
        logger.debug("  IndexStoreLibrary loaded successfully")
        
        do {
            logger.debug("Creating IndexStoreDB instance...")
            self.indexStore = try IndexStoreDB(
                storePath: indexStorePath,
                databasePath: databasePath,
                library: library,
                waitUntilDoneInitializing: true,
                listenToUnitEvents: false
            )
            logger.info("IndexStoreDB initialized successfully")
            logger.debug("  Ready to query index database")
        } catch {
            logger.error("IndexStoreDB initialization failed: \(error)")
            logger.error("  Store path: \(indexStorePath)")
            logger.error("  Database path: \(databasePath)")
            throw GraphGeneratorError.failedToOpenIndex(
                "Failed to initialize IndexStoreDB: \(error.localizedDescription)"
            )
        }
        
        // Initialize repositories
        self.symbolRepository = SymbolRepository(indexStore: indexStore, logger: logger)
        self.inheritanceRepository = InheritanceRepository(
            indexStore: indexStore,
            symbolRepository: symbolRepository,
            logger: logger
        )
        
        // Initialize discovery services
        self.protocolDiscovery = ProtocolDiscovery(
            indexStore: indexStore,
            symbolRepository: symbolRepository,
            sourceRoot: absoluteSourceRoot,
            logger: logger
        )
        self.macroDiscovery = MacroDiscovery(
            indexStore: indexStore,
            symbolRepository: symbolRepository,
            sourceRoot: absoluteSourceRoot,
            logger: logger
        )
    }
    
    /// Find the indexstore library in Xcode toolchain
    private static func findIndexStoreLibrary() throws -> String {
        // Try common locations for libIndexStore.dylib
        let possiblePaths = [
            "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib",
            "/Applications/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib",
            "/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/lib/libIndexStore.dylib"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Try to find via xcode-select
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try? process.run()
        process.waitUntilExit()
        
        if let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) {
            let derivedPath = output + "/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib"
            if FileManager.default.fileExists(atPath: derivedPath) {
                return derivedPath
            }
        }
        
        throw GraphGeneratorError.failedToOpenIndex(
            "Could not find libIndexStore.dylib. Make sure Xcode is installed."
        )
    }
    
    // MARK: - Protocol Discovery (Delegates to ProtocolDiscovery)
    
    /// Find all symbols that conform to a specific protocol
    func findSymbolsConformingToProtocol(protocolName: String, excludedDirs: Set<String> = []) throws -> [IndexedSymbol] {
        try protocolDiscovery.findSymbolsConforming(to: protocolName, excludedDirs: excludedDirs)
    }
    
    /// Find all types that conform to a given protocol
    func findTypesConforming(to protocolName: String) -> [IndexedSymbol] {
        inheritanceRepository.findTypesConforming(to: protocolName)
    }
    
    /// Find all protocol conformances for a type
    func findProtocolConformances(of typeName: String, inFile filePath: String? = nil) -> [String] {
        inheritanceRepository.findProtocolConformances(of: typeName, inFile: filePath)
    }
    
    // MARK: - Macro Discovery (Delegates to MacroDiscovery)
    
    /// Find all symbols annotated with a specific macro
    func findSymbolsWithMacro(macroName: String) throws -> [IndexedSymbol] {
        try macroDiscovery.findSymbolsAnnotated(with: macroName)
    }
    
    // MARK: - Symbol Lookup (Delegates to SymbolRepository)
    
    /// Find a symbol by name
    func findSymbolByName(_ name: String, inFile filePath: String? = nil) -> IndexedSymbol? {
        symbolRepository.findSymbol(byName: name, inFile: filePath)
    }
    
    /// Find a symbol by USR
    func findSymbolByUSR(_ usr: String) -> IndexedSymbol? {
        symbolRepository.findSymbol(byUSR: usr)
    }
    
    /// Find a symbol near a specific location
    func findSymbolNearLocation(filePath: String, line: Int) -> IndexedSymbol? {
        symbolRepository.findSymbolNearLocation(filePath: filePath, line: line)
    }
    
    // MARK: - Inheritance (Delegates to InheritanceRepository)
    
    /// Find the parent class of a type
    func findParentClass(of typeName: String, inFile filePath: String? = nil) -> IndexedSymbol? {
        inheritanceRepository.findParentClass(of: typeName, inFile: filePath)
    }
    
    /// Get the full inheritance chain for a type
    func getInheritanceChain(of typeName: String, inFile filePath: String? = nil) -> [IndexedSymbol] {
        inheritanceRepository.getInheritanceChain(of: typeName, inFile: filePath)
    }
    
    // MARK: - Knot Annotations (Mixed - uses MacroRepository & SymbolRepository)
    
    /// Find symbols with knot annotations
    func findSymbolsWithKnotAnnotations(sourcePath: String, excludedDirs: Set<String> = []) -> [(symbol: IndexedSymbol, knotInfo: KnotInfo)] {
        var results: [(symbol: IndexedSymbol, knotInfo: KnotInfo)] = []
        
        // Use MacroRepository to find knot annotation locations
        let macroRepository = try? MacroRepository(logger: logger, indexManager: self)
        guard let manager = macroRepository else {
            logger.warning("Could not initialize MacroRepository")
            return results
        }
        
        let knotUsages = manager.findAllKnotAnnotations(sourcePath: sourcePath, excludedDirs: excludedDirs)
        logger.info("Found \(knotUsages.count) knot annotations")
        
        for usage in knotUsages {
            logger.debug("Processing knot at \(usage.filePath):\(usage.line)")
            
            // Parse the file directly to find the type name
            guard let sourceCode = try? String(contentsOfFile: usage.filePath, encoding: .utf8) else {
                continue
            }
            
            let lines = sourceCode.components(separatedBy: CharacterSet.newlines)
            guard usage.line > 0 && usage.line <= lines.count else {
                continue
            }
            
            // Parse the type name from lines after the annotation
            // Search up to 10 lines to handle multiline annotations
            var typeName: String?
            for i in (usage.line - 1)..<min(usage.line + 10, lines.count) {
                let line = lines[i]
                // Look for struct/class declaration
                let typePattern = #"(struct|class|enum)\s+(\w+)"#
                if let regex = try? NSRegularExpression(pattern: typePattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)),
                   let nameRange = Range(match.range(at: 2), in: line) {
                    typeName = String(line[nameRange])
                    break
                }
            }
            
            guard let name = typeName else {
                logger.warning("  Could not find type name after knot annotation")
                continue
            }
            
            logger.debug("    Parsed: \(name) at line \(usage.line)")
            
            // Extract knot info using KnotParser
            if let knotInfo = KnotParser.extractKnotAnnotation(from: usage.filePath, typeName: name) {
                logger.debug("    ✓ Resolved knot: schemaId=\(knotInfo.schemaId), type=\(knotInfo.knotType.rawValue), subSchemas=\(knotInfo.subSchemas.joined(separator: ", "))")
                
                // Try to find this symbol in the index
                var symbol = symbolRepository.findSymbol(byName: name, inFile: usage.filePath)
                if symbol == nil {
                    symbol = symbolRepository.findSymbol(byName: name)
                }
                
                if let symbol = symbol {
                    results.append((symbol: symbol, knotInfo: knotInfo))
                } else {
                    // Create synthetic symbol
                    let syntheticSymbol = IndexedSymbol(
                        name: name,
                        usr: "file://\(usage.filePath)#\(name)",
                        kind: .struct,
                        filePath: usage.filePath,
                        line: usage.line,
                        column: 1
                    )
                    results.append((symbol: syntheticSymbol, knotInfo: knotInfo))
                }
            }
        }
        
        return results
    }
    
    // MARK: - Helper Methods
    
    /// Check if a type name is a known Swift primitive or Foundation type
    static func isPrimitiveType(_ typeName: String) -> Bool {
        TypeUtilities.isPrimitiveType(typeName)
    }
}
