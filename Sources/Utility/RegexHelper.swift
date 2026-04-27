import Foundation

/// Utility for working with regular expressions
struct RegexHelper {
    /// Create a regular expression from a pattern
    /// - Parameters:
    ///   - pattern: The regex pattern string
    ///   - options: NSRegularExpression options
    /// - Returns: NSRegularExpression if pattern is valid, nil otherwise
    static func create(
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> NSRegularExpression? {
        return try? NSRegularExpression(pattern: pattern, options: options)
    }
    
    /// Extract all matches from a string
    /// - Parameters:
    ///   - regex: The regular expression
    ///   - string: The string to search in
    ///   - options: Matching options
    /// - Returns: Array of NSTextCheckingResult matches
    static func matches(
        regex: NSRegularExpression,
        in string: String,
        options: NSRegularExpression.MatchingOptions = []
    ) -> [NSTextCheckingResult] {
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        return regex.matches(in: string, options: options, range: range)
    }
    
    /// Get the first match from a string
    /// - Parameters:
    ///   - regex: The regular expression
    ///   - string: The string to search in
    ///   - options: Matching options
    /// - Returns: First NSTextCheckingResult match, or nil if no match found
    static func firstMatch(
        regex: NSRegularExpression,
        in string: String,
        options: NSRegularExpression.MatchingOptions = []
    ) -> NSTextCheckingResult? {
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        return regex.firstMatch(in: string, options: options, range: range)
    }
    
    /// Extract captured group text from a match
    /// - Parameters:
    ///   - match: The match result
    ///   - groupIndex: The capture group index (0 is the full match)
    ///   - string: The original string
    /// - Returns: The captured text, or nil if group doesn't exist
    static func capturedText(
        from match: NSTextCheckingResult,
        groupIndex: Int,
        in string: String
    ) -> String? {
        guard groupIndex < match.numberOfRanges,
              let range = Range(match.range(at: groupIndex), in: string) else {
            return nil
        }
        return String(string[range])
    }
}
