import Foundation
import SwiftSyntax

/// Visitor that extracts @ChimeraMultiKnot or @ChimeraMapKnot annotation from a type
class KnotVisitor: SyntaxVisitor {
    /// The name of the type to extract annotation from
    let targetTypeName: String
    
    /// The extracted knot info, if found
    private(set) var knotInfo: KnotInfo?
    
    init(targetTypeName: String) {
        self.targetTypeName = targetTypeName
        super.init(viewMode: .sourceAccurate)
    }
    
    // MARK: - Type Declaration Tracking
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == targetTypeName {
            knotInfo = extractKnotFromAttributes(node.attributes)
        }
        return .skipChildren
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == targetTypeName {
            knotInfo = extractKnotFromAttributes(node.attributes)
        }
        return .skipChildren
    }
    
    // MARK: - Attribute Extraction
    
    /// Extract knot annotation from type attributes
    private func extractKnotFromAttributes(_ attributes: AttributeListSyntax) -> KnotInfo? {
        for attribute in attributes {
            if let customAttr = attribute.as(AttributeSyntax.self) {
                // Get the attribute name - try different syntax types
                var attributeName: String?
                
                if let identifierType = customAttr.attributeName.as(IdentifierTypeSyntax.self) {
                    attributeName = identifierType.name.text
                } else {
                    // Fallback: extract from description
                    let desc = customAttr.attributeName.description.trimmingCharacters(in: .whitespacesAndNewlines)
                    attributeName = desc
                }
                
                guard let attrName = attributeName else { continue }
                
                let knotType: KnotType?
                if attrName == "ChimeraMultiKnot" {
                    knotType = .multiKnot
                } else if attrName == "ChimeraMapKnot" {
                    knotType = .mapKnot
                } else {
                    continue
                }
                
                // Extract parameters
                if let arguments = customAttr.arguments?.as(LabeledExprListSyntax.self),
                   let type = knotType {
                    return extractKnotFromArguments(arguments, knotType: type)
                }
            }
        }
        return nil
    }
    
    // MARK: - Argument Extraction
    
    /// Extract knot parameters from attribute arguments
    private func extractKnotFromArguments(_ arguments: LabeledExprListSyntax, knotType: KnotType) -> KnotInfo? {
        var schemaId: String?
        var subSchemas: [String] = []
        
        for argument in arguments {
            let label = argument.label?.text
            
            // Get the string representation of the expression
            let exprString = argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Parse using regex: "paramName = value"
            if exprString.contains("=") {
                let parts = exprString.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if parts.count >= 2 {
                    let paramName = parts[0]
                    let valueString = parts[1...].joined(separator: "=") // Rejoin in case value contains =
                    
                    if paramName == "schemaId" {
                        // Extract string value
                        if valueString.hasPrefix("\"") && valueString.hasSuffix("\"") {
                            let startIndex = valueString.index(after: valueString.startIndex)
                            let endIndex = valueString.index(before: valueString.endIndex)
                            schemaId = String(valueString[startIndex..<endIndex])
                        }
                    } else if paramName == "subSchemas" {
                        // Extract array value
                        subSchemas = parseSubSchemasFromString(valueString)
                    }
                }
            }
            // Also try the original approach (label: value)
            else if label == "schemaId" {
                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                    schemaId = stringLiteral.segments.compactMap { segment in
                        if case .stringSegment(let stringSegment) = segment {
                            return stringSegment.content.text
                        }
                        return nil
                    }.joined()
                }
            } else if label == "subSchemas" {
                if let arrayExpr = argument.expression.as(ArrayExprSyntax.self) {
                    subSchemas = extractSubSchemasFromArray(arrayExpr)
                }
            }
        }
        
        guard let id = schemaId else { return nil }
        return KnotInfo(schemaId: id, subSchemas: subSchemas, knotType: knotType)
    }
    
    /// Parse subSchemas from string representation
    private func parseSubSchemasFromString(_ arrayString: String) -> [String] {
        var schemas: [String] = []
        
        // Remove brackets and split by commas
        let cleaned = arrayString.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let items = cleaned.components(separatedBy: ",")
        
        for item in items {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            // Handle TypeName.class format
            if let dotIndex = trimmed.firstIndex(of: ".") {
                let typeName = String(trimmed[..<dotIndex])
                if !typeName.isEmpty {
                    schemas.append(typeName)
                }
            } else if !trimmed.isEmpty {
                schemas.append(trimmed)
            }
        }
        
        return schemas
    }
    
    /// Extract subSchemas from array expression
    private func extractSubSchemasFromArray(_ arrayExpr: ArrayExprSyntax) -> [String] {
        var schemas: [String] = []
        
        for element in arrayExpr.elements {
            // Handle TypeName.class or TypeName.self format
            if let memberAccess = element.expression.as(MemberAccessExprSyntax.self),
               let baseType = memberAccess.base?.as(DeclReferenceExprSyntax.self) {
                let memberName = memberAccess.declName.baseName.text
                if memberName == "class" || memberName == "self" {
                    schemas.append(baseType.baseName.text)
                }
            }
            // Handle just TypeName
            else if let declRef = element.expression.as(DeclReferenceExprSyntax.self) {
                schemas.append(declRef.baseName.text)
            }
        }
        
        return schemas
    }
}
