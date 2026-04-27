import Foundation
import SwiftSyntax

/// Visitor that extracts @PolymorphicMapping annotation from a specific property
class PolymorphicVisitor: SyntaxVisitor {
    /// The name of the type containing the property
    let targetTypeName: String
    
    /// The name of the property to extract annotation from
    let targetPropertyName: String
    
    /// The extracted polymorphic mapping, if found
    private(set) var polymorphicMapping: PolymorphicMapping?
    
    /// Track if we're inside the target type
    private var insideTargetType = false
    
    init(targetTypeName: String, targetPropertyName: String) {
        self.targetTypeName = targetTypeName
        self.targetPropertyName = targetPropertyName
        super.init(viewMode: .sourceAccurate)
    }
    
    // MARK: - Type Declaration Tracking
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == targetTypeName {
            insideTargetType = true
            return .visitChildren
        }
        return .skipChildren
    }
    
    override func visitPost(_ node: StructDeclSyntax) {
        if node.name.text == targetTypeName {
            insideTargetType = false
        }
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == targetTypeName {
            insideTargetType = true
            return .visitChildren
        }
        return .skipChildren
    }
    
    override func visitPost(_ node: ClassDeclSyntax) {
        if node.name.text == targetTypeName {
            insideTargetType = false
        }
    }
    
    // MARK: - Property Annotation Extraction
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard insideTargetType else { return .skipChildren }
        
        // Check if this is the target property
        guard let binding = node.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
              pattern.identifier.text == targetPropertyName else {
            return .skipChildren
        }
        
        // Check for @PolymorphicMapping attribute
        for attribute in node.attributes {
            if let customAttr = attribute.as(AttributeSyntax.self),
               let attrName = customAttr.attributeName.as(IdentifierTypeSyntax.self),
               attrName.name.text == "PolymorphicMapping" {
                
                // Extract parameters
                if let arguments = customAttr.arguments?.as(LabeledExprListSyntax.self) {
                    polymorphicMapping = extractMappingFromArguments(arguments)
                }
            }
        }
        
        return .skipChildren
    }
    
    // MARK: - Argument Extraction
    
    /// Extract mapping parameters from attribute arguments
    private func extractMappingFromArguments(_ arguments: LabeledExprListSyntax) -> PolymorphicMapping? {
        var discriminatorKey: String?
        var variants: [String: String] = [:]
        
        for argument in arguments {
            let label = argument.label?.text
            
            // Support both "discriminator" and "key" parameter names
            if label == "discriminator" || label == "key" {
                // Extract string literal
                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                    discriminatorKey = stringLiteral.segments.compactMap { segment in
                        if case .stringSegment(let stringSegment) = segment {
                            return stringSegment.content.text
                        }
                        return nil
                    }.joined()
                }
            } else if label == "variants" || label == "values" {
                // Extract dictionary literal - support both "variants" and "values"
                if let dictExpr = argument.expression.as(DictionaryExprSyntax.self) {
                    variants = extractVariantsFromDict(dictExpr)
                }
            }
        }
        
        guard let discriminator = discriminatorKey else { return nil }
        return PolymorphicMapping(discriminatorKey: discriminator, variants: variants)
    }
    
    /// Extract variants dictionary from dictionary expression
    private func extractVariantsFromDict(_ dictExpr: DictionaryExprSyntax) -> [String: String] {
        var variants: [String: String] = [:]
        
        if case .elements(let elements) = dictExpr.content {
            for element in elements {
                // Extract key (string literal)
                if let keyString = element.key.as(StringLiteralExprSyntax.self) {
                    let key = keyString.segments.compactMap { segment in
                        if case .stringSegment(let stringSegment) = segment {
                            return stringSegment.content.text
                        }
                        return nil
                    }.joined()
                    
                    // Extract value (Type.self)
                    if let memberAccess = element.value.as(MemberAccessExprSyntax.self),
                       let baseType = memberAccess.base?.as(DeclReferenceExprSyntax.self),
                       memberAccess.declName.baseName.text == "self" {
                        let typeName = baseType.baseName.text
                        variants[key] = typeName
                    }
                }
            }
        }
        
        return variants
    }
}

// MARK: - ChimeraPolymorphic Visitor

/// Visitor that extracts @ChimeraPolymorphic annotation from a type declaration
class ChimeraPolymorphicVisitor: SyntaxVisitor {
    /// The name of the type to find
    let targetTypeName: String
    
    /// The extracted polymorphic mapping with schemaId, if found
    private(set) var polymorphicMapping: PolymorphicParser.ParsedPolymorphicMapping?
    
    init(targetTypeName: String) {
        self.targetTypeName = targetTypeName
        super.init(viewMode: .sourceAccurate)
    }
    
    // MARK: - Type Declaration Extraction
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == targetTypeName {
            polymorphicMapping = extractChimeraPolymorphicFromType(node.attributes)
        }
        return .skipChildren
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == targetTypeName {
            polymorphicMapping = extractChimeraPolymorphicFromType(node.attributes)
        }
        return .skipChildren
    }
    
    // MARK: - Annotation Extraction
    
    /// Extract @ChimeraPolymorphic annotation from type attributes
    private func extractChimeraPolymorphicFromType(_ attributes: AttributeListSyntax) -> PolymorphicParser.ParsedPolymorphicMapping? {
        for attribute in attributes {
            if let customAttr = attribute.as(AttributeSyntax.self),
               let attrName = customAttr.attributeName.as(IdentifierTypeSyntax.self),
               attrName.name.text == "ChimeraPolymorphic" {
                
                // Extract parameters: schemaID, key, values
                if let arguments = customAttr.arguments?.as(LabeledExprListSyntax.self) {
                    return extractMappingFromArguments(arguments)
                }
            }
        }
        return nil
    }
    
    /// Extract mapping parameters from @ChimeraPolymorphic arguments
    private func extractMappingFromArguments(_ arguments: LabeledExprListSyntax) -> PolymorphicParser.ParsedPolymorphicMapping? {
        var schemaId: String?
        var discriminatorKey: String?
        var variants: [String: String] = [:]
        
        for argument in arguments {
            let label = argument.label?.text
            
            if label == "schemaID" {
                // Extract schemaID string literal
                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                    schemaId = stringLiteral.segments.compactMap { segment in
                        if case .stringSegment(let stringSegment) = segment {
                            return stringSegment.content.text
                        }
                        return nil
                    }.joined()
                }
            } else if label == "key" {
                // Extract discriminator key string literal
                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                    discriminatorKey = stringLiteral.segments.compactMap { segment in
                        if case .stringSegment(let stringSegment) = segment {
                            return stringSegment.content.text
                        }
                        return nil
                    }.joined()
                }
            } else if label == "values" {
                // Extract values dictionary
                if let dictExpr = argument.expression.as(DictionaryExprSyntax.self) {
                    variants = extractVariantsFromDict(dictExpr)
                }
            }
        }
        
        // Both schemaID and discriminatorKey are required for @ChimeraPolymorphic
        guard let schemaId = schemaId, let discriminator = discriminatorKey else {
            return nil
        }
        
        return PolymorphicParser.ParsedPolymorphicMapping(
            discriminatorKey: discriminator,
            variants: variants,
            isProtocol: false,
            schemaId: schemaId
        )
    }
    
    /// Extract variants dictionary from dictionary expression
    private func extractVariantsFromDict(_ dictExpr: DictionaryExprSyntax) -> [String: String] {
        var variants: [String: String] = [:]
        
        if case .elements(let elements) = dictExpr.content {
            for element in elements {
                // Extract key (string literal)
                if let keyString = element.key.as(StringLiteralExprSyntax.self) {
                    let key = keyString.segments.compactMap { segment in
                        if case .stringSegment(let stringSegment) = segment {
                            return stringSegment.content.text
                        }
                        return nil
                    }.joined()
                    
                    // Extract value (Type.self)
                    if let memberAccess = element.value.as(MemberAccessExprSyntax.self),
                       let baseType = memberAccess.base?.as(DeclReferenceExprSyntax.self),
                       memberAccess.declName.baseName.text == "self" {
                        let typeName = baseType.baseName.text
                        variants[key] = typeName
                    }
                }
            }
        }
        
        return variants
    }
}

// MARK: - ChimeraSchema Type-Level Visitor

/// Visitor that extracts @ChimeraSchema annotation from a type declaration
class ChimeraSchemaTypeVisitor: SyntaxVisitor {
    /// The name of the type to find
    let targetTypeName: String
    
    /// The extracted schema key, if found
    private(set) var schemaKey: String?
    
    init(targetTypeName: String) {
        self.targetTypeName = targetTypeName
        super.init(viewMode: .sourceAccurate)
    }
    
    // MARK: - Type Declaration Extraction
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == targetTypeName {
            schemaKey = extractChimeraSchemaFromType(node.attributes)
        }
        return .skipChildren
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == targetTypeName {
            schemaKey = extractChimeraSchemaFromType(node.attributes)
        }
        return .skipChildren
    }
    
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == targetTypeName {
            schemaKey = extractChimeraSchemaFromType(node.attributes)
        }
        return .skipChildren
    }
    
    // MARK: - Annotation Extraction
    
    /// Extract @ChimeraSchema annotation from type attributes
    private func extractChimeraSchemaFromType(_ attributes: AttributeListSyntax) -> String? {
        for attribute in attributes {
            if let customAttr = attribute.as(AttributeSyntax.self),
               let attrName = customAttr.attributeName.as(IdentifierTypeSyntax.self),
               attrName.name.text == "ChimeraSchema" {
                
                // Extract the "key" parameter
                if let arguments = customAttr.arguments?.as(LabeledExprListSyntax.self) {
                    return extractKeyFromArguments(arguments)
                }
            }
        }
        return nil
    }
    
    /// Extract the "key" parameter from @ChimeraSchema arguments
    private func extractKeyFromArguments(_ arguments: LabeledExprListSyntax) -> String? {
        for argument in arguments {
            if argument.label?.text == "key" {
                // Extract string literal
                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                    return stringLiteral.segments.compactMap { segment in
                        if case .stringSegment(let stringSegment) = segment {
                            return stringSegment.content.text
                        }
                        return nil
                    }.joined()
                }
            }
        }
        return nil
    }
}
