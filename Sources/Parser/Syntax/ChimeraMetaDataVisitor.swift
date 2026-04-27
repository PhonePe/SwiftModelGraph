import Foundation
import SwiftSyntax

/// Visitor that extracts @ChimeraMetaData(description:) from a specific type declaration.
/// Scoped to find the annotation on the type itself, not on its members.
class ChimeraMetaDataVisitor: SyntaxVisitor {
    let targetTypeName: String

    /// The extracted description, if found.
    private(set) var metaDescription: String?

    init(targetTypeName: String) {
        self.targetTypeName = targetTypeName
        super.init(viewMode: .sourceAccurate)
    }

    // MARK: - Type declaration visits

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == targetTypeName {
            checkAttributes(node.attributes)
            return .skipChildren
        }
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == targetTypeName {
            checkAttributes(node.attributes)
            return .skipChildren
        }
        return .visitChildren
    }

    // MARK: - Attribute extraction

    private func checkAttributes(_ attributes: AttributeListSyntax?) {
        guard let attributes = attributes else { return }
        for attribute in attributes {
            guard let customAttr = attribute.as(AttributeSyntax.self),
                  let attrName = customAttr.attributeName.as(IdentifierTypeSyntax.self),
                  attrName.name.text == "ChimeraMetaData",
                  let arguments = customAttr.arguments?.as(LabeledExprListSyntax.self)
            else { continue }

            for arg in arguments {
                if arg.label?.text == "description",
                   let lit = arg.expression.as(StringLiteralExprSyntax.self) {
                    metaDescription = lit.segments.compactMap {
                        if case .stringSegment(let s) = $0 { return s.content.text }
                        return nil
                    }.joined()
                }
            }
        }
    }
}
