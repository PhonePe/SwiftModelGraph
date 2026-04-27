import Foundation

/// Utility for working with file paths and URLs
struct PathResolver {
    /// Convert a file path string to a URL
    /// - Parameter path: The file path string
    /// - Returns: URL representing the file path
    static func fileURL(path: String) -> URL {
        return URL(fileURLWithPath: path)
    }
    
    /// Convert a file path string to a URL with a relative base
    /// - Parameters:
    ///   - path: The file path string
    ///   - baseURL: The base URL for relative resolution
    /// - Returns: URL representing the file path relative to base
    static func fileURL(path: String, relativeTo baseURL: URL) -> URL {
        return URL(fileURLWithPath: path, relativeTo: baseURL)
    }
    
    /// Append a path component to a URL
    /// - Parameters:
    ///   - url: The base URL
    ///   - component: The path component to append
    /// - Returns: New URL with component appended
    static func appendingPathComponent(_ component: String, to url: URL) -> URL {
        return url.appendingPathComponent(component)
    }
    
    /// Append a path component to a path string
    /// - Parameters:
    ///   - path: The base path string
    ///   - component: The path component to append
    /// - Returns: New path string with component appended
    static func appendingPathComponent(_ component: String, to path: String) -> String {
        return (path as NSString).appendingPathComponent(component)
    }
    
    /// Get the home directory for the current user
    /// - Returns: URL for the user's home directory
    static func homeDirectory() -> URL {
        return FileManager.default.homeDirectoryForCurrentUser
    }
    
    /// Get the temporary directory
    /// - Returns: URL for the temporary directory
    static func temporaryDirectory() -> URL {
        return FileManager.default.temporaryDirectory
    }
    
    /// Get the path extension from a URL
    /// - Parameter url: The URL
    /// - Returns: The file extension (without the dot)
    static func pathExtension(of url: URL) -> String {
        return url.pathExtension
    }
    
    /// Get the path string from a URL
    /// - Parameter url: The URL
    /// - Returns: The path string
    static func path(from url: URL) -> String {
        return url.path
    }
}
