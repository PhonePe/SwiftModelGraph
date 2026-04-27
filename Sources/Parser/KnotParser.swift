import Foundation
import SwiftSyntax
import SwiftParser

/// Type of knot annotation
enum KnotType: String {
    case multiKnot = "MultiKnot"
    case mapKnot = "MapKnot"
}

/// Result of parsing a knot annotation
struct KnotInfo {
    let schemaId: String
    let subSchemas: [String]
    let knotType: KnotType
}

/// Parser for extracting @ChimeraMultiKnot and @ChimeraMapKnot annotation information
class KnotParser {
    
    /// Extract knot annotation from a type
    /// - Parameters:
    ///   - filePath: Absolute path to the source file
    ///   - typeName: Name of the type (struct/class)
    /// - Returns: KnotInfo if found, nil otherwise
    static func extractKnotAnnotation(from filePath: String, typeName: String) -> KnotInfo? {
        guard let sourceCode = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return nil
        }
        
        let sourceFile = Parser.parse(source: sourceCode)
        let visitor = KnotVisitor(targetTypeName: typeName)
        visitor.walk(sourceFile)
        
        return visitor.knotInfo
    }
    
    /// Parse knot annotation using regex (fallback)
    static func extractKnotAnnotationRegex(from filePath: String, typeName: String) -> KnotInfo? {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return nil
        }
        
        let lines = content.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            // Skip commented lines
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("//") {
                continue
            }
            
            // Check for knot annotations
            if line.contains("@ChimeraMultiKnot") || line.contains("@ChimeraMapKnot") {
                let knotType: KnotType = line.contains("@ChimeraMultiKnot") ? .multiKnot : .mapKnot
                
                // Check if next line(s) contain the target type
                let nextLines = lines.dropFirst(index + 1).prefix(3).joined(separator: " ")
                if nextLines.contains("\\b\(typeName)\\b") {
                    // Parse the annotation
                    if let info = parseKnotAnnotation(line, knotType: knotType) {
                        return info
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    /// Parse knot annotation string
    private static func parseKnotAnnotation(_ annotation: String, knotType: KnotType) -> KnotInfo? {
        // Extract schemaId
        let schemaIdPattern = #"schemaId\s*=\s*"([^"]*)""#
        guard let schemaIdRegex = try? NSRegularExpression(pattern: schemaIdPattern),
              let schemaIdMatch = schemaIdRegex.firstMatch(
                in: annotation,
                range: NSRange(annotation.startIndex..<annotation.endIndex, in: annotation)
              ),
              let schemaIdRange = Range(schemaIdMatch.range(at: 1), in: annotation) else {
            return nil
        }
        
        let schemaId = String(annotation[schemaIdRange])
        
        // Extract subSchemas array
        let subSchemasPattern = #"subSchemas\s*=\s*\[([^\]]*)\]"#
        guard let subSchemasRegex = try? NSRegularExpression(pattern: subSchemasPattern),
              let subSchemasMatch = subSchemasRegex.firstMatch(
                in: annotation,
                range: NSRange(annotation.startIndex..<annotation.endIndex, in: annotation)
              ),
              let subSchemasRange = Range(subSchemasMatch.range(at: 1), in: annotation) else {
            return KnotInfo(schemaId: schemaId, subSchemas: [], knotType: knotType)
        }
        
        let subSchemasString = String(annotation[subSchemasRange])
        let subSchemas = parseSubSchemas(subSchemasString)
        
        return KnotInfo(schemaId: schemaId, subSchemas: subSchemas, knotType: knotType)
    }
    
    /// Parse subSchemas array string like "FeatureConfig1.class, FeatureConfig2.class" or "Type.self"
    private static func parseSubSchemas(_ subSchemasString: String) -> [String] {
        var schemas: [String] = []
        
        // Pattern: TypeName.class, TypeName.self, or just TypeName
        let pattern = #"(\w+)(?:\.(?:class|self))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return schemas
        }
        
        let matches = regex.matches(
            in: subSchemasString,
            range: NSRange(subSchemasString.startIndex..<subSchemasString.endIndex, in: subSchemasString)
        )
        
        for match in matches {
            guard let typeRange = Range(match.range(at: 1), in: subSchemasString) else {
                continue
            }
            let typeName = String(subSchemasString[typeRange])
            if !typeName.isEmpty && typeName != "class" && typeName != "self" {
                schemas.append(typeName)
            }
        }
        
        return schemas
    }
}
