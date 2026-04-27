import Foundation

/// A node in the model graph representing a struct or class
struct ModelNode: Codable {
    /// The name of the type (e.g., "User", "Address")
    let name: String
    
    /// The kind of type: "struct" or "class"
    let kind: String
    
    /// Absolute path to the source file
    let filePath: String
    
    /// Line number where the type is defined
    let line: Int
    
    /// Schema ID from @ChimeraSchema(key: "...") parameter (if present)
    var schemaId: String?

    /// Description from @ChimeraMetaData(description: "...") annotation (if present)
    var schemaDescription: String?
    
    /// Name of the parent class this type inherits from (if any)
    var inheritsFrom: String?
    
    /// Properties inherited from parent classes
    var inheritedProperties: [InheritedPropertyInfo]
    
    /// All properties declared in this type
    let properties: [PropertyInfo]
    
    /// Enum cases (only populated for enums)
    let enumCases: [EnumCaseInfo]
    
    /// Child nodes (custom types found in properties)
    var children: [ModelNode]
    
    /// Whether this node represents a cyclic reference (to break infinite loops)
    var isCyclic: Bool
    
    /// If this node is a child, the name of the parent's property that references it
    var parentPropertyName: String?
    
    /// Whether this type is a polymorphic variant (expanded from protocol or @PolymorphicMapping)
    var isPolymorphic: Bool
    
    /// Polymorphic type information (if this property can have multiple types)
    var polymorphism: PolymorphicInfo?

    /// When non-nil, indicates this node represents a property-level schema
    /// The property's type becomes the root schema (e.g., dictionary → additionalProperties at root)
    var sourceProperty: PropertyInfo?
    
    enum CodingKeys: String, CodingKey {
        case name
        case kind
        case filePath
        case line
        case schemaId
        case schemaDescription
        case inheritsFrom
        case inheritedProperties
        case properties
        case enumCases
        case children
        case isCyclic
        case parentPropertyName
        case isPolymorphic
        case polymorphism
        case sourceProperty
    }
    
    init(
        name: String,
        kind: String,
        filePath: String,
        line: Int,
        schemaId: String? = nil,
        schemaDescription: String? = nil,
        inheritsFrom: String? = nil,
        inheritedProperties: [InheritedPropertyInfo] = [],
        properties: [PropertyInfo],
        enumCases: [EnumCaseInfo] = [],
        children: [ModelNode],
        isCyclic: Bool,
        parentPropertyName: String? = nil,
        isPolymorphic: Bool = false,
        polymorphism: PolymorphicInfo? = nil,
        sourceProperty: PropertyInfo? = nil
    ) {
        self.name = name
        self.kind = kind
        self.filePath = filePath
        self.line = line
        self.schemaId = schemaId
        self.schemaDescription = schemaDescription
        self.inheritsFrom = inheritsFrom
        self.inheritedProperties = inheritedProperties
        self.properties = properties
        self.enumCases = enumCases
        self.children = children
        self.isCyclic = isCyclic
        self.parentPropertyName = parentPropertyName
        self.isPolymorphic = isPolymorphic
        self.polymorphism = polymorphism
        self.sourceProperty = sourceProperty
    }
}

// MARK: - Pretty Print Extension

extension ModelNode {
    func prettyPrint(indent: Int) -> String {
        let prefix = String(repeating: "  ", count: indent)
        var output = ""
        
        // Node header
        let cyclicMarker = isCyclic ? " ⚠️ [CYCLIC]" : ""
        let propertyRef = parentPropertyName.map { " (via: \($0))" } ?? ""
        output += "\(prefix)📦 \(name) (\(kind))\(propertyRef)\(cyclicMarker)\n"
        
        if !isCyclic {
            // Properties
            if !properties.isEmpty {
                output += "\(prefix)  Properties:\n"
                for prop in properties {
                    let primitiveMarker = TypeUtilities.isPrimitiveType(prop.typeName) ? "📝" : "🔗"
                    output += "\(prefix)    \(primitiveMarker) \(prop.name): \(prop.typeDescription)\n"
                }
            }
            
            // Children
            if !children.isEmpty {
                output += "\(prefix)  Children:\n"
                for child in children {
                    output += child.prettyPrint(indent: indent + 2)
                }
            }
        }
        
        return output
    }
}
