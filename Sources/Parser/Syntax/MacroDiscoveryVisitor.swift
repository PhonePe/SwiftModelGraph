import Foundation
import SwiftSyntax

/// A SyntaxVisitor that discovers macro annotations on type declarations
/// Uses SwiftSyntax AST to accurately detect macros, avoiding regex pitfalls like:
/// - False positives in strings/comments
/// - Multi-line attributes
/// - Nested parentheses in parameters
class MacroDiscoveryVisitor: SyntaxVisitor {
    /// The collected macro usages
    private(set) var discoveries: [MacroUsage] = []
    
    /// The macro name we're searching for (e.g., "ChimeraSchema")
    private let targetMacroName: String
    
    /// The file path being analyzed
    private let currentFilePath: String
    
    /// Logger for debugging
    private let logger: Logger?
    
    /// Track the current type being visited (for property-level annotations)
    private var currentTypeName: String?
    private var currentTypePosition: AbsolutePosition?
    
    /// Track which types have property-level annotations (to avoid duplicate discoveries)
    private var typesWithPropertyLevelAnnotations: Set<String> = []
    
    /// Initialize visitor
    /// - Parameters:
    ///   - targetMacro: The macro name to search for (without @ symbol)
    ///   - filePath: The file path being analyzed
    ///   - logger: Optional logger for debugging
    init(targetMacro: String, filePath: String, logger: Logger? = nil) {
        self.targetMacroName = targetMacro
        self.currentFilePath = filePath
        self.logger = logger
        super.init(viewMode: .sourceAccurate)
    }
    
    // MARK: - Visit Type Declarations
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        currentTypeName = node.name.text
        currentTypePosition = node.positionAfterSkippingLeadingTrivia
        
        checkForMacro(in: node.attributes, declName: node.name.text, position: node.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }
    
    override func visitPost(_ node: StructDeclSyntax) {
        currentTypeName = nil
        currentTypePosition = nil
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        currentTypeName = node.name.text
        currentTypePosition = node.positionAfterSkippingLeadingTrivia
        
        checkForMacro(in: node.attributes, declName: node.name.text, position: node.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }
    
    override func visitPost(_ node: ClassDeclSyntax) {
        currentTypeName = nil
        currentTypePosition = nil
    }
    
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        checkForMacro(in: node.attributes, declName: node.name.text, position: node.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }
    
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        checkForMacro(in: node.attributes, declName: node.name.text, position: node.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }
    
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        checkForMacro(in: node.attributes, declName: node.name.text, position: node.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }
    
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        // For extensions, use the extended type name
        let typeName = node.extendedType.trimmedDescription
        checkForMacro(in: node.attributes, declName: "extension \(typeName)", position: node.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }
    
    // MARK: - Visit Property Declarations (for property-level annotations)
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        // Only check properties inside a type
        guard let typeName = currentTypeName, let typePosition = currentTypePosition else {
            return .skipChildren
        }
        
        // Check if this property has the target macro
        let hasTargetMacro = node.attributes.contains { attribute in
            guard case .attribute(let attr) = attribute else { return false }
            let attrName = attr.attributeName.trimmedDescription
            return attrName == targetMacroName || attrName.hasSuffix(".\(targetMacroName)")
        }
        
        if hasTargetMacro && !typesWithPropertyLevelAnnotations.contains(typeName) {
            logger?.debug("    ✓ Found property-level @\(targetMacroName) in type: \(typeName)")
            
            // Add the parent type as a discovery point (so it gets processed)
            // Use empty parameters since property-level schemas don't have type-level parameters
            let (line, column) = convertPositionToLineColumn(typePosition)
            discoveries.append(MacroUsage(
                filePath: currentFilePath,
                line: line,
                column: column,
                parameters: [:]  // Empty parameters for property-level schemas
            ))
            
            typesWithPropertyLevelAnnotations.insert(typeName)
        }
        
        return .skipChildren
    }
    
    // MARK: - Macro Detection
    
    /// Check if the given attributes contain our target macro
    private func checkForMacro(
        in attributes: AttributeListSyntax?,
        declName: String,
        position: AbsolutePosition
    ) {
        guard let attributes = attributes else { return }
        
        for attribute in attributes {
            // AttributeListSyntax can contain either attributes or #if directives
            guard case .attribute(let attr) = attribute else { continue }
            
            // Check if this is our target macro
            // The attributeName can be various types: simple identifier, member access, etc.
            let attrName = attr.attributeName.trimmedDescription
            
            // Log what we're checking (verbose mode)
            logger?.debug("  Checking attribute '@\(attrName)' on \(declName) (target: '@\(targetMacroName)')")
            
            // Match the macro name - handle both simple names and qualified names
            // e.g., both "ChimeraSchema" and "Some.Module.ChimeraSchema" should match
            let matches = attrName == targetMacroName || attrName.hasSuffix("."+targetMacroName)
            
            if matches {
                logger?.debug("    ✓ MATCH! Found @\(attrName)")
                
                // Extract parameters from the attribute
                let parameters = extractParameters(from: attr.arguments)
                
                // Convert position to line/column
                let location = attr.positionAfterSkippingLeadingTrivia
                let (line, column) = convertPositionToLineColumn(location)
                
                discoveries.append(MacroUsage(
                    filePath: currentFilePath,
                    line: line,
                    column: column,
                    parameters: parameters
                ))
            }
        }
    }
    
    // MARK: - Parameter Extraction
    
    /// Extract parameters from macro arguments
    private func extractParameters(from args: AttributeSyntax.Arguments?) -> [String: Any] {
        var params: [String: Any] = [:]
        
        guard let args = args else { return params }
        
        // Handle labeled argument list: @Macro(key: "value", array: ["a", "b"])
        if case .argumentList(let list) = args {
            for arg in list {
                // Get parameter label
                let label = arg.label?.text ?? ""
                
                // Extract value from expression
                let value = extractValue(from: arg.expression)
                params[label] = value
            }
        }
        
        return params
    }
    
    /// Extract value from an expression syntax node
    private func extractValue(from expr: ExprSyntax) -> Any {
        // Handle string literals: "value"
        if let stringLiteral = expr.as(StringLiteralExprSyntax.self) {
            return extractStringLiteral(stringLiteral)
        }
        
        // Handle integer literals: 42
        if let intLiteral = expr.as(IntegerLiteralExprSyntax.self) {
            if let intValue = Int(intLiteral.literal.text) {
                return intValue
            }
        }
        
        // Handle float literals: 3.14
        if let floatLiteral = expr.as(FloatLiteralExprSyntax.self) {
            if let doubleValue = Double(floatLiteral.literal.text) {
                return doubleValue
            }
        }
        
        // Handle boolean literals: true/false
        if let boolLiteral = expr.as(BooleanLiteralExprSyntax.self) {
            return boolLiteral.literal.text == "true"
        }
        
        // Handle array expressions: ["a", "b"]
        if let arrayExpr = expr.as(ArrayExprSyntax.self) {
            return extractArray(from: arrayExpr)
        }
        
        // Handle dictionary expressions: ["key": "value"]
        if let dictExpr = expr.as(DictionaryExprSyntax.self) {
            return extractDictionary(from: dictExpr)
        }
        
        // Fallback: return string representation
        return expr.trimmedDescription
    }
    
    /// Extract string from string literal (handling multi-segment strings)
    private func extractStringLiteral(_ stringLiteral: StringLiteralExprSyntax) -> String {
        var result = ""
        for segment in stringLiteral.segments {
            if case .stringSegment(let stringSegment) = segment {
                result += stringSegment.content.text
            }
        }
        return result
    }
    
    /// Extract array from array expression
    private func extractArray(from arrayExpr: ArrayExprSyntax) -> [Any] {
        var result: [Any] = []
        for element in arrayExpr.elements {
            result.append(extractValue(from: element.expression))
        }
        return result
    }
    
    /// Extract dictionary from dictionary expression
    private func extractDictionary(from dictExpr: DictionaryExprSyntax) -> [String: Any] {
        var result: [String: Any] = [:]
        
        // Check if this is a dictionary (not an empty [:])
        guard case .elements(let elements) = dictExpr.content else {
            return result
        }
        
        for element in elements {
            // Extract key (must be string literal)
            if let keyExpr = element.key.as(StringLiteralExprSyntax.self) {
                let key = extractStringLiteral(keyExpr)
                let value = extractValue(from: element.value)
                result[key] = value
            } else {
                // For non-string keys, use the description
                let key = element.key.trimmedDescription
                let value = extractValue(from: element.value)
                result[key] = value
            }
        }
        
        return result
    }
    
    // MARK: - Position Conversion
    
    /// Convert AbsolutePosition to line and column numbers (1-based)
    /// Note: This is a simplified version. For accurate line/column,
    /// we'd need to track the source file's line table.
    /// For now, we approximate based on position.
    private func convertPositionToLineColumn(_ position: AbsolutePosition) -> (line: Int, column: Int) {
        // This is a simplified implementation
        // In production, you'd use SourceLocationConverter from SwiftSyntax
        // For now, return position as line (will be improved with proper line tracking)
        let offset = position.utf8Offset
        
        // Read the file and count lines up to this position
        guard let content = try? String(contentsOfFile: currentFilePath, encoding: .utf8) else {
            return (1, 1)
        }
        
        var line = 1
        var column = 1
        var currentOffset = 0
        
        for char in content.utf8 {
            if currentOffset >= offset {
                break
            }
            
            if char == UInt8(ascii: "\n") {
                line += 1
                column = 1
            } else {
                column += 1
            }
            
            currentOffset += 1
        }
        
        return (line, column)
    }
}
