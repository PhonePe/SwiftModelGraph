import Foundation
import SwiftSyntax
import SwiftParser

/// Result of parsing @PolymorphicMapping annotation
struct PolymorphicMapping {
    let discriminatorKey: String
    let variants: [String: String]  // discriminator value -> type name
}

/// Parser for extracting @PolymorphicMapping annotation information
class PolymorphicParser {
    
    /// Internal result type for parsing (before schema expansion)
    struct ParsedPolymorphicMapping {
        let discriminatorKey: String
        let variants: [String: String]  // discriminator value -> type name
        let isProtocol: Bool
        let schemaId: String?  // For @ChimeraPolymorphic annotations
    }
    
    /// Extract @PolymorphicMapping annotation from a property
    /// - Parameters:
    ///   - filePath: Absolute path to the source file
    ///   - typeName: Name of the type containing the property
    ///   - propertyName: Name of the property to check
    /// - Returns: ParsedPolymorphicMapping if found, nil otherwise
    static func extractPolymorphicMapping(
        from filePath: String,
        typeName: String,
        propertyName: String
    ) -> ParsedPolymorphicMapping? {
        guard let sourceCode = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return nil
        }
        
        let sourceFile = Parser.parse(source: sourceCode)
        
        let visitor = PolymorphicVisitor(targetTypeName: typeName, targetPropertyName: propertyName)
        visitor.walk(sourceFile)
        
        if let mapping = visitor.polymorphicMapping {
            return ParsedPolymorphicMapping(
                discriminatorKey: mapping.discriminatorKey,
                variants: mapping.variants,
                isProtocol: false,
                schemaId: nil
            )
        }
        
        return nil
    }
    
    /// Extract @ChimeraPolymorphic annotation from a type declaration
    /// - Parameters:
    ///   - filePath: Absolute path to the source file
    ///   - typeName: Name of the type to check for the annotation
    /// - Returns: ParsedPolymorphicMapping if found, nil otherwise
    static func extractChimeraPolymorphicMapping(
        from filePath: String,
        typeName: String
    ) -> ParsedPolymorphicMapping? {
        guard let sourceCode = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return nil
        }
        
        let sourceFile = Parser.parse(source: sourceCode)
        
        let visitor = ChimeraPolymorphicVisitor(targetTypeName: typeName)
        visitor.walk(sourceFile)
        
        return visitor.polymorphicMapping
    }
    
    /// Extract @ChimeraSchema annotation key from a type declaration
    /// -Parameters:
    ///   - filePath: Absolute path to the source file
    ///   - typeName: Name of the type to check for the annotation
    /// - Returns: Schema key string if found, nil otherwise
    static func extractChimeraSchemaKey(
        from filePath: String,
        typeName: String
    ) -> String? {
        guard let sourceCode = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return nil
        }
        
        let sourceFile = Parser.parse(source: sourceCode)
        
        let visitor = ChimeraSchemaTypeVisitor(targetTypeName: typeName)
        visitor.walk(sourceFile)
        
        return visitor.schemaKey
    }
    
    /// Extract polymorphic mapping using regex (fallback)
    /// Pattern: @PolymorphicMapping(discriminator: "type", variants: ["dog": Dog.self, "cat": Cat.self])
    static func extractPolymorphicMappingRegex(
        from filePath: String,
        propertyName: String
    ) -> ParsedPolymorphicMapping? {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return nil
        }
        
        // Find the property with @PolymorphicMapping
        let lines = content.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            // Check if this line has @PolymorphicMapping
            if line.contains("@PolymorphicMapping") {
                // Check if next line(s) contain the property
                let nextLines = lines.dropFirst(index + 1).prefix(3).joined(separator: " ")
                if nextLines.contains("\\b\(propertyName)\\b") {
                    // Extract parameters from annotation
                    if let mapping = parsePolymorphicAnnotation(line) {
                        return ParsedPolymorphicMapping(
                            discriminatorKey: mapping.discriminatorKey,
                            variants: mapping.variants,
                            isProtocol: false,
                            schemaId: nil
                        )
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    /// Parse @PolymorphicMapping annotation string
    private static func parsePolymorphicAnnotation(_ annotation: String) -> ParsedPolymorphicMapping? {
        // Extract discriminator key
        let discriminatorPattern = #"discriminator:\s*"([^"]*)""#
        guard let discriminatorRegex = try? NSRegularExpression(pattern: discriminatorPattern),
              let discriminatorMatch = discriminatorRegex.firstMatch(
                in: annotation,
                range: NSRange(annotation.startIndex..<annotation.endIndex, in: annotation)
              ),
              let discriminatorRange = Range(discriminatorMatch.range(at: 1), in: annotation) else {
            return nil
        }
        
        let discriminatorKey = String(annotation[discriminatorRange])
        
        // Extract variants
        let variantsPattern = #"variants:\s*\[([^\]]*)\]"#
        guard let variantsRegex = try? NSRegularExpression(pattern: variantsPattern),
              let variantsMatch = variantsRegex.firstMatch(
                in: annotation,
                range: NSRange(annotation.startIndex..<annotation.endIndex, in: annotation)
              ),
              let variantsRange = Range(variantsMatch.range(at: 1), in: annotation) else {
            return ParsedPolymorphicMapping(discriminatorKey: discriminatorKey, variants: [:], isProtocol: false, schemaId: nil)
        }
        
        let variantsString = String(annotation[variantsRange])
        let variants = parseVariants(variantsString)
        
        return ParsedPolymorphicMapping(discriminatorKey: discriminatorKey, variants: variants, isProtocol: false, schemaId: nil)
    }
    
    /// Parse variants string like "dog": Dog.self, "cat": Cat.self
    private static func parseVariants(_ variantsString: String) -> [String: String] {
        var variants: [String: String] = [:]
        
        // Pattern: "value": Type.self
        let pattern = #""([^"]*)"\s*:\s*(\w+)\.self"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return variants
        }
        
        let matches = regex.matches(
            in: variantsString,
            range: NSRange(variantsString.startIndex..<variantsString.endIndex, in: variantsString)
        )
        
        for match in matches {
            guard match.numberOfRanges >= 3,
                  let keyRange = Range(match.range(at: 1), in: variantsString),
                  let typeRange = Range(match.range(at: 2), in: variantsString) else {
                continue
            }
            
            let key = String(variantsString[keyRange])
            let typeName = String(variantsString[typeRange])
            variants[key] = typeName
        }
        
        return variants
    }
}
