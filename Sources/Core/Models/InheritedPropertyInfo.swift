import Foundation

/// Information about a property inherited from a parent class
struct InheritedPropertyInfo: Codable {
    /// The property name
    let name: String
    
    /// The type name
    let typeName: String
    
    /// Whether the property is optional
    let isOptional: Bool
    
    /// Whether the property is an array
    let isArray: Bool
    
    /// Whether the property is a set
    let isSet: Bool
    
    /// Whether the property is a dictionary
    let isDictionary: Bool
    
    /// JSON key from CodingKeys enum (null if not mapped)
    var codingKey: String?
    
    /// The immediate parent class that declares this property
    let declaredIn: String
    
    /// The original class where this property was first declared
    let originallyDeclaredIn: String
    
    /// File path where this property is originally declared
    let filePath: String
    
    /// Line number where this property is originally declared
    let line: Int
}
