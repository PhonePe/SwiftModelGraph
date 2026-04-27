import Foundation
import SwiftSyntax

/// Extracts enum case information from enum declarations
class EnumExtractor {
    
    /// Extract enum cases from an enum declaration
    /// - Parameter enumDecl: The enum declaration syntax node
    /// - Returns: Array of EnumCaseInfo
    func extractEnumCases(from enumDecl: EnumDeclSyntax) -> [EnumCaseInfo] {
        var enumCases: [EnumCaseInfo] = []
        
        // Extract enum cases
        for member in enumDecl.memberBlock.members {
            if let enumCase = member.decl.as(EnumCaseDeclSyntax.self) {
                for element in enumCase.elements {
                    let caseName = element.name.text
                    var associatedValues: [String] = []
                    
                    // Extract associated values
                    if let parameterClause = element.parameterClause {
                        for parameter in parameterClause.parameters {
                            let typeName = parameter.type.trimmedDescription
                            associatedValues.append(typeName)
                        }
                    }
                    
                    // Extract raw value
                    var rawValue: String?
                    if let initializer = element.rawValue {
                        rawValue = initializer.value.trimmedDescription
                    }
                    
                    enumCases.append(EnumCaseInfo(
                        name: caseName,
                        associatedValues: associatedValues,
                        rawValue: rawValue
                    ))
                }
            }
        }
        
        return enumCases
    }
}
