import Foundation

/// Repository for reading source file contents from the file system
struct SourceFileRepository {
    private let logger: Logger
    
    init(logger: Logger = Logger(verbose: false)) {
        self.logger = logger
    }
    
    /// Read the contents of a source file
    /// - Parameter filePath: The absolute path to the file
    /// - Returns: The file contents as a string, or nil if reading fails
    func readFile(at filePath: String) -> String? {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            logger.warning("Failed to read file: \(filePath)")
            return nil
        }
        return content
    }
    
    /// Read the contents of a source file from a URL
    /// - Parameter url: The file URL
    /// - Returns: The file contents as a string, or nil if reading fails
    func readFile(at url: URL) -> String? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            logger.warning("Failed to read file: \(url.path)")
            return nil
        }
        return content
    }
    
    /// Read the contents of a source file, throwing an error on failure
    /// - Parameter filePath: The absolute path to the file
    /// - Returns: The file contents as a string
    /// - Throws: Error if the file cannot be read
    func readFileOrThrow(at filePath: String) throws -> String {
        return try String(contentsOfFile: filePath, encoding: .utf8)
    }
    
    /// Read the contents of a source file from a URL, throwing an error on failure
    /// - Parameter url: The file URL
    /// - Returns: The file contents as a string
    /// - Throws: Error if the file cannot be read
    func readFileOrThrow(at url: URL) throws -> String {
        return try String(contentsOf: url, encoding: .utf8)
    }
    
    /// Check if a file is readable (exists and can be opened)
    /// - Parameter filePath: The absolute path to the file
    /// - Returns: True if the file can be read, false otherwise
    func isReadable(filePath: String) -> Bool {
        let fileManager = FileManager.default
        return fileManager.isReadableFile(atPath: filePath)
    }
    
    /// Read multiple files in batch
    /// - Parameter filePaths: Array of file paths to read
    /// - Returns: Dictionary mapping file paths to their contents (only successful reads included)
    func readFiles(at filePaths: [String]) -> [String: String] {
        var results: [String: String] = [:]
        for path in filePaths {
            if let content = readFile(at: path) {
                results[path] = content
            }
        }
        return results
    }
}
