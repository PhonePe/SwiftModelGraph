import Foundation
import SwiftSyntax

/// Annotation data extracted from @ChimeraProperty(...)
struct ChimeraPropertyAnnotation {
    var key: String? = nil
    var description: String = ""
    var isDeprecated: Bool = false
    var regexPatterns: [String] = []
    /// Sentinel: -0.0 means "not provided"
    var min: Double = -0.0
    /// Sentinel: -0.0 means "not provided"
    var max: Double = -0.0
}

/// Visitor that extracts @ChimeraProperty annotations from all properties of a target type
/// in a single AST pass, returning a dictionary keyed by property name.
class ChimeraPropertyVisitor: SyntaxVisitor {
    let targetTypeName: String

    /// All extracted annotations, keyed by property name.
    private(set) var annotations: [String: ChimeraPropertyAnnotation] = [:]

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
            guard let customAttr = attribute.as(AttributeSyntax.self),
                  let attrName = customAttr.attributeName.as(IdentifierTypeSyntax.self),
                  attrName.name.text == "ChimeraProperty"
            else { continue }

            if let arguments = customAttr.arguments?.as(LabeledExprListSyntax.self) {
                annotations[propertyName] = extractAnnotation(from: arguments)
            } else {
                // @ChimeraProperty used without arguments — record with defaults
                annotations[propertyName] = ChimeraPropertyAnnotation()
            }
        }

        return .skipChildren
    }

    // MARK: - Argument extraction

    private func extractAnnotation(from arguments: LabeledExprListSyntax) -> ChimeraPropertyAnnotation {
        var result = ChimeraPropertyAnnotation()

        for argument in arguments {
            switch argument.label?.text {
            case "key":
                result.key = extractString(argument.expression)
            case "description":
                result.description = extractString(argument.expression) ?? ""
            case "isDeprecated":
                result.isDeprecated = extractBool(argument.expression) ?? false
            case "regex":
                result.regexPatterns = extractStringArray(argument.expression)
            case "min":
                result.min = extractDouble(argument.expression) ?? -0.0
            case "max":
                result.max = extractDouble(argument.expression) ?? -0.0
            default:
                break
            }
        }

        return result
    }

    private func extractString(_ expr: ExprSyntax) -> String? {
        guard let lit = expr.as(StringLiteralExprSyntax.self) else { return nil }
        return lit.segments.compactMap {
            if case .stringSegment(let s) = $0 { return s.content.text }
            return nil
        }.joined()
    }

    private func extractBool(_ expr: ExprSyntax) -> Bool? {
        guard let lit = expr.as(BooleanLiteralExprSyntax.self) else { return nil }
        return lit.literal.text == "true"
    }

    private func extractStringArray(_ expr: ExprSyntax) -> [String] {
        guard let arr = expr.as(ArrayExprSyntax.self) else { return [] }
        return arr.elements.compactMap { extractString($0.expression) }
    }

    /// Extract a Double from a literal expression, handling negative values.
    /// In the SwiftSyntax AST, -0.0 is PrefixOperatorExprSyntax("-", FloatLiteralExprSyntax("0.0")).
    private func extractDouble(_ expr: ExprSyntax) -> Double? {
        // Positive float literal: 3.14
        if let lit = expr.as(FloatLiteralExprSyntax.self) {
            return Double(lit.literal.text)
        }
        // Positive integer literal: 0, 100
        if let lit = expr.as(IntegerLiteralExprSyntax.self) {
            return Double(lit.literal.text)
        }
        // Negative literal: -0.0, -3.14, -1
        if let prefix = expr.as(PrefixOperatorExprSyntax.self),
           prefix.operator.text == "-",
           let inner = extractDouble(prefix.expression) {
            return -inner
        }
        return nil
    }
}
