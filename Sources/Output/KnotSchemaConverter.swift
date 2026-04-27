import Foundation

/// Converts ModelGraph nodes with knot annotations to JSON Schema format
class KnotSchemaConverter {
    
    struct KnotSchemaInfo {
        let symbol: IndexedSymbol
        let knotInfo: KnotInfo
        let modelNode: ModelNode?
        let metaDescription: String?
    }
    
    /// Convert knot schemas to JSON Schema format array
    /// - Parameters:
    ///   - knotSchemas: Array of knot schema info
    ///   - classNameToSchemaId: Mapping of class names to their schema IDs from @ChimeraSchema annotations
    static func convert(_ knotSchemas: [KnotSchemaInfo], classNameToSchemaId: [String: String] = [:]) -> String {
        var schemasArray: [[String: Any]] = []
        
        for knotSchema in knotSchemas {
            let schemaObject = convertKnotSchema(knotSchema, classNameToSchemaId: classNameToSchemaId)
            schemasArray.append(schemaObject)
        }
        
        // Convert to JSON string
        if let jsonData = try? JSONSerialization.data(withJSONObject: schemasArray, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "[]"
    }
    
    /// Convert a single knot schema
    /// - Parameters:
    ///   - knotSchema: The knot schema info to convert
    ///   - classNameToSchemaId: Mapping of class names to their schema IDs
    private static func convertKnotSchema(_ knotSchema: KnotSchemaInfo, classNameToSchemaId: [String: String]) -> [String: Any] {
        let symbol = knotSchema.symbol
        let knotInfo = knotSchema.knotInfo
        
        // Resolve subSchemas: convert class names to schema IDs where available
        let resolvedSubSchemas = knotInfo.subSchemas.map { className -> String in
            // Try to find the schema ID for this class name
            if let schemaId = classNameToSchemaId[className] {
                return schemaId
            }
            // If not found, keep the class name as is
            return className
        }
        
        // Build schemaDefinition based on knot type
        var schemaDefinition: [String: Any]
        
        if knotInfo.knotType == .multiKnot {
            // MultiKnot: array with oneOf for subSchemas
            let oneOfItems = resolvedSubSchemas.map { schemaId -> [String: Any] in
                return ["const": schemaId]
            }
            
            schemaDefinition = [
                "$anchor": knotInfo.schemaId,
                "type": "array",
                "items": [
                    "type": "string",
                    "oneOf": oneOfItems
                ] as [String : Any]
            ]
        } else {
            // MapKnot: keep original structure
            schemaDefinition = [
                "$schema": "https://json-schema.org/draft/2020-12/schema",
                "$anchor": knotInfo.schemaId,
                "type": "object",
                "title": symbol.name,
                "knotType": knotInfo.knotType.rawValue,
                "subSchemas": resolvedSubSchemas
            ]
            
            // Add properties if we have the model node
            if let modelNode = knotSchema.modelNode {
                if !modelNode.properties.isEmpty {
                    schemaDefinition["properties"] = convertProperties(modelNode.properties)
                    
                    let required = modelNode.properties.filter { !$0.isOptional }.map {
                        $0.codingKey ?? $0.name
                    }
                    if !required.isEmpty {
                        schemaDefinition["required"] = required
                    }
                }
                
                // Add enum cases if present
                if !modelNode.enumCases.isEmpty {
                    schemaDefinition["enum"] = modelNode.enumCases.map { $0.name }
                }
            }
        }
        
        // Build metadata - use @ChimeraMetaData(description:) if available
        let metaData: [String: Any] = [
            "description": knotSchema.metaDescription ?? ""
        ]
        
        // Build the structured schema object
        let schemaObject: [String: Any] = [
            "schemaDefinition": schemaDefinition,
            // "status": "APPROVED",
            "associatedKeys": [],
            "metaData": metaData
        ]
        
        return schemaObject
    }
    
    /// Convert properties to JSON Schema properties object
    private static func convertProperties(_ properties: [PropertyInfo]) -> [String: Any] {
        var propertiesSchema: [String: Any] = [:]
        
        for property in properties {
            let propertyName = property.codingKey ?? property.name
            propertiesSchema[propertyName] = convertPropertyType(property)
        }
        
        return propertiesSchema
    }
    
    /// Convert a property type to JSON Schema type
    private static func convertPropertyType(_ property: PropertyInfo) -> [String: Any] {
        var propertySchema: [String: Any] = [:]
        
        // Handle arrays
        if property.isArray {
            propertySchema["type"] = "array"
            propertySchema["items"] = typeSchema(property.typeName)
            return propertySchema
        }
        
        // Handle sets (as arrays with uniqueItems)
        if property.isSet {
            propertySchema["type"] = "array"
            propertySchema["items"] = typeSchema(property.typeName)
            propertySchema["uniqueItems"] = true
            return propertySchema
        }
        
        // Handle dictionaries (as objects with additionalProperties)
        if property.isDictionary {
            propertySchema["type"] = "object"
            propertySchema["additionalProperties"] = typeSchema(property.typeName)
            return propertySchema
        }
        
        // Regular type
        let typeInfo = typeSchema(property.typeName)
        if TypeUtilities.isPrimitiveType(property.typeName) {
            propertySchema = typeInfo
        } else {
            // Reference to another schema
            propertySchema["$ref"] = "#/definitions/\(property.typeName)"
        }
        
        return propertySchema
    }
    
    /// Get JSON Schema type for a Swift type
    private static func typeSchema(_ typeName: String) -> [String: Any] {
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
            // Non-primitive type - will be referenced
            return ["$ref": "#/definitions/\(typeName)"]
        }
    }
}
