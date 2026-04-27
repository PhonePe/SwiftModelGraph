import Foundation
import IndexStoreDB

/// Processes symbols and builds their node representations recursively
class SymbolProcessor {
    private let indexManager: IndexStoreManager
    private let sourceRoot: String
    private let parser: SwiftFileParser
    private let cycleDetector: CycleDetector
    private let logger: Logger
    
    /// Maximum depth for polymorphic expansion
    private let maxPolymorphicDepth = 10
        private let typeDeclarationPattern = #"(?:public\s+|private\s+|internal\s+|fileprivate\s+|open\s+)?(struct|class|enum|protocol)\s+(\w+)"#
    
    init(
        indexManager: IndexStoreManager,
        sourceRoot: String,
        parser: SwiftFileParser,
        cycleDetector: CycleDetector,
        logger: Logger
    ) {
        self.indexManager = indexManager
        self.sourceRoot = sourceRoot
        self.parser = parser
        self.cycleDetector = cycleDetector
        self.logger = logger
    }
    
    /// Process a single symbol and recursively build its child graph
    /// - Parameters:
    ///   - symbol: The symbol to process
    ///   - schemaId: Optional schema ID from @ChimeraSchema parameter
    ///   - depth: Current recursion depth (for logging)
    ///   - isPolymorphic: Whether this is a polymorphic variant
    ///   - polymorphicDepth: Current polymorphic expansion depth
    /// - Returns: A ModelNode representing the symbol and its children
    func processSymbol(
        _ symbol: IndexedSymbol,
        schemaId: String? = nil,
        depth: Int,
        isPolymorphic: Bool = false,
        polymorphicDepth: Int = 0
    ) throws -> ModelNode? {
        let indent = String(repeating: "  ", count: depth)
        logger.debug("\(indent)Processing: \(symbol.name) (USR: \(symbol.usr.prefix(20))...)")
        
        // Check polymorphic depth limit
        if polymorphicDepth > maxPolymorphicDepth {
            logger.warning("\(indent)⚠️ Max polymorphic depth reached for \(symbol.name)")
            return nil
        }
        
        // RECURSION GUARD: Check if we've already visited this symbol in current path
        if cycleDetector.isVisited(symbol.usr) {
            logger.debug("\(indent)⚠️ Cycle detected for \(symbol.name) - skipping")
            return cycleDetector.createCyclicNode(
                for: symbol,
                schemaId: schemaId,
                isPolymorphic: isPolymorphic
            )
        }
        
        // Check cache - if found, mark as cyclic since we're visiting again
        if let cached = cycleDetector.getCachedNode(for: symbol.usr) {
            logger.debug("\(indent)⚠️ Cycle detected for \(symbol.name) (from cache) - skipping")
            return cycleDetector.createCyclicNodeFromCache(cached, schemaId: schemaId)
        }
        
        // Mark as visited BEFORE processing children
        cycleDetector.markVisited(symbol.usr)
        
        // Get inheritance information
        let inheritanceChain = indexManager.getInheritanceChain(of: symbol.name, inFile: symbol.filePath)
        let inheritsFrom = inheritanceChain.first?.name
        
        if let parent = inheritsFrom {
            logger.debug("\(indent)  Inherits from: \(parent)")
        }
        
        // Collect inherited properties
        let inheritedProperties = try collectInheritedProperties(
            from: inheritanceChain,
            indent: indent
        )
        
        // Extract properties and enum cases using SwiftSyntax
        let properties: [ExtractedProperty]
        let enumCases: [EnumCaseInfo]
        do {
            let result = try parser.extractProperties(
                fromFile: symbol.filePath,
                typeName: symbol.name
            )
            properties = result.properties
            enumCases = result.enumCases
        } catch {
            logger.warning("\(indent)Failed to parse \(symbol.name): \(error.localizedDescription)")
            return nil
        }
        
        logger.debug("\(indent)Found \(properties.count) properties and \(enumCases.count) enum cases in \(symbol.name)")
        
        // Check for type-level @ChimeraPolymorphic annotation
        let typePolymorphicInfo = PolymorphicParser.extractChimeraPolymorphicMapping(
            from: symbol.filePath,
            typeName: symbol.name
        )
        
        var typePolymorphism: PolymorphicInfo? = nil
        if let polyInfo = typePolymorphicInfo, let polySchemaId = polyInfo.schemaId {
            logger.debug("\(indent)🔄 Found @ChimeraPolymorphic on \(symbol.name): schemaID=\(polySchemaId), key=\(polyInfo.discriminatorKey)")
            
            // Process polymorphic variants and build their schemas
            let variants = try processPolymorphicVariants(
                polyInfo,
                parentSymbol: symbol,
                depth: depth,
                polymorphicDepth: polymorphicDepth,
                indent: indent
            )
            
            typePolymorphism = PolymorphicInfo(
                discriminatorKey: polyInfo.discriminatorKey,
                variants: variants,
                isProtocol: polyInfo.isProtocol,
                schemaId: polySchemaId
            )
        }
        
        // Extract CodingKeys for this type
        let codingKeys = CodingKeysParser.extractCodingKeys(from: symbol.filePath, typeName: symbol.name)

        // Extract @ChimeraMetaData description only for root schemas (types with @ChimeraSchema).
        // Nested types and polymorphic variants are never root schemas, so @ChimeraMetaData
        // on them has no effect on the output.
        let schemaDescription: String?
        if schemaId != nil {
            schemaDescription = ChimeraPropertyParser.extractMetaDescription(
                from: symbol.filePath,
                typeName: symbol.name
            )
        } else {
            schemaDescription = nil
        }

        // Batch-extract @ChimeraProperty annotations for all properties (one file parse)
        let chimeraAnnotations = ChimeraPropertyParser.extractPropertyAnnotations(
            from: symbol.filePath,
            typeName: symbol.name
        )

        // Extract property-level @ChimeraSchema annotations (for property-level schemas)
        let propertyLevelSchemas = ChimeraPropertyParser.extractPropertyLevelSchemas(
            from: symbol.filePath,
            typeName: symbol.name
        )

        // Process properties and find children
        let (propertyInfos, children) = try processProperties(
            properties,
            for: symbol,
            codingKeys: codingKeys,
            chimeraAnnotations: chimeraAnnotations,
            propertyLevelSchemas: propertyLevelSchemas,
            depth: depth,
            polymorphicDepth: polymorphicDepth,
            indent: indent
        )
        
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
        
        // Filter out properties with property-level @ChimeraSchema from the parent's property list
        // These become separate root schemas, not properties of the parent
        let filteredPropertyInfos = propertyInfos.filter { $0.chimeraSchemaKey == nil }
        
        // Note: Do NOT filter property-level schema nodes from children here
        // GraphBuilder.collectPropertyLevelSchemas() needs to find them in the tree
        
        let node = ModelNode(
            name: symbol.name,
            kind: kindString,
            filePath: symbol.filePath,
            line: symbol.line,
            schemaId: schemaId,
            schemaDescription: schemaDescription,
            inheritsFrom: inheritsFrom,
            inheritedProperties: inheritedProperties,
            properties: filteredPropertyInfos,
            enumCases: enumCases,
            children: children,  // Include property-level schema nodes so GraphBuilder can collect them
            isCyclic: false,
            isPolymorphic: isPolymorphic,
            polymorphism: typePolymorphism
        )
        
        // Cache the result
        cycleDetector.cacheNode(node, for: symbol.usr)
        
        return node
    }
    
    // MARK: - Private Helpers
    
    /// Collect inherited properties from parent classes/structs
    private func collectInheritedProperties(
        from inheritanceChain: [IndexedSymbol],
        indent: String
    ) throws -> [InheritedPropertyInfo] {
        var inheritedProperties: [InheritedPropertyInfo] = []
        
        for parentSymbol in inheritanceChain {
            do {
                let parentResult = try parser.extractProperties(
                    fromFile: parentSymbol.filePath,
                    typeName: parentSymbol.name
                )
                
                // Find original declaration for each property
                for property in parentResult.properties {
                    var originalSymbol = parentSymbol
                    let declaredIn = parentSymbol.name
                    
                    // Walk up the chain to find original declaration
                    let parentChain = indexManager.getInheritanceChain(of: parentSymbol.name, inFile: parentSymbol.filePath)
                    for ancestor in parentChain.reversed() {
                        if let ancestorResult = try? parser.extractProperties(fromFile: ancestor.filePath, typeName: ancestor.name),
                           ancestorResult.properties.contains(where: { $0.name == property.name }) {
                            originalSymbol = ancestor
                        }
                    }
                    
                    // Extract CodingKeys for this property
                    let codingKeys = CodingKeysParser.extractCodingKeys(from: parentSymbol.filePath, typeName: parentSymbol.name)
                    let codingKey = codingKeys[property.name] ?? nil
                    
                    inheritedProperties.append(InheritedPropertyInfo(
                        name: property.name,
                        typeName: property.typeName,
                        isOptional: property.isOptional,
                        isArray: property.isArray,
                        isSet: property.isSet,
                        isDictionary: property.isDictionary,
                        codingKey: codingKey,
                        declaredIn: declaredIn,
                        originallyDeclaredIn: originalSymbol.name,
                        filePath: originalSymbol.filePath,
                        line: originalSymbol.line
                    ))
                }
            } catch {
                logger.warning("\(indent)  Failed to extract properties from parent \(parentSymbol.name)")
            }
        }
        
        return inheritedProperties
    }
    
    /// Process properties and build children nodes
    private func processProperties(
        _ properties: [ExtractedProperty],
        for symbol: IndexedSymbol,
        codingKeys: [String: String?],
        chimeraAnnotations: [String: ChimeraPropertyAnnotation] = [:],
        propertyLevelSchemas: [String: String] = [:],
        depth: Int,
        polymorphicDepth: Int,
        indent: String
    ) throws -> (propertyInfos: [PropertyInfo], children: [ModelNode]) {
        var propertyInfos: [PropertyInfo] = []
        var children: [ModelNode] = []
        
        for property in properties {
            // Check for @PolymorphicMapping on this property
            let polymorphicInfo = PolymorphicParser.extractPolymorphicMapping(
                from: symbol.filePath,
                typeName: symbol.name,
                propertyName: property.name
            )
            
            if let polyInfo = polymorphicInfo {
                logger.debug("\(indent)  🔄 Found @PolymorphicMapping on \(property.name): discriminator=\(polyInfo.discriminatorKey), variants=\(polyInfo.variants.keys.joined(separator: ", "))")
            }
            
            // Get CodingKey for this property
            let codingKey = codingKeys[property.name] ?? nil
            
            var propertyInfo = PropertyInfo(
                name: property.name,
                typeName: property.typeName,
                isOptional: property.isOptional,
                isArray: property.isArray,
                isSet: property.isSet,
                isDictionary: property.isDictionary,
                dictionaryKeyType: property.genericTypes.first,
                codingKey: codingKey
            )
            
            // Check if this property is polymorphic or if type should be explored
            if let polyInfo = polymorphicInfo {
                let variants = try processPolymorphicVariants(
                    polyInfo,
                    parentSymbol: symbol,
                    depth: depth,
                    polymorphicDepth: polymorphicDepth,
                    indent: indent
                )
                
                // Add polymorphism info to the property
                propertyInfo.isPolymorphic = true
                propertyInfo.polymorphism = PolymorphicInfo(
                    discriminatorKey: polyInfo.discriminatorKey,
                    variants: variants,
                    isProtocol: polyInfo.isProtocol,
                    schemaId: nil  // Property-level polymorphism doesn't have schemaId
                )
            }
            
            // Apply @ChimeraProperty annotation data (if present)
            if let annotation = chimeraAnnotations[property.name] {
                // key parameter overrides CodingKeys enum mapping
                if let key = annotation.key {
                    propertyInfo.codingKey = key
                }
                if !annotation.description.isEmpty {
                    propertyInfo.chimeraDescription = annotation.description
                }
                if annotation.isDeprecated {
                    propertyInfo.isDeprecated = true
                }
                if !annotation.regexPatterns.isEmpty {
                    propertyInfo.regexPatterns = annotation.regexPatterns
                }
                // Sentinel: -0.0 (negative zero) means "not provided"
                if !(annotation.min.sign == .minus && annotation.min.isZero) {
                    propertyInfo.minimum = annotation.min
                }
                if !(annotation.max.sign == .minus && annotation.max.isZero) {
                    propertyInfo.maximum = annotation.max
                }
            }

            // Apply property-level @ChimeraSchema annotation (if present)
            if let schemaKey = propertyLevelSchemas[property.name] {
                propertyInfo.chimeraSchemaKey = schemaKey
                logger.debug("\(indent)  🔑 Found property-level @ChimeraSchema(key: \"\(schemaKey)\") on \(property.name)")
            }

            propertyInfos.append(propertyInfo)
            
            // Explore non-polymorphic types as children (but skip if property has @ChimeraSchema)
            // Properties with @ChimeraSchema will be processed separately as root schemas
            if propertyInfo.chimeraSchemaKey == nil && polymorphicInfo == nil && shouldExploreType(property.typeName) {
                logger.debug("\(indent)  Property \(property.name): \(property.typeName) - exploring...")
                
                if let childNodes = try explorePropertyType(
                    property,
                    parentSymbol: symbol,
                    depth: depth,
                    polymorphicDepth: polymorphicDepth,
                    indent: indent
                ) {
                    children.append(contentsOf: childNodes)
                }
            } else if propertyInfo.chimeraSchemaKey != nil {
                logger.debug("\(indent)  Property \(property.name): \(property.typeName) - has @ChimeraSchema, will be processed separately")
            } else {
                logger.debug("\(indent)  Property \(property.name): \(property.typeName) - primitive/ignored")
            }
        }
        
        // Create separate ModelNode entries for properties with @ChimeraSchema annotations
        for propertyInfo in propertyInfos {
            guard let schemaKey = propertyInfo.chimeraSchemaKey else { continue }
            
            logger.debug("\(indent)  Creating property-level schema for \(propertyInfo.name) with key: \(schemaKey)")
            
            // For property-level schemas, create a node with the property's type as root
            // Find the property to get its type information
            guard let property = properties.first(where: { $0.name == propertyInfo.name }) else {
                continue
            }
            
            // Create a synthetic "ModelNode" representing the property's type structure
            // For dictionaries: typeName is the value type, isDictionary=true
            // For arrays: typeName is the element type, isArray=true
            // For custom types: typeName is the type itself
            
            // Note: We don't recursively explore children here to avoid cycle detection issues
            // The JSONSchemaConverter will resolve child types from the nodeMap during conversion
            
            // Create the property-level schema node
            let propertySchemaNode = ModelNode(
                name: property.typeName,  // Use the property's type as the node name
                kind: "property-schema",  // Special kind to distinguish property-level schemas
                filePath: symbol.filePath,
                line: symbol.line,
                schemaId: schemaKey,
                schemaDescription: propertyInfo.chimeraDescription,
                inheritsFrom: nil,
                inheritedProperties: [],
                properties: [propertyInfo],  // Include the property info itself
                enumCases: [],
                children: [],  // Children will be resolved by JSONSchemaConverter
                isCyclic: false,
                isPolymorphic: propertyInfo.isPolymorphic,
                polymorphism: propertyInfo.polymorphism,
                sourceProperty: propertyInfo  // Mark this as a property-level schema
            )
            
            children.append(propertySchemaNode)
        }
        
        return (propertyInfos, children)
    }
    
    /// Process polymorphic variants for a property
    private func processPolymorphicVariants(
        _ polyInfo: PolymorphicParser.ParsedPolymorphicMapping,
        parentSymbol: IndexedSymbol,
        depth: Int,
        polymorphicDepth: Int,
        indent: String
    ) throws -> [PolymorphicVariant] {
        var variants: [PolymorphicVariant] = []
        
        for (discriminatorValue, variantTypeName) in polyInfo.variants {
            logger.debug("\(indent)    Expanding variant: \(discriminatorValue) -> \(variantTypeName)")
            
            // Find the variant type
            let variantSymbol = findSymbolByNameWithFallback(variantTypeName, preferredFilePath: parentSymbol.filePath)
            
            if let variantSymbol = variantSymbol {
                // Extract @ChimeraSchema key from the variant type, if present
                let variantSchemaKey = PolymorphicParser.extractChimeraSchemaKey(
                    from: variantSymbol.filePath,
                    typeName: variantTypeName
                )
                
                if let schemaKey = variantSchemaKey {
                    logger.debug("\(indent)      Found @ChimeraSchema(key: \"\(schemaKey)\") on variant \(variantTypeName)")
                }
                
                if let variantNode = try processSymbol(
                    variantSymbol,
                    depth: depth + 1,
                    isPolymorphic: true,
                    polymorphicDepth: polymorphicDepth + 1
                ) {
                    let variant = PolymorphicVariant(
                        discriminatorValue: discriminatorValue,
                        typeName: variantTypeName,
                        schema: variantNode,
                        schemaId: variantSchemaKey
                    )
                    variants.append(variant)
                }
            } else {
                logger.warning("\(indent)    Could not find variant type: \(variantTypeName)")
            }
        }
        
        return variants
    }
    
    /// Explore a property's type and return child nodes
    private func explorePropertyType(
        _ property: ExtractedProperty,
        parentSymbol: IndexedSymbol,
        depth: Int,
        polymorphicDepth: Int,
        indent: String
    ) throws -> [ModelNode]? {
        // Try index lookup first, then fallback to source-based lookup in the same file.
        let childSymbol = findSymbolByNameWithFallback(property.typeName, preferredFilePath: parentSymbol.filePath)
        
        guard let childSymbol = childSymbol else {
            logger.debug("\(indent)  Could not find \(property.typeName) in index")
            return nil
        }
        
        // Check if this type is actually a protocol - if so, find all conforming types
        if childSymbol.kind == .protocol {
            return try handleProtocolType(
                property,
                protocolSymbol: childSymbol,
                depth: depth,
                polymorphicDepth: polymorphicDepth,
                indent: indent
            )
        } else {
            // Regular type exploration
            if let childNode = try processSymbol(childSymbol, depth: depth + 1, polymorphicDepth: polymorphicDepth) {
                // Associate the child with its parent property
                var nodeWithProperty = childNode
                nodeWithProperty.parentPropertyName = property.name
                return [nodeWithProperty]
            }
        }
        
        return nil
    }
    
    /// Handle exploration of protocol types
    private func handleProtocolType(
        _ property: ExtractedProperty,
        protocolSymbol: IndexedSymbol,
        depth: Int,
        polymorphicDepth: Int,
        indent: String
    ) throws -> [ModelNode]? {
        logger.debug("\(indent)    \(property.typeName) is a protocol - finding all conforming types")
        let conformingTypes = indexManager.findTypesConforming(to: property.typeName)
        
        // Build polymorphic variants for protocol conformance
        var variants: [PolymorphicVariant] = []
        for conformingType in conformingTypes {
            logger.debug("\(indent)      Conforming type: \(conformingType.name)")
            
            // Extract @ChimeraSchema key from the conforming type, if present
            let conformingSchemaKey = PolymorphicParser.extractChimeraSchemaKey(
                from: conformingType.filePath,
                typeName: conformingType.name
            )
            
            if let schemaKey = conformingSchemaKey {
                logger.debug("\(indent)        Found @ChimeraSchema(key: \"\(schemaKey)\") on conforming type \(conformingType.name)")
            }
            
            if let conformingNode = try processSymbol(
                conformingType,
                depth: depth + 1,
                isPolymorphic: true,
                polymorphicDepth: polymorphicDepth + 1
            ) {
                let variant = PolymorphicVariant(
                    discriminatorValue: conformingType.name,
                    typeName: conformingType.name,
                    schema: conformingNode,
                    schemaId: conformingSchemaKey
                )
                variants.append(variant)
            }
        }
        
        // Update would need to happen in processProperties, not here
        // Return empty for now as this is handled differently
        return nil
    }
    
    /// Determine if a type should be explored (i.e., it's not a primitive)
    private func shouldExploreType(_ typeName: String) -> Bool {
        // Skip primitives
        if TypeUtilities.isPrimitiveType(typeName) {
            return false
        }
        
        // Skip known framework types that aren't models
        let frameworkTypes: Set<String> = [
            "View", "Color", "Image", "Text", "Font",
            "Binding", "State", "Published", "ObservableObject",
            "Error", "Result", "Codable", "Hashable", "Equatable",
            "Identifiable", "Comparable"
        ]
        
        if frameworkTypes.contains(typeName) {
            return false
        }
        
        // Skip generic placeholders (single letter types like T, U, V)
        if typeName.count == 1 && typeName.first?.isUppercase == true {
            return false
        }
        
        return true
    }

    /// Find a symbol by name using IndexStore first and then source-file fallback for local declarations.
    private func findSymbolByNameWithFallback(_ typeName: String, preferredFilePath: String) -> IndexedSymbol? {
        if let symbol = indexManager.findSymbolByName(typeName, inFile: preferredFilePath) {
            return symbol
        }

        if let symbol = indexManager.findSymbolByName(typeName) {
            return symbol
        }

        return findTypeDeclarationInFile(typeName: typeName, filePath: preferredFilePath)
    }

    /// Parse a file to find a local type declaration and create a synthetic symbol when IndexStore is missing it.
    private func findTypeDeclarationInFile(typeName: String, filePath: String) -> IndexedSymbol? {
        guard let source = try? String(contentsOfFile: filePath, encoding: .utf8),
              let regex = try? NSRegularExpression(pattern: typeDeclarationPattern) else {
            return nil
        }

        let lines = source.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = regex.firstMatch(in: line, range: range),
                  match.numberOfRanges >= 3,
                  let kindRange = Range(match.range(at: 1), in: line),
                  let nameRange = Range(match.range(at: 2), in: line) else {
                continue
            }

            let foundName = String(line[nameRange])
            guard foundName == typeName else {
                continue
            }

            let kindText = String(line[kindRange])
            let symbolKind: IndexSymbolKind
            switch kindText {
            case "struct":
                symbolKind = .struct
            case "class":
                symbolKind = .class
            case "enum":
                symbolKind = .enum
            case "protocol":
                symbolKind = .protocol
            default:
                continue
            }

            logger.debug("  Using source fallback for type \(typeName) in \(filePath)")
            return IndexedSymbol(
                name: typeName,
                usr: "file://\(filePath)#\(typeName)",
                kind: symbolKind,
                filePath: filePath,
                line: index + 1,
                column: 1
            )
        }

        return nil
    }
}
