import Foundation
import SwiftSyntax

/// A SyntaxVisitor that extracts property declarations from struct/class definitions
class PropertyExtractorVisitor: SyntaxVisitor {
    /// The collected properties
    private(set) var properties: [ExtractedProperty] = []
    
    /// The collected enum cases
    private(set) var enumCases: [EnumCaseInfo] = []
    
    /// The name of the type we're extracting from (for filtering nested types)
    private let targetTypeName: String?
    
    /// Track if we're inside the target type's scope
    private var insideTargetType = false
    private var scopeDepth = 0
    
    /// Type analyzer for extracting type information
    private let typeAnalyzer = TypeAnalyzer()
    
    /// Enum extractor for processing enum cases
    private let enumExtractor = EnumExtractor()
    
    init(targetTypeName: String? = nil) {
        self.targetTypeName = targetTypeName
        super.init(viewMode: .sourceAccurate)
    }
    
    // MARK: - Struct/Class tracking
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if let target = targetTypeName, node.name.text == target {
            insideTargetType = true
            scopeDepth = 0
        }
        return .visitChildren
    }
    
    override func visitPost(_ node: StructDeclSyntax) {
        if let target = targetTypeName, node.name.text == target {
            insideTargetType = false
        }
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if let target = targetTypeName, node.name.text == target {
            insideTargetType = true
            scopeDepth = 0
        }
        return .visitChildren
    }
    
    override func visitPost(_ node: ClassDeclSyntax) {
        if let target = targetTypeName, node.name.text == target {
            insideTargetType = false
        }
    }
    
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        if let target = targetTypeName, node.name.text == target {
            insideTargetType = true
            scopeDepth = 0
            
            // Use EnumExtractor to extract cases
            enumCases = enumExtractor.extractEnumCases(from: node)
        }
        return .visitChildren
    }
    
    override func visitPost(_ node: EnumDeclSyntax) {
        if let target = targetTypeName, node.name.text == target {
            insideTargetType = false
        }
    }
    
    // MARK: - Property extraction
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        // Skip if we have a target and we're not inside it
        if targetTypeName != nil && !insideTargetType {
            return .skipChildren
        }
        
        // Skip computed properties (those with only getter)
        // Skip static and private properties
        for modifier in node.modifiers {
            if modifier.name.text == "static" || modifier.name.text == "class" {
                return .skipChildren
            }
            // Skip fully private properties, but allow private(set) which have public/internal getters
            // private(set) properties will have a detail component like "(set)"
            if modifier.name.text == "private" || modifier.name.text == "fileprivate" {
                // Check if this is private(set) or similar by looking for detail component
                let hasDetail = modifier.detail != nil
                // Only skip if there's no detail (i.e., fully private, not private(set))
                if !hasDetail {
                    return .skipChildren
                }
            }
        }
        
        // Process each binding in the declaration
        for binding in node.bindings {
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }
            
            let propertyName = pattern.identifier.text
            
            // Skip computed properties (those with accessors that don't have storage)
            if let accessor = binding.accessorBlock {
                // If it has only get accessor without set, it's computed
                if case .accessors(let accessors) = accessor.accessors {
                    let hasGetter = accessors.contains { $0.accessorSpecifier.text == "get" }
                    let hasSetter = accessors.contains { $0.accessorSpecifier.text == "set" }
                    let hasWillSet = accessors.contains { $0.accessorSpecifier.text == "willSet" }
                    let hasDidSet = accessors.contains { $0.accessorSpecifier.text == "didSet" }
                    
                    // If it only has get without property observers, it's computed
                    if hasGetter && !hasSetter && !hasWillSet && !hasDidSet {
                        continue
                    }
                }
            }
            
            // Get type annotation
            if let typeAnnotation = binding.typeAnnotation {
                if let extracted = typeAnalyzer.extractTypeInfo(from: typeAnnotation.type) {
                    properties.append(ExtractedProperty(
                        name: propertyName,
                        typeName: extracted.typeName,
                        isOptional: extracted.isOptional,
                        isArray: extracted.isArray,
                        isSet: extracted.isSet,
                        isDictionary: extracted.isDictionary,
                        genericTypes: extracted.genericTypes
                    ))
                }
            }
            // If no type annotation, try to infer from initializer (limited)
            else if let initializer = binding.initializer {
                if let inferredType = typeAnalyzer.inferType(from: initializer.value) {
                    properties.append(ExtractedProperty(
                        name: propertyName,
                        typeName: inferredType.typeName,
                        isOptional: inferredType.isOptional,
                        isArray: inferredType.isArray,
                        isSet: inferredType.isSet,
                        isDictionary: inferredType.isDictionary,
                        genericTypes: inferredType.genericTypes
                    ))
                }
            }
        }
        
        return .skipChildren
    }
}
