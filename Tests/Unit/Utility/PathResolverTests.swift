import XCTest
@testable import ModelGraphGenerator

final class PathResolverTests: XCTestCase {
    
    // MARK: - fileURL Tests
    
    func testFileURL_AbsolutePath() {
        let path = "/Users/test/file.swift"
        let url = PathResolver.fileURL(path: path)
        
        XCTAssertEqual(url.path, path, "Should create URL with correct path")
        XCTAssertTrue(url.isFileURL, "Should be a file URL")
    }
    
    func testFileURL_RelativePath() {
        let path = "relative/path/file.swift"
        let url = PathResolver.fileURL(path: path)
        
        XCTAssertTrue(url.isFileURL, "Should be a file URL")
        XCTAssertTrue(url.path.hasSuffix(path), "Path should end with relative path")
    }
    
    func testFileURL_EmptyPath() {
        let path = ""
        let url = PathResolver.fileURL(path: path)
        
        XCTAssertTrue(url.isFileURL, "Should be a file URL")
    }
    
    func testFileURL_WithRelativeBase() {
        let path = "file.swift"
        let baseURL = URL(fileURLWithPath: "/Users/test")
        let url = PathResolver.fileURL(path: path, relativeTo: baseURL)
        
        XCTAssertTrue(url.isFileURL, "Should be a file URL")
        XCTAssertNotNil(url.baseURL, "Should have base URL")
    }
    
    // MARK: - appendingPathComponent Tests
    
    func testAppendingPathComponent_ToURL() {
        let baseURL = URL(fileURLWithPath: "/Users/test")
        let url = PathResolver.appendingPathComponent("Documents", to: baseURL)
        
        XCTAssertEqual(url.path, "/Users/test/Documents", "Should append component correctly")
    }
    
    func testAppendingPathComponent_ToURLMultiple() {
        let baseURL = URL(fileURLWithPath: "/Users/test")
        let url1 = PathResolver.appendingPathComponent("Documents", to: baseURL)
        let url2 = PathResolver.appendingPathComponent("file.swift", to: url1)
        
        XCTAssertEqual(url2.path, "/Users/test/Documents/file.swift", "Should append multiple components")
    }
    
    func testAppendingPathComponent_ToURLWithTrailingSlash() {
        let baseURL = URL(fileURLWithPath: "/Users/test/")
        let url = PathResolver.appendingPathComponent("Documents", to: baseURL)
        
        XCTAssertEqual(url.path, "/Users/test/Documents", "Should handle trailing slash")
    }
    
    func testAppendingPathComponent_ToPathString() {
        let basePath = "/Users/test"
        let path = PathResolver.appendingPathComponent("Documents", to: basePath)
        
        XCTAssertEqual(path, "/Users/test/Documents", "Should append component to string path")
    }
    
    func testAppendingPathComponent_ToPathStringMultiple() {
        let basePath = "/Users/test"
        let path1 = PathResolver.appendingPathComponent("Documents", to: basePath)
        let path2 = PathResolver.appendingPathComponent("file.swift", to: path1)
        
        XCTAssertEqual(path2, "/Users/test/Documents/file.swift", "Should append multiple components to string")
    }
    
    func testAppendingPathComponent_ToEmptyPath() {
        let basePath = ""
        let path = PathResolver.appendingPathComponent("test", to: basePath)
        
        XCTAssertEqual(path, "test", "Should handle empty base path")
    }
    
    // MARK: - Directory Tests
    
    func testHomeDirectory() {
        let homeURL = PathResolver.homeDirectory()
        
        XCTAssertTrue(homeURL.isFileURL, "Should be a file URL")
        XCTAssertFalse(homeURL.path.isEmpty, "Home path should not be empty")
        XCTAssertTrue(FileManager.default.fileExists(atPath: homeURL.path), "Home directory should exist")
    }
    
    func testTemporaryDirectory() {
        let tempURL = PathResolver.temporaryDirectory()
        
        XCTAssertTrue(tempURL.isFileURL, "Should be a file URL")
        XCTAssertFalse(tempURL.path.isEmpty, "Temp path should not be empty")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path), "Temp directory should exist")
    }
    
    // MARK: - pathExtension Tests
    
    func testPathExtension_SwiftFile() {
        let url = URL(fileURLWithPath: "/Users/test/file.swift")
        let ext = PathResolver.pathExtension(of: url)
        
        XCTAssertEqual(ext, "swift", "Should extract swift extension")
    }
    
    func testPathExtension_MultipleDotsInPath() {
        let url = URL(fileURLWithPath: "/Users/test.user/file.swift")
        let ext = PathResolver.pathExtension(of: url)
        
        XCTAssertEqual(ext, "swift", "Should extract last extension only")
    }
    
    func testPathExtension_NoExtension() {
        let url = URL(fileURLWithPath: "/Users/test/file")
        let ext = PathResolver.pathExtension(of: url)
        
        XCTAssertEqual(ext, "", "Should return empty string for no extension")
    }
    
    func testPathExtension_HiddenFile() {
        let url = URL(fileURLWithPath: "/Users/test/.hidden")
        let ext = PathResolver.pathExtension(of: url)
        
        // macOS treats .hidden as a file without extension (the dot indicates hidden file)
        XCTAssertEqual(ext, "", "Should return empty for hidden file without extension")
    }
    
    func testPathExtension_Directory() {
        let url = URL(fileURLWithPath: "/Users/test/")
        let ext = PathResolver.pathExtension(of: url)
        
        XCTAssertEqual(ext, "", "Should return empty string for directory")
    }
    
    // MARK: - path Tests
    
    func testPath_FromURL() {
        let url = URL(fileURLWithPath: "/Users/test/file.swift")
        let path = PathResolver.path(from: url)
        
        XCTAssertEqual(path, "/Users/test/file.swift", "Should extract path from URL")
    }
    
    func testPath_FromURLWithComponents() {
        let baseURL = URL(fileURLWithPath: "/Users/test")
        let url = baseURL.appendingPathComponent("Documents").appendingPathComponent("file.swift")
        let path = PathResolver.path(from: url)
        
        XCTAssertEqual(path, "/Users/test/Documents/file.swift", "Should extract full path from URL")
    }
    
    // MARK: - Integration Tests
    
    func testIntegration_BuildComplexPath() {
        let home = PathResolver.homeDirectory()
        let derivedData = PathResolver.appendingPathComponent("Library", to: home)
        let developer = PathResolver.appendingPathComponent("Developer", to: derivedData)
        let xcode = PathResolver.appendingPathComponent("Xcode", to: developer)
        let path = PathResolver.path(from: xcode)
        
        XCTAssertTrue(path.contains("Library/Developer/Xcode"), "Should build complex nested path")
    }
    
    func testIntegration_CreateAndVerifyTempFile() throws {
        let tempDir = PathResolver.temporaryDirectory()
        let testDir = PathResolver.appendingPathComponent("PathResolverTest-\(UUID().uuidString)", to: tempDir)
        
        // Create directory
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        // Verify it exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: PathResolver.path(from: testDir)))
        
        // Create a file
        let testFile = PathResolver.appendingPathComponent("test.swift", to: testDir)
        try "// Test".write(to: testFile, atomically: true, encoding: .utf8)
        
        // Verify extension
        XCTAssertEqual(PathResolver.pathExtension(of: testFile), "swift")
        
        // Cleanup
        try FileManager.default.removeItem(at: testDir)
    }
    
    func testIntegration_PathStringConversion() {
        let pathString = "/Users/test/Documents"
        let url = PathResolver.fileURL(path: pathString)
        let convertedPath = PathResolver.path(from: url)
        
        XCTAssertEqual(pathString, convertedPath, "Round-trip conversion should preserve path")
    }
}
