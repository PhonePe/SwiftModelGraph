import Foundation

/// Errors that can occur during model graph generation
enum GraphGeneratorError: Error, LocalizedError {
    case indexStoreNotFound(String)
    case failedToOpenIndex(String)
    case sourceFileNotFound(String)
    case parsingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .indexStoreNotFound(let message):
            return "Index store not found: \(message)"
        case .failedToOpenIndex(let message):
            return "Failed to open index: \(message)"
        case .sourceFileNotFound(let message):
            return "Source file not found: \(message)"
        case .parsingFailed(let message):
            return "Parsing failed: \(message)"
        }
    }
}
