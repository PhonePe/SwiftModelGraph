import Foundation

/// Polymorphic type information
struct PolymorphicInfo: Codable {
    /// The discriminator key used to identify type variants
    let discriminatorKey: String
    
    /// Array of possible type variants
    let variants: [PolymorphicVariant]
    
    /// Whether this comes from protocol conformance
    let isProtocol: Bool
    
    /// Optional schema ID for standalone polymorphic schemas (from @ChimeraPolymorphic)
    let schemaId: String?
}

/// A single polymorphic variant with its schema
struct PolymorphicVariant: Codable {
    /// The discriminator value (e.g., "OPEN_ERROR_SCREEN")
    let discriminatorValue: String
    
    /// The type name for this variant (e.g., "ErrorModels")
    let typeName: String
    
    /// The complete schema for this variant
    let schema: ModelNode
    
    /// Optional schema ID from @ChimeraSchema annotation on the variant type
    let schemaId: String?
}
