import Foundation
import SwiftSyntax

/// Analyzes Swift type syntax to extract type information
class TypeAnalyzer {
    
    /// Represents detailed type information extracted from syntax
    struct TypeInfo {
        let typeName: String
        let isOptional: Bool
        let isArray: Bool
        let isSet: Bool
        let isDictionary: Bool
        let genericTypes: [String]
    }
    
    /// Extract comprehensive type information from a type syntax node
    /// - Parameter type: The TypeSyntax node to analyze
    /// - Returns: TypeInfo with details about the type
    func extractTypeInfo(from type: TypeSyntax) -> TypeInfo? {
        // Handle Optional types: Type?
        if let optionalType = type.as(OptionalTypeSyntax.self) {
            if let inner = extractTypeInfo(from: optionalType.wrappedType) {
                return TypeInfo(
                    typeName: inner.typeName,
                    isOptional: true,
                    isArray: inner.isArray,
                    isSet: inner.isSet,
                    isDictionary: inner.isDictionary,
                    genericTypes: inner.genericTypes
                )
            }
        }
        
        // Handle Implicitly Unwrapped Optional: Type!
        if let implicitOptional = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            if let inner = extractTypeInfo(from: implicitOptional.wrappedType) {
                return TypeInfo(
                    typeName: inner.typeName,
                    isOptional: true,
                    isArray: inner.isArray,
                    isSet: inner.isSet,
                    isDictionary: inner.isDictionary,
                    genericTypes: inner.genericTypes
                )
            }
        }
        
        // Handle Array types: [Type]
        if let arrayType = type.as(ArrayTypeSyntax.self) {
            if let elementInfo = extractTypeInfo(from: arrayType.element) {
                return TypeInfo(
                    typeName: elementInfo.typeName,
                    isOptional: false,
                    isArray: true,
                    isSet: false,
                    isDictionary: false,
                    genericTypes: elementInfo.genericTypes
                )
            }
        }
        
        // Handle Dictionary types: [Key: Value]
        if let dictType = type.as(DictionaryTypeSyntax.self) {
            let keyType = dictType.key.trimmedDescription
            let valueType = dictType.value.trimmedDescription
            
            // For dictionaries, we're mainly interested in the value type for graph building
            // But we store both for completeness
            if let valueInfo = extractTypeInfo(from: dictType.value) {
                return TypeInfo(
                    typeName: valueInfo.typeName,
                    isOptional: false,
                    isArray: false,
                    isSet: false,
                    isDictionary: true,
                    genericTypes: [keyType, valueType]
                )
            }
        }
        
        // Handle Generic types: Array<Type>, Optional<Type>, Set<Type>, etc.
        if let identifierType = type.as(IdentifierTypeSyntax.self) {
            let baseName = identifierType.name.text
            
            // Check for generic arguments
            if let genericArgs = identifierType.genericArgumentClause {
                let args = genericArgs.arguments.map { $0.argument.trimmedDescription }
                
                switch baseName {
                case "Array":
                    if let firstArg = genericArgs.arguments.first {
                        if let elementInfo = extractTypeInfo(from: firstArg.argument) {
                            return TypeInfo(
                                typeName: elementInfo.typeName,
                                isOptional: false,
                                isArray: true,
                                isSet: false,
                                isDictionary: false,
                                genericTypes: args
                            )
                        }
                    }
                    
                case "Set":
                    if let firstArg = genericArgs.arguments.first {
                        if let elementInfo = extractTypeInfo(from: firstArg.argument) {
                            return TypeInfo(
                                typeName: elementInfo.typeName,
                                isOptional: false,
                                isArray: false,
                                isSet: true,
                                isDictionary: false,
                                genericTypes: args
                            )
                        }
                    }
                    
                case "Optional":
                    if let firstArg = genericArgs.arguments.first {
                        if let inner = extractTypeInfo(from: firstArg.argument) {
                            return TypeInfo(
                                typeName: inner.typeName,
                                isOptional: true,
                                isArray: inner.isArray,
                                isSet: inner.isSet,
                                isDictionary: inner.isDictionary,
                                genericTypes: inner.genericTypes
                            )
                        }
                    }
                    
                case "Dictionary":
                    if genericArgs.arguments.count >= 2 {
                        let keyArg = genericArgs.arguments[genericArgs.arguments.startIndex]
                        let valueIndex = genericArgs.arguments.index(after: genericArgs.arguments.startIndex)
                        let valueArg = genericArgs.arguments[valueIndex]
                        
                        if let valueInfo = extractTypeInfo(from: valueArg.argument) {
                            return TypeInfo(
                                typeName: valueInfo.typeName,
                                isOptional: false,
                                isArray: false,
                                isSet: false,
                                isDictionary: true,
                                genericTypes: [keyArg.argument.trimmedDescription, valueArg.argument.trimmedDescription]
                            )
                        }
                    }
                    
                default:
                    // Other generic types - return the base name
                    return TypeInfo(
                        typeName: baseName,
                        isOptional: false,
                        isArray: false,
                        isSet: false,
                        isDictionary: false,
                        genericTypes: args
                    )
                }
            }
            
            // Simple identifier type (no generics)
            return TypeInfo(
                typeName: baseName,
                isOptional: false,
                isArray: false,
                isSet: false,
                isDictionary: false,
                genericTypes: []
            )
        }
        
        // Handle member types: Module.Type
        if let memberType = type.as(MemberTypeSyntax.self) {
            // Return just the final type name
            let fullName = memberType.trimmedDescription
            return TypeInfo(
                typeName: fullName,
                isOptional: false,
                isArray: false,
                isSet: false,
                isDictionary: false,
                genericTypes: []
            )
        }
        
        // Handle tuple types - we'll just note it as a Tuple
        if let _ = type.as(TupleTypeSyntax.self) {
            return TypeInfo(
                typeName: "Tuple",
                isOptional: false,
                isArray: false,
                isSet: false,
                isDictionary: false,
                genericTypes: []
            )
        }
        
        // Handle attributed types (e.g., @escaping, @Sendable)
        if let attributedType = type.as(AttributedTypeSyntax.self) {
            return extractTypeInfo(from: attributedType.baseType)
        }
        
        // Fallback: return the trimmed description
        return TypeInfo(
            typeName: type.trimmedDescription,
            isOptional: false,
            isArray: false,
            isSet: false,
            isDictionary: false,
            genericTypes: []
        )
    }
    
    /// Attempt to infer type from initializer expression
    /// - Parameter expr: The expression syntax to analyze
    /// - Returns: TypeInfo if type can be inferred
    func inferType(from expr: ExprSyntax) -> TypeInfo? {
        // Array literal: []
        if let arrayExpr = expr.as(ArrayExprSyntax.self) {
            // Try to get type from first element
            if let firstElement = arrayExpr.elements.first {
                if let elementType = inferType(from: firstElement.expression) {
                    return TypeInfo(
                        typeName: elementType.typeName,
                        isOptional: false,
                        isArray: true,
                        isSet: false,
                        isDictionary: false,
                        genericTypes: []
                    )
                }
            }
            return nil
        }
        
        // Dictionary literal: [:]
        if let _ = expr.as(DictionaryExprSyntax.self) {
            return nil // Can't easily infer dictionary types
        }
        
        // Function call that might be a constructor: TypeName()
        if let functionCall = expr.as(FunctionCallExprSyntax.self) {
            if let callee = functionCall.calledExpression.as(DeclReferenceExprSyntax.self) {
                let typeName = callee.baseName.text
                // Check if it looks like a type name (starts with uppercase)
                if let firstChar = typeName.first, firstChar.isUppercase {
                    return TypeInfo(
                        typeName: typeName,
                        isOptional: false,
                        isArray: false,
                        isSet: false,
                        isDictionary: false,
                        genericTypes: []
                    )
                }
            }
        }
        
        return nil
    }
}
