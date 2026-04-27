import Foundation
import SwiftSyntax

/// Visitor that extracts CodingKeys enum mappings from Swift types
class CodingKeysVisitor: SyntaxVisitor {
    /// The name of the type to extract CodingKeys from
    let targetTypeName: String
    
    /// The collected CodingKeys mappings (property name -> JSON key)
    private(set) var codingKeys: [String: String?] = [:]
    
    /// Track if we're inside the target type or its extension
    private var insideTarget = false
    
    init(targetTypeName: String) {
        self.targetTypeName = targetTypeName
        super.init(viewMode: .sourceAccurate)
    }
    
    // MARK: - Type Declaration Tracking
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == targetTypeName {
            insideTarget = true
            return .visitChildren
        }
        return .skipChildren
    }
    
    override func visitPost(_ node: StructDeclSyntax) {
        if node.name.text == targetTypeName {
            insideTarget = false
        }
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == targetTypeName {
            insideTarget = true
            return .visitChildren
        }
        return .skipChildren
    }
    
    override func visitPost(_ node: ClassDeclSyntax) {
        if node.name.text == targetTypeName {
            insideTarget = false
        }
    }
    
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let extendedType = node.extendedType.trimmedDescription
        if extendedType == targetTypeName {
            insideTarget = true
            return .visitChildren
        }
        return .skipChildren
    }
    
    override func visitPost(_ node: ExtensionDeclSyntax) {
        let extendedType = node.extendedType.trimmedDescription
        if extendedType == targetTypeName {
            insideTarget = false
        }
    }
    
    // MARK: - CodingKeys Extraction
    
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        guard insideTarget else { return .skipChildren }
        
        // Check if this is a CodingKeys enum
        if node.name.text == "CodingKeys" {
            // Check if it conforms to CodingKey protocol
            let conformsToCodingKey = node.inheritanceClause?.inheritedTypes.contains(where: { inherited in
                inherited.type.trimmedDescription.contains("CodingKey")
            }) ?? false
            
            if conformsToCodingKey {
                extractCodingKeysFromEnum(node)
            }
        }
        
        return .skipChildren
    }
    
    /// Extract CodingKeys mappings from an enum declaration
    private func extractCodingKeysFromEnum(_ enumDecl: EnumDeclSyntax) {
        for member in enumDecl.memberBlock.members {
            if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                for element in caseDecl.elements {
                    let caseName = element.name.text
                    
                    // Check if there's a raw value (string literal)
                    if let rawValue = element.rawValue?.value.as(StringLiteralExprSyntax.self) {
                        // Extract the string value
                        let stringValue = rawValue.segments.compactMap { segment -> String? in
                            if case .stringSegment(let stringSegment) = segment {
                                return stringSegment.content.text
                            }
                            return nil
                        }.joined()
                        
                        codingKeys[caseName] = stringValue
                    } else {
                        // No explicit raw value, set to nil to indicate no mapping
                        codingKeys[caseName] = nil
                    }
                }
            }
        }
    }
}
