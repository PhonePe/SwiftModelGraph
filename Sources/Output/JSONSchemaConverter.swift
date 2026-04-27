import Foundation

/// Converts ModelGraph to JSON Schema format
/// https://json-schema.org/
class JSONSchemaConverter {
    
    /// Convert a ModelGraph to JSON Schema format
    /// Returns a JSON string containing array of schema objects
    static func convert(_ graph: ModelGraph, baseURL: String = "https://example.com/schemas") -> String {
        var schemasArray: [[String: Any]] = []
        
        // Build a lookup map of all nodes in the graph for inlining
        // Priority: Root nodes with schemaId should not be overwritten by children
        var nodeMap: [String: ModelNode] = [:]
        
        // First, add all children (they might not have schemaId)
        for root in graph.roots {
            addChildrenToMap(root, map: &nodeMap)
        }
        
        // Then, add/overwrite with roots (they have schemaId and take priority)
        for root in graph.roots {
            nodeMap[root.name] = root
        }
        
        // Track seen schema IDs to detect duplicates
        var schemaIdToFile: [String: String] = [:]
        
        // Convert each root schema
        for root in graph.roots {
            // Skip empty container types (types with only property-level schemas)
            // These are just used to extract property-level schemas and shouldn't output
            let hasSchemaId = root.schemaId != nil
            let hasProperties = !root.properties.isEmpty
            let hasPolymorphism = root.polymorphism != nil
            let hasEnumCases = !root.enumCases.isEmpty
            
            if !hasSchemaId && !hasProperties && !hasPolymorphism && !hasEnumCases {
                // Skip outputting this empty container type
                continue
            }
            
            // Check for duplicate schema IDs
            if let schemaId = root.schemaId {
                if let existingFile = schemaIdToFile[schemaId] {
                    // Found a duplicate - fail with error
                    let error = """
                    ❌ ERROR: Duplicate schema ID detected!
                    
                    Schema ID: '\(schemaId)'
                    First defined in:  \(existingFile)
                    Also defined in:   \(root.filePath)
                    
                    Each @ChimeraSchema(key: "...") must have a unique key.
                    Please use different schema IDs or remove one of the duplicate annotations.
                    """
                    print(error)
                    fatalError("Duplicate schema ID '\(schemaId)' found in multiple files")
                }
                schemaIdToFile[schemaId] = root.filePath
            }
            
            let schema: [String: Any]
            
            // Check if this is a @ChimeraPolymorphic type (has type-level polymorphism with schemaId)
            if let polymorphism = root.polymorphism, polymorphism.schemaId != nil {
                // Generate polymorphic schema with oneOf inside properties
                schema = convertPolymorphicNodeInline(root, polymorphism: polymorphism, nodeMap: nodeMap, isNested: false)
            } else {
                // Regular node conversion
                schema = convertNodeInline(root, nodeMap: nodeMap)
            }
            
            // Build metadata — description from @ChimeraMetaData(description:) if present
            let metaData: [String: Any] = [
                "description": root.schemaDescription ?? ""
            ]
            
            // Serialize schema dict to a compact JSON string for schemaDefinition
            let schemaDefinitionValue: Any
            // if let schemaData = try? JSONSerialization.data(withJSONObject: schema, options: [.sortedKeys]),
            //    let schemaString = String(data: schemaData, encoding: .utf8) {
            //     schemaDefinitionValue = schemaString
            // } else {
                schemaDefinitionValue = schema
            // }

            // Build the structured schema object
            var schemaObject: [String: Any] = [
                "schemaDefinition": schemaDefinitionValue,
                // "status": "APPROVED", // no longer needed according to manav
                // "associatedKeys": [], // Can be populated with related schema IDs
                "metaData": metaData
            ]

            if let schemaId = root.schemaId ?? root.polymorphism?.schemaId {
                schemaObject["schemaId"] = schemaId
            }

            schemasArray.append(schemaObject)
        }
        
        // Convert to JSON string
        if let jsonData = try? JSONSerialization.data(withJSONObject: schemasArray, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "[]"
    }
    
    /// Recursively add all children to the node map
    private static func addChildrenToMap(_ node: ModelNode, map: inout [String: ModelNode]) {
        for child in node.children {
            map[child.name] = child
            addChildrenToMap(child, map: &map)
        }
    }
    
    /// Convert a ModelNode to a JSON Schema object (inline, no definitions)
    private static func convertNodeInline(_ node: ModelNode, nodeMap: [String: ModelNode], isNested: Bool = false) -> [String: Any] {
        // Handle property-level schemas (from @ChimeraSchema on properties)
        if let sourceProperty = node.sourceProperty {
            return convertPropertyLevelSchema(node, property: sourceProperty, nodeMap: nodeMap, isNested: isNested)
        }
        
        // Handle type-level polymorphism (from @ChimeraPolymorphic)
        if let polymorphism = node.polymorphism {
            return convertPolymorphicNodeInline(node, polymorphism: polymorphism, nodeMap: nodeMap, isNested: isNested)
        }
        
        var schema: [String: Any] = [
            "type": "object"
        ]
        
        // Add $schema and title only for root schemas (not nested)
        if !isNested {
            schema["$schema"] = "https://json-schema.org/draft/2020-12/schema"
        } else {
            // For nested objects, add title if available
            if let schemaId = node.schemaId {
                schema["title"] = schemaId
            }
        }
        
        // Handle enum cases
        if !node.enumCases.isEmpty {
            schema["type"] = "string"
            schema["enum"] = node.enumCases.map { $0.name }
            return schema
        }
        
        // Add properties
        if !node.properties.isEmpty {
            schema["properties"] = convertPropertiesInline(node.properties, nodeMap: nodeMap)

            let required = node.properties.filter { !$0.isOptional }.map {
                $0.codingKey ?? $0.name
            }
            if !required.isEmpty {
                schema["required"] = required
            }
        }

        schema["additionalProperties"] = false

        return schema
    }
    
    /// Convert a property-level schema (from @ChimeraSchema on a property) to JSON Schema
    /// For dictionaries: generates { "type": "object", "additionalProperties": {...} } at root
    /// For arrays: generates { "type": "array", "items": {...} } at root
    /// For custom types: expands the type's properties at root
    private static func convertPropertyLevelSchema(_ node: ModelNode, property: PropertyInfo, nodeMap: [String: ModelNode], isNested: Bool = false) -> [String: Any] {
        var schema: [String: Any] = [:]
        
        // Add $schema only for root schemas
        if !isNested {
            schema["$schema"] = "https://json-schema.org/draft/2020-12/schema"
        }
        
        // Add title from the property's chimeraSchemaKey (only for nested schemas)
        if isNested, let schemaId = node.schemaId {
            schema["title"] = schemaId
        }
        
        // Add description if present
        if let description = node.schemaDescription {
            schema["description"] = description
        }
        
        // Handle based on property type
        if property.isDictionary {
            // Dictionary: place additionalProperties at root level
            schema["type"] = "object"
            
            // Get the value type schema
            if let childNode = nodeMap[property.typeName] {
                schema["additionalProperties"] = convertNodeInline(childNode, nodeMap: nodeMap, isNested: true)
            } else {
                schema["additionalProperties"] = typeSchemaInline(property.typeName)
            }
            
            // Add propertyNames constraint for Bool keys
            if let keyType = property.dictionaryKeyType, keyType == "Bool" {
                schema["propertyNames"] = ["pattern": "^(true|false)$"]
            }
        } else if property.isArray {
            // Array: place items at root level
            schema["type"] = "array"
            
            // Get the element type schema
            if let childNode = nodeMap[property.typeName] {
                schema["items"] = convertNodeInline(childNode, nodeMap: nodeMap, isNested: true)
            } else {
                schema["items"] = typeSchemaInline(property.typeName)
            }
        } else if property.isSet {
            // Set: place items at root level with uniqueItems
            schema["type"] = "array"
            schema["uniqueItems"] = true
            
            // Get the element type schema
            if let childNode = nodeMap[property.typeName] {
                schema["items"] = convertNodeInline(childNode, nodeMap: nodeMap, isNested: true)
            } else {
                schema["items"] = typeSchemaInline(property.typeName)
            }
        } else {
            // Custom type: expand the type's properties at root level
            // Handle polymorphic property
            if let polymorphism = property.polymorphism {
                // Property is polymorphic - generate oneOf
                var oneOfVariants: [[String: Any]] = []
                for variant in polymorphism.variants {
                    let variantSchema = convertNodeInline(variant.schema, nodeMap: nodeMap, isNested: true)
                    oneOfVariants.append(variantSchema)
                }
                
                schema["type"] = "object"
                schema["additionalProperties"] = false
                schema["oneOf"] = oneOfVariants
            } else if let childNode = nodeMap[property.typeName] {
                // Expand the child node's properties at root
                let childSchema = convertNodeInline(childNode, nodeMap: nodeMap, isNested: true)
                
                // Merge child schema into root (excluding title which we already set)
                for (key, value) in childSchema {
                    if key != "title" && key != "$schema" {
                        schema[key] = value
                    }
                }
            } else {
                // Primitive type - just use the type schema
                schema = typeSchemaInline(property.typeName)
                
                // Re-add title and $schema since typeSchemaInline doesn't include them
                if !isNested {
                    schema["$schema"] = "https://json-schema.org/draft/2020-12/schema"
                }
                if isNested, let schemaId = node.schemaId {
                    schema["title"] = schemaId
                }
            }
        }
        
        return schema
    }
    
    /// Convert a polymorphic node (with @ChimeraPolymorphic) to JSON Schema with oneOf
    private static func convertPolymorphicNodeInline(_ node: ModelNode, polymorphism: PolymorphicInfo, nodeMap: [String: ModelNode], isNested: Bool = false) -> [String: Any] {
        var schema: [String: Any] = ["type": "object"]
        
        // Only add $schema for root-level schemas
        if !isNested {
            schema["$schema"] = "https://json-schema.org/draft/2020-12/schema"
        }
        
        // Add title from polymorphism schemaId (only for nested schemas)
        if isNested, let schemaId = polymorphism.schemaId {
            schema["title"] = schemaId
        }
        
        // Build oneOf array from variants
        var oneOfSchemas: [[String: Any]] = []
        let discriminatorKey = polymorphism.discriminatorKey
        
        for variant in polymorphism.variants {
            var variantSchema: [String: Any] = [
                "type": "object"
            ]
            
            // Add discriminator property with const value
            var properties: [String: Any] = [
                discriminatorKey: [
                    "const": variant.discriminatorValue
                ]
            ]
            
            // Add all variant properties
            let variantNode = variant.schema
            for prop in variantNode.properties {
                let propName = prop.codingKey ?? prop.name
                // Skip discriminator if it already exists in variant
                if propName == discriminatorKey {
                    continue
                }
                properties[propName] = convertPropertyTypeInline(prop, nodeMap: nodeMap)
            }
            
            variantSchema["properties"] = properties
            
            // Build required array - include discriminator key first
            var required = [discriminatorKey]
            required.append(contentsOf: variantNode.properties.filter { 
                !$0.isOptional && ($0.codingKey ?? $0.name) != discriminatorKey 
            }.map { $0.codingKey ?? $0.name })
            
            variantSchema["required"] = required
            variantSchema["title"] = variant.typeName
            
            // Add title if the variant type has its own @ChimeraSchema annotation
            if let schemaId = variant.schemaId {
                variantSchema["title"] = schemaId
            }

            variantSchema["additionalProperties"] = false

            oneOfSchemas.append(variantSchema)
        }
        
        // Place oneOf at root level
        schema["oneOf"] = oneOfSchemas
        schema["additionalProperties"] = false

        return schema
    }
    
    /// Convert properties to JSON Schema properties object (inline)
    private static func convertPropertiesInline(_ properties: [PropertyInfo], nodeMap: [String: ModelNode]) -> [String: Any] {
        var propertiesSchema: [String: Any] = [:]
        
        for property in properties {
            let propertyName = property.codingKey ?? property.name
            
            if property.isPolymorphic, let polymorphism = property.polymorphism {
                // Handle polymorphism with oneOf (inline)
                propertiesSchema[propertyName] = convertPolymorphicPropertyInline(property, polymorphism: polymorphism, nodeMap: nodeMap)
            } else {
                propertiesSchema[propertyName] = convertPropertyTypeInline(property, nodeMap: nodeMap)
            }
        }
        
        return propertiesSchema
    }
    
    /// Convert a polymorphic property to JSON Schema with oneOf (inline)
    private static func convertPolymorphicPropertyInline(_ property: PropertyInfo, polymorphism: PolymorphicInfo, nodeMap: [String: ModelNode]) -> [String: Any] {
        var schemas: [[String: Any]] = []
        
        // Use the custom discriminator key from the annotation
        let discriminatorKey = polymorphism.discriminatorKey
        
        for variant in polymorphism.variants {
            // Create inline variant schema with discriminator
            var variantSchema: [String: Any] = [
                "type": "object"
            ]
            
            // Get properties from the variant schema
            // Use the custom discriminator key from polymorphism
            var properties: [String: Any] = [
                discriminatorKey: [
                    "const": variant.discriminatorValue
                ]
            ]
            
            // Add variant type properties inline
            let variantNode = variant.schema
            for prop in variantNode.properties {
                let propName = prop.codingKey ?? prop.name
                // Skip the discriminator property if it already exists in the variant schema
                if propName == discriminatorKey {
                    continue
                }
                properties[propName] = convertPropertyTypeInline(prop, nodeMap: nodeMap)
            }
            
            variantSchema["properties"] = properties
            
            // Build required array - always include discriminator key first
            var required = [discriminatorKey]
            required.append(contentsOf: variantNode.properties.filter { 
                !$0.isOptional && ($0.codingKey ?? $0.name) != discriminatorKey 
            }.map { $0.codingKey ?? $0.name })
            
            if !required.isEmpty {
                variantSchema["required"] = required
            }
            
            // Add title if available
            variantSchema["title"] = variant.typeName
            
            // Add title if the variant type has its own @ChimeraSchema annotation
            if let schemaId = variant.schemaId {
                variantSchema["title"] = schemaId
            }

            variantSchema["additionalProperties"] = false

            schemas.append(variantSchema)
        }

        return [
            "type": "object",
            "additionalProperties": false,
            "oneOf": schemas
        ]
    }
    
    /// Convert a property type to JSON Schema type (inline)
    private static func convertPropertyTypeInline(_ property: PropertyInfo, nodeMap: [String: ModelNode]) -> [String: Any] {
        // Build the base schema for the property's type
        var propertySchema: [String: Any]

        if property.isArray {
            // Handle arrays
            if let childNode = nodeMap[property.typeName] {
                propertySchema = ["type": "array", "items": convertNodeInline(childNode, nodeMap: nodeMap, isNested: true)]
            } else {
                propertySchema = ["type": "array", "items": typeSchemaInline(property.typeName)]
            }
        } else if property.isSet {
            // Handle sets (as arrays with uniqueItems)
            if let childNode = nodeMap[property.typeName] {
                propertySchema = ["type": "array", "items": convertNodeInline(childNode, nodeMap: nodeMap, isNested: true), "uniqueItems": true]
            } else {
                propertySchema = ["type": "array", "items": typeSchemaInline(property.typeName), "uniqueItems": true]
            }
        } else if property.isDictionary {
            // Handle dictionaries (as objects with additionalProperties)
            if let childNode = nodeMap[property.typeName] {
                propertySchema = ["type": "object", "additionalProperties": convertNodeInline(childNode, nodeMap: nodeMap, isNested: true)]
            } else {
                propertySchema = ["type": "object", "additionalProperties": typeSchemaInline(property.typeName)]
            }
            if let keyType = property.dictionaryKeyType, keyType == "Bool" {
                propertySchema["propertyNames"] = ["pattern": "^(true|false)$"]
            }
        } else if let childNode = nodeMap[property.typeName] {
            // Nested object type
            propertySchema = convertNodeInline(childNode, nodeMap: nodeMap, isNested: true)
        } else {
            // Regular primitive type
            propertySchema = typeSchemaInline(property.typeName)
        }

        // Apply @ChimeraProperty annotation overlays (JSON Schema Draft 2020-12 keywords)

        // description — supported by all types
        if let desc = property.chimeraDescription, !desc.isEmpty {
            propertySchema["description"] = desc
        }

        // deprecated — supported in Draft 2020-12
        if let isDeprecated = property.isDeprecated, isDeprecated {
            propertySchema["deprecated"] = true
        }

        // regex patterns — single: "pattern", multiple: "allOf" with multiple pattern schemas
        if let patterns = property.regexPatterns, !patterns.isEmpty {
            if patterns.count == 1 {
                propertySchema["pattern"] = patterns[0]
            } else {
                propertySchema["allOf"] = patterns.map { ["pattern": $0] as [String: Any] }
            }
        }

        // minimum / maximum — only for numeric Swift types
        let numericTypes: Set<String> = [
            "Int", "Int8", "Int16", "Int32", "Int64",
            "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
            "Float", "Double", "Decimal", "CGFloat"
        ]
        if numericTypes.contains(property.typeName) {
            if let min = property.minimum {
                propertySchema["minimum"] = min
            }
            if let max = property.maximum {
                propertySchema["maximum"] = max
            }
        }

        return propertySchema
    }
    
    /// Get JSON Schema type for a Swift type (inline, no $ref)
    private static func typeSchemaInline(_ typeName: String) -> [String: Any] {
        switch typeName {
        case "String":
            return ["type": "string"]
        case "Int", "Int8", "Int16", "Int32", "Int64",
             "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
            return ["type": "integer"]
        case "Float", "Double", "Decimal", "CGFloat":
            return ["type": "number"]
        case "Bool":
            return ["type": "boolean"]
        case "Date":
            return ["type": "string", "format": "date-time"]
        case "URL":
            return ["type": "string", "format": "uri"]
        case "UUID":
            return ["type": "string", "format": "uuid"]
        case "Data":
            return ["type": "string", "format": "byte"]
        default:
            // Non-primitive type that we couldn't resolve - mark as object
            return ["type": "object"]
        }
    }
}
