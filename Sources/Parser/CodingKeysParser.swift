import Foundation
import SwiftSyntax
import SwiftParser

/// Parser for extracting CodingKeys mappings from Swift types
class CodingKeysParser {
    
    /// Extract CodingKeys mappings from a type definition
    /// - Parameters:
    ///   - filePath: Absolute path to the source file
    ///   - typeName: Name of the type to extract CodingKeys from
    /// - Returns: Dictionary mapping property names to JSON keys (nil value means no string mapping)
    static func extractCodingKeys(from filePath: String, typeName: String) -> [String: String?] {
        guard let sourceCode = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return [:]
        }
        
        let sourceFile = Parser.parse(source: sourceCode)
        
        // Single visitor handles both type declarations and extensions
        let visitor = CodingKeysVisitor(targetTypeName: typeName)
        visitor.walk(sourceFile)
        
        return visitor.codingKeys
    }
}
