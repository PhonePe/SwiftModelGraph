import Foundation

/// Information about an enum case
struct EnumCaseInfo: Codable {
    /// The case name
    let name: String
    
    /// Associated value types (if any)
    let associatedValues: [String]
    
    /// Raw value (if any)
    let rawValue: String?
}
