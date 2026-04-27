import Foundation
import SwiftSyntax
import SwiftParser

/// Utility class to parse Swift files and extract properties
class SwiftFileParser {
    private let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    /// Parse a Swift file and extract properties from a specific type
    /// - Parameters:
    ///   - filePath: Path to the Swift source file
    ///   - typeName: The struct/class name to extract properties from
    /// - Returns: Tuple of (properties, enumCases)
    func extractProperties(fromFile filePath: String, typeName: String) throws -> (properties: [ExtractedProperty], enumCases: [EnumCaseInfo]) {
        let url = URL(fileURLWithPath: filePath)
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw GraphGeneratorError.sourceFileNotFound(filePath)
        }
        
        let sourceCode = try String(contentsOf: url, encoding: .utf8)
        return try extractProperties(from: sourceCode, typeName: typeName)
    }
    
    /// Parse Swift source code and extract properties from a specific type
    /// - Parameters:
    ///   - sourceCode: The Swift source code string
    ///   - typeName: The struct/class name to extract properties from
    /// - Returns: Tuple of (properties, enumCases)
    func extractProperties(from sourceCode: String, typeName: String) throws -> (properties: [ExtractedProperty], enumCases: [EnumCaseInfo]) {
        let sourceFile = Parser.parse(source: sourceCode)
        
        let visitor = PropertyExtractorVisitor(targetTypeName: typeName)
        visitor.walk(sourceFile)
        
        logger.debug("Extracted \(visitor.properties.count) properties and \(visitor.enumCases.count) enum cases from \(typeName)")
        
        return (properties: visitor.properties, enumCases: visitor.enumCases)
    }
    
    /// Parse a Swift file and extract all types defined in it
    /// - Parameter filePath: Path to the Swift source file
    /// - Returns: Array of type names (structs and classes)
    func extractTypeNames(fromFile filePath: String) throws -> [String] {
        let url = URL(fileURLWithPath: filePath)
        let sourceCode = try String(contentsOf: url, encoding: .utf8)
        
        let sourceFile = Parser.parse(source: sourceCode)
        
        let visitor = TypeNameExtractorVisitor()
        visitor.walk(sourceFile)
        
        return visitor.typeNames
    }
}

/// Simple visitor to extract all type names from a file
class TypeNameExtractorVisitor: SyntaxVisitor {
    private(set) var typeNames: [String] = []
    
    init() {
        super.init(viewMode: .sourceAccurate)
    }
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        typeNames.append(node.name.text)
        return .visitChildren
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        typeNames.append(node.name.text)
        return .visitChildren
    }
    
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        typeNames.append(node.name.text)
        return .visitChildren
    }
}
