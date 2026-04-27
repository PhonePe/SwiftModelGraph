import Foundation
import SwiftSyntax

/// Visitor that extracts property-level @ChimeraSchema annotations from a target type
/// in a single AST pass, returning a dictionary mapping property name to schema key.
class ChimeraSchemaPropertyVisitor: SyntaxVisitor {
    let targetTypeName: String

    /// All extracted schema keys, keyed by property name.
    /// Example: ["config": "slot_action_map1"]
    private(set) var propertySchemaKeys: [String: String] = [:]

    private var insideTargetType = false

    init(targetTypeName: String) {
        self.targetTypeName = targetTypeName
        super.init(viewMode: .sourceAccurate)
    }

    // MARK: - Type scope tracking

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

    // MARK: - Property annotation extraction

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard insideTargetType else { return .skipChildren }

        guard let binding = node.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
            return .skipChildren
        }
        let propertyName = pattern.identifier.text

        for attribute in node.attributes {
            guard case .attribute(let attr) = attribute else { continue }
            
            // Check if this is @ChimeraSchema - handle both simple and qualified names
            let attrName = attr.attributeName.trimmedDescription
            let isChimeraSchema = attrName == "ChimeraSchema" || attrName.hasSuffix(".ChimeraSchema")
            
            guard isChimeraSchema else { continue }

            // Extract the "key" parameter
            if let schemaKey = extractSchemaKey(from: attr.arguments) {
                propertySchemaKeys[propertyName] = schemaKey
            }
        }

        return .skipChildren
    }

    // MARK: - Parameter extraction

    /// Extract the "key" parameter from @ChimeraSchema(key: "...")
    private func extractSchemaKey(from args: AttributeSyntax.Arguments?) -> String? {
        guard let args = args else { return nil }
        
        // Handle labeled argument list: @ChimeraSchema(key: "value")
        if case .argumentList(let list) = args {
            for arg in list {
                if arg.label?.text == "key" {
                    return extractString(arg.expression)
                }
            }
        }
        
        return nil
    }

    /// Extract string from string literal expression
    private func extractString(_ expr: ExprSyntax) -> String? {
        guard let lit = expr.as(StringLiteralExprSyntax.self) else { return nil }
        return lit.segments.compactMap {
            if case .stringSegment(let s) = $0 { return s.content.text }
            return nil
        }.joined()
    }
}
