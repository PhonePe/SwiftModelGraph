import Foundation

/// Utility functions for type checking and classification
enum TypeUtilities {
    
    /// Check if a type name is a system type (Foundation, UIKit, etc.)
    /// - Parameter typeName: The type name to check
    /// - Returns: True if it's a system type
    static func isSystemType(_ typeName: String) -> Bool {
        let systemPrefixes = ["NS", "UI", "CG", "CF", "CA", "AV", "MK", "SC", "SK", "WK"]
        
        // Check if starts with system prefix
        for prefix in systemPrefixes {
            if typeName.hasPrefix(prefix) {
                return true
            }
        }
        
        // Common system types without prefixes
        let systemTypes: Set<String> = [
            "Equatable", "Hashable", "Comparable",
            "Codable", "Encodable", "Decodable",
            "CustomStringConvertible", "CustomDebugStringConvertible",
            "Error", "LocalizedError",
            "RawRepresentable", "CaseIterable",
            "Identifiable", "ObservableObject",
            "View", "ViewModifier" // SwiftUI
        ]
        
        return systemTypes.contains(typeName)
    }
    
    /// Check if a type name is a known Swift primitive or Foundation type
    /// - Parameter typeName: The type name to check
    /// - Returns: True if it's a primitive type
    static func isPrimitiveType(_ typeName: String) -> Bool {
        let primitiveTypes: Set<String> = [
            // Swift Standard Library
            "Int", "Int8", "Int16", "Int32", "Int64",
            "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
            "Float", "Double", "Float16", "Float80",
            "Bool",
            "String", "Character", "Substring",
            "Void", "Never",
            "Any", "AnyObject", "AnyHashable",
            
            // Foundation
            "Date", "Data", "URL", "UUID",
            "Decimal", "NSNumber", "NSString",
            "TimeInterval", "DateInterval",
            "Locale", "Calendar", "TimeZone",
            
            // Collections (generic containers themselves)
            "Array", "Set", "Dictionary",
            "Optional",
            
            // Common type aliases
            "CGFloat", "CGPoint", "CGSize", "CGRect",
            "NSInteger", "NSUInteger"
        ]
        
        return primitiveTypes.contains(typeName)
    }
}
