import Foundation
import SwiftSyntax
import SwiftParser

/// Parser for @ChimeraProperty annotations
class ChimeraPropertyParser {

    /// Extract all @ChimeraProperty annotations for properties in a type.
    /// Parses the file once and returns a dictionary keyed by property name.
    /// Only properties with @ChimeraProperty annotation will be included in the result.
    /// - Parameters:
    ///   - filePath: Absolute path to the source file
    ///   - typeName: The struct/class name to extract from
    /// - Returns: Dictionary of property name → ChimeraPropertyAnnotation
    static func extractPropertyAnnotations(
        from filePath: String,
        typeName: String
    ) -> [String: ChimeraPropertyAnnotation] {
        guard let sourceCode = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return [:]
        }

        // Quick pre-check: skip files that don't mention the annotation
        guard sourceCode.contains("@ChimeraProperty") else {
            return [:]
        }

        let sourceFile = Parser.parse(source: sourceCode)
        let visitor = ChimeraPropertyVisitor(targetTypeName: typeName)
        visitor.walk(sourceFile)
        return visitor.annotations
    }

    /// Extract the description from @ChimeraMetaData(description:) on a type declaration.
    /// This is called from SymbolProcessor when building a ModelNode for an annotated type.
    /// - Parameters:
    ///   - filePath: Absolute path to the source file
    ///   - typeName: The struct/class name to look at
    /// - Returns: The description string, or nil if @ChimeraMetaData is absent or has no description
    static func extractMetaDescription(
        from filePath: String,
        typeName: String
    ) -> String? {
        guard let sourceCode = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return nil
        }

        // Quick pre-check: skip files that don't mention the annotation
        guard sourceCode.contains("@ChimeraMetaData") else {
            return nil
        }

        let sourceFile = Parser.parse(source: sourceCode)
        let visitor = ChimeraMetaDataVisitor(targetTypeName: typeName)
        visitor.walk(sourceFile)
        return visitor.metaDescription
    }

    /// Extract property-level @ChimeraSchema annotations from a type.
    /// Returns a dictionary mapping property name to schema key.
    /// - Parameters:
    ///   - filePath: Absolute path to the source file
    ///   - typeName: The struct/class name to extract from
    /// - Returns: Dictionary of property name → schema key
    static func extractPropertyLevelSchemas(
        from filePath: String,
        typeName: String
    ) -> [String: String] {
        guard let sourceCode = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return [:]
        }

        // Quick pre-check: skip files that don't mention the annotation
        guard sourceCode.contains("@ChimeraSchema") else {
            return [:]
        }

        let sourceFile = Parser.parse(source: sourceCode)
        let visitor = ChimeraSchemaPropertyVisitor(targetTypeName: typeName)
        visitor.walk(sourceFile)
        return visitor.propertySchemaKeys
    }
}
