import Foundation

/// Information about a property
struct PropertyInfo: Codable {
    /// The property name
    let name: String
    
    /// The type name (base type, unwrapped from optional/array)
    let typeName: String
    
    /// Whether the property is optional (Type?)
    let isOptional: Bool
    
    /// Whether the property is an array ([Type] or Array<Type>)
    let isArray: Bool
    
    /// Whether the property is a set (Set<Type>)
    let isSet: Bool
    
    /// Whether the property is a dictionary
    let isDictionary: Bool

    /// Dictionary key type (e.g., String, Bool) when property is a dictionary
    let dictionaryKeyType: String?
    
    /// JSON key from CodingKeys enum (null if not mapped)
    var codingKey: String?
    
    /// Whether this property is polymorphic
    var isPolymorphic: Bool = false

    /// Polymorphic type information (if this property can have multiple types)
    var polymorphism: PolymorphicInfo?

    /// Human-readable description from @ChimeraProperty(description:)
    var chimeraDescription: String? = nil

    /// Whether this property is deprecated via @ChimeraProperty(isDeprecated:)
    /// Emitted as "deprecated": true in JSON Schema Draft 2020-12 output
    var isDeprecated: Bool? = nil

    /// Regex patterns from @ChimeraProperty(regex:)
    /// Single pattern → JSON Schema "pattern", multiple → "allOf" with multiple "pattern" schemas
    var regexPatterns: [String]? = nil

    /// Minimum numeric value from @ChimeraProperty(min:)
    /// Only applied for numeric property types (Int, Float, Double, etc.)
    var minimum: Double? = nil

    /// Maximum numeric value from @ChimeraProperty(max:)
    /// Only applied for numeric property types (Int, Float, Double, etc.)
    var maximum: Double? = nil

    /// Schema key from property-level @ChimeraSchema(key: "...")
    /// When present, this property becomes its own root-level schema instead of being nested
    var chimeraSchemaKey: String? = nil
    
    /// Computed description for display
    var typeDescription: String {
        var desc = typeName
        if isArray {
            desc = "[\(desc)]"
        } else if isSet {
            desc = "Set<\(desc)>"
        } else if isDictionary {
            desc = "[Key: \(desc)]"
        }
        if isOptional {
            desc += "?"
        }
        return desc
    }
}

/// Represents an extracted property with its type information
struct ExtractedProperty {
    let name: String
    let typeName: String
    let isOptional: Bool
    let isArray: Bool
    let isSet: Bool
    let isDictionary: Bool
    let genericTypes: [String]  // For Dictionary, this holds [KeyType, ValueType]
    
    /// The base type name (unwrapped from optionals/arrays)
    var baseTypeName: String {
        return typeName
    }
    
    var description: String {
        var desc = name + ": "
        if isArray {
            desc += "[\(typeName)]"
        } else if isSet {
            desc += "Set<\(typeName)>"
        } else if isDictionary {
            desc += "[\(genericTypes.first ?? "Key"): \(typeName)]"
        } else {
            desc += typeName
        }
        if isOptional {
            desc += "?"
        }
        return desc
    }
}
