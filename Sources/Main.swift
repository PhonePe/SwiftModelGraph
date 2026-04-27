import ArgumentParser
import Foundation

@main
struct ModelGraphGenerator: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "model-graph",
        abstract: "Generates a parent-child relationship graph from Swift models marked as root models",
        version: "1.0.0"
    )
    
    @Option(name: .shortAndLong, help: "Path to the DerivedData folder or IndexStore location")
    var indexPath: String?
    
    @Option(name: .shortAndLong, help: "Path to the source files directory")
    var sourcePath: String
    
    @Option(name: .shortAndLong, help: "Name of the protocol or macro to search for (default: ChimeraSchema)")
    var markerName: String = "ChimeraSchema"
    
    @Flag(name: .long, help: "Use macro-based detection (@RootModel) instead of protocol conformance")
    var useMacro: Bool = false
    
    @Option(name: .shortAndLong, help: "Output file path for JSON (default: stdout)")
    var output: String?
    
    @Flag(name: .shortAndLong, help: "Enable verbose logging")
    var verbose: Bool = false
    
    @Flag(name: .long, help: "Output in JSON Schema format (https://json-schema.org/)")
    var jsonSchema: Bool = false
    
    @Option(name: .long, parsing: .upToNextOption, help: "Folder names to exclude from scanning (e.g. --exclude-dirs Pods DerivedData)")
    var excludeDirs: [String] = []
    
    mutating func run() throws {
        let logger = Logger(verbose: verbose)
        
        // Determine index store path
        let indexStorePath: String
        if let providedPath = indexPath {
            indexStorePath = providedPath
        } else {
            // Try to find default Xcode DerivedData location
            indexStorePath = try findDefaultIndexStore(logger: logger)
        }
        
        logger.info("Scanning source files at: \(sourcePath)")
        
        if useMacro {
            logger.info("Looking for macro: @\(markerName)")
        } else {
            logger.info("Looking for protocol conformance: \(markerName)")
        }
        
        let rootSymbolsWithParams: [(symbol: IndexedSymbol, parameters: [String: Any])]
        let indexManager: IndexStoreManager
        
        let excludedDirSet = Set(excludeDirs)
        if !excludedDirSet.isEmpty {
            logger.info("Excluding directories: \(excludeDirs.joined(separator: ", "))")
        }
        
        if useMacro {
            // Phase 1: Fast SwiftSyntax scan (no IndexStore needed yet)
            logger.info("=== Phase 1: Fast file scan with SwiftSyntax ===")
            let quickMacroRepository = try MacroRepository(logger: logger, indexManager: nil)
            let usages = quickMacroRepository.findAllMacroUsages(macroName: markerName, sourcePath: sourcePath, excludedDirs: excludedDirSet)
            
            if usages.isEmpty {
                logger.warning("No @\(markerName) annotations found in source files")
                print("{\"roots\": []}")
                return
            }
            
            logger.info("Found \(usages.count) @\(markerName) annotation(s)")
            
            // Phase 2: Initialize IndexStore to resolve symbols
            logger.info("=== Phase 2: Initialize IndexStore for symbol resolution ===")
            logger.info("Using index store at: \(indexStorePath)")
            
            indexManager = try IndexStoreManager(
                indexStorePath: indexStorePath,
                sourceRoot: sourcePath,
                logger: logger
            )
            
            // Resolve the usages we already found
            let macroRepositoryWithIndex = try MacroRepository(logger: logger, indexManager: indexManager)
            rootSymbolsWithParams = try macroRepositoryWithIndex.resolveUsagesToSymbols(usages)
            logger.info("Resolved \(rootSymbolsWithParams.count) symbols annotated with @\(markerName)")
        } else {
            // Protocol conformance requires IndexStore from the start
            logger.info("Using index store at: \(indexStorePath)")
            indexManager = try IndexStoreManager(
                indexStorePath: indexStorePath,
                sourceRoot: sourcePath,
                logger: logger
            )
            
            let rootSymbols = try indexManager.findSymbolsConformingToProtocol(protocolName: markerName, excludedDirs: excludedDirSet)
            rootSymbolsWithParams = rootSymbols.map { (symbol: $0, parameters: [:] as [String: Any]) }
            logger.info("Found \(rootSymbolsWithParams.count) symbols conforming to \(markerName)")
        }
        
        if rootSymbolsWithParams.isEmpty {
            if useMacro {
                logger.warning("No symbols found with @\(markerName) annotation")
            } else {
                logger.warning("No symbols found conforming to \(markerName) protocol")
            }
            print("{\"roots\": []}")
            return
        }
        
        // Phase 2 & 3: Build the relationship graph
        let graphBuilder = GraphBuilder(
            indexManager: indexManager,
            sourceRoot: sourcePath,
            logger: logger
        )
        
        // Phase 3.5: Discover and add @ChimeraPolymorphic types to root symbols
        var allRootSymbolsWithParams = rootSymbolsWithParams
        if useMacro {
            logger.info("Discovering @ChimeraPolymorphic types...")
            let discoveryCoordinator = DiscoveryCoordinator(
                indexStore: indexManager.indexStore,
                symbolRepository: indexManager.symbolRepository,
                sourceRoot: sourcePath,
                logger: logger
            )
            
            let polymorphicTypes = try discoveryCoordinator.findChimeraPolymorphicTypes()
            logger.info("Found \(polymorphicTypes.count) @ChimeraPolymorphic types")
            
            // Add @ChimeraPolymorphic types to root symbols with their schemaIDs
            for (symbol, schemaId) in polymorphicTypes {
                allRootSymbolsWithParams.append((symbol: symbol, parameters: ["key": schemaId]))
            }
        }
        
        let graph = try graphBuilder.buildGraph(from: allRootSymbolsWithParams)
        
        // Phase 3.5: Process knot annotations if using macro mode
        var knotSchemas: [KnotSchemaConverter.KnotSchemaInfo] = []
        if useMacro {
            logger.info("Scanning for knot annotations (@ChimeraMultiKnot, @ChimeraMapKnot)...")
            let knotSymbols = indexManager.findSymbolsWithKnotAnnotations(sourcePath: sourcePath, excludedDirs: excludedDirSet)
            logger.info("Found \(knotSymbols.count) symbols with knot annotations")
            
            // Build model nodes for knot symbols
            for (symbol, knotInfo) in knotSymbols {
                // Try to build a model node for this symbol
                let modelNode = try? graphBuilder.processSymbol(
                    symbol,
                    depth: 0,
                    isPolymorphic: false,
                    polymorphicDepth: 0
                )
                
                // Extract @ChimeraMetaData(description:) for knot schemas
                let metaDescription = ChimeraPropertyParser.extractMetaDescription(
                    from: symbol.filePath,
                    typeName: symbol.name
                )
                
                knotSchemas.append(KnotSchemaConverter.KnotSchemaInfo(
                    symbol: symbol,
                    knotInfo: knotInfo,
                    modelNode: modelNode,
                    metaDescription: metaDescription
                ))
            }
        }
        
        // Phase 4: Output as JSON or JSON Schema
        let jsonString: String
        if jsonSchema {
            logger.info("Converting to JSON Schema format...")
            jsonString = JSONSchemaConverter.convert(graph)
        } else {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(graph)
            jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        }
        
        // Determine output path - default to source location
        let outputPath: String
        if let providedOutput = output {
            outputPath = providedOutput
        } else {
            // Save to source location with timestamp
            let timestamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: "+", with: "_")
            let fileName = "chimera-schema-model-graph.json"
            outputPath = (sourcePath as NSString).appendingPathComponent(fileName)
        }
        
        if FileManager.default.fileExists(atPath: outputPath) {
            logger.info("File already exists at \(outputPath), overwriting...")
        }
        try jsonString.write(toFile: outputPath, atomically: true, encoding: .utf8)
        logger.info("Graph written to: \(outputPath)")
        print("✅ Model graph saved to: \(outputPath)")
        
        // Phase 5: Output knot schemas if any were found
        if !knotSchemas.isEmpty && jsonSchema {
            // Build className -> schemaId mapping from rootSymbolsWithParams
            var classNameToSchemaId: [String: String] = [:]
            for (symbol, parameters) in rootSymbolsWithParams {
                if let schemaId = parameters["key"] as? String {
                    classNameToSchemaId[symbol.name] = schemaId
                }
            }
            
            let knotJsonString = KnotSchemaConverter.convert(knotSchemas, classNameToSchemaId: classNameToSchemaId)
            
            // Generate knot output path
            let knotOutputPath: String
            if outputPath.hasSuffix(".json") {
                knotOutputPath = outputPath.replacingOccurrences(of: ".json", with: "-knots.json")
            } else {
                knotOutputPath = outputPath + "-knots.json"
            }
            
            if FileManager.default.fileExists(atPath: knotOutputPath) {
                logger.info("File already exists at \(knotOutputPath), overwriting...")
            }
            try knotJsonString.write(toFile: knotOutputPath, atomically: true, encoding: .utf8)
            logger.info("Knot schemas written to: \(knotOutputPath)")
            print("✅ Knot schemas saved to: \(knotOutputPath)")
        }
    }
    
    private func findDefaultIndexStore(logger: Logger) throws -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let derivedDataPath = homeDir
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")
        
        logger.info("Searching for index store in DerivedData: \(derivedDataPath.path)")
        
        let contents = try FileManager.default.contentsOfDirectory(
            at: derivedDataPath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        
        // Find the most recently modified project folder
        var mostRecent: (url: URL, date: Date)?
        
        for folder in contents {
            let indexPath = folder
                .appendingPathComponent("Index.noindex/DataStore")
            
            if FileManager.default.fileExists(atPath: indexPath.path) {
                let attributes = try FileManager.default.attributesOfItem(atPath: folder.path)
                if let modDate = attributes[.modificationDate] as? Date {
                    if mostRecent == nil || modDate > mostRecent!.date {
                        mostRecent = (indexPath, modDate)
                    }
                }
            }
        }
        
        guard let found = mostRecent else {
            throw GraphGeneratorError.indexStoreNotFound(
                "Could not find Index.noindex/DataStore in any DerivedData folder"
            )
        }
        
        return found.url.path
    }
}
