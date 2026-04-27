import Foundation

/// Utility for scanning and enumerating files in the file system
struct FileScanner {
    private let logger: Logger
    
    init(logger: Logger = Logger(verbose: false)) {
        self.logger = logger
    }
    
    /// Scan a directory recursively for Swift files
    /// - Parameters:
    ///   - directoryPath: The root directory path to scan
    ///   - skipPackageDescendants: Whether to skip Swift package directories
    ///   - excludedDirs: Set of directory names to exclude from scanning
    /// - Returns: Array of URLs for all .swift files found
    func findSwiftFiles(
        in directoryPath: String,
        skipPackageDescendants: Bool = false,
        excludedDirs: Set<String> = []
    ) -> [URL] {
        var swiftFiles: [URL] = []
        let fileManager = FileManager.default
        
        var options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
        if skipPackageDescendants {
            options.insert(.skipsPackageDescendants)
        }
        
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: directoryPath),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: options
        ) else {
            logger.warning("Could not enumerate directory: \(directoryPath)")
            return swiftFiles
        }
        
        for case let fileURL as URL in enumerator {
            // Skip excluded directories
            if !excludedDirs.isEmpty {
                let pathComponents = fileURL.pathComponents
                if pathComponents.contains(where: { excludedDirs.contains($0) }) {
                    continue
                }
            }
            if fileURL.pathExtension == "swift" {
                swiftFiles.append(fileURL)
            }
        }
        
        logger.debug("Found \(swiftFiles.count) Swift files in \(directoryPath)")
        return swiftFiles
    }
    
    /// Check if a file exists at the given path
    /// - Parameter path: The file path to check
    /// - Returns: True if file exists, false otherwise
    func fileExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    /// Get directory contents
    /// - Parameters:
    ///   - directoryURL: The directory URL
    ///   - keys: Resource keys to include in the results
    ///   - options: Directory enumeration options
    /// - Returns: Array of URLs for directory contents
    /// - Throws: Error if directory cannot be read
    func contentsOfDirectory(
        at directoryURL: URL,
        includingPropertiesForKeys keys: [URLResourceKey]? = nil,
        options: FileManager.DirectoryEnumerationOptions = []
    ) throws -> [URL] {
        return try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: keys,
            options: options
        )
    }
    
    /// Get file attributes
    /// - Parameter path: The file path
    /// - Returns: Dictionary of file attributes
    /// - Throws: Error if attributes cannot be retrieved
    func attributesOfItem(at path: String) throws -> [FileAttributeKey: Any] {
        return try FileManager.default.attributesOfItem(atPath: path)
    }
}
