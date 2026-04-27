import XCTest
@testable import ModelGraphGenerator

final class FileScannerTests: XCTestCase {
    var tempDirectory: URL!
    var fileScanner: FileScanner!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        fileScanner = FileScanner(logger: Logger(verbose: false))
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - findSwiftFiles Tests
    
    func testFindSwiftFiles_EmptyDirectory() {
        let files = fileScanner.findSwiftFiles(in: tempDirectory.path)
        XCTAssertEqual(files.count, 0, "Should find no files in empty directory")
    }
    
    func testFindSwiftFiles_WithSwiftFiles() throws {
        // Create test files
        let file1 = tempDirectory.appendingPathComponent("Test1.swift")
        let file2 = tempDirectory.appendingPathComponent("Test2.swift")
        let file3 = tempDirectory.appendingPathComponent("Test.txt")
        
        try "// Test".write(to: file1, atomically: true, encoding: .utf8)
        try "// Test".write(to: file2, atomically: true, encoding: .utf8)
        try "Test".write(to: file3, atomically: true, encoding: .utf8)
        
        let files = fileScanner.findSwiftFiles(in: tempDirectory.path)
        
        XCTAssertEqual(files.count, 2, "Should find exactly 2 Swift files")
        let fileNames = files.map { $0.lastPathComponent }
        XCTAssertTrue(fileNames.contains("Test1.swift"), "Should include Test1.swift")
        XCTAssertTrue(fileNames.contains("Test2.swift"), "Should include Test2.swift")
    }
    
    func testFindSwiftFiles_NestedDirectories() throws {
        // Create nested structure
        let subDir = tempDirectory.appendingPathComponent("SubDir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        let file1 = tempDirectory.appendingPathComponent("Root.swift")
        let file2 = subDir.appendingPathComponent("Nested.swift")
        
        try "// Test".write(to: file1, atomically: true, encoding: .utf8)
        try "// Test".write(to: file2, atomically: true, encoding: .utf8)
        
        let files = fileScanner.findSwiftFiles(in: tempDirectory.path)
        
        XCTAssertEqual(files.count, 2, "Should find files in nested directories")
        let fileNames = files.map { $0.lastPathComponent }
        XCTAssertTrue(fileNames.contains("Root.swift"), "Should include root file")
        XCTAssertTrue(fileNames.contains("Nested.swift"), "Should include nested file")
    }
    
    func testFindSwiftFiles_SkipsHiddenFiles() throws {
        let visibleFile = tempDirectory.appendingPathComponent("Visible.swift")
        let hiddenFile = tempDirectory.appendingPathComponent(".Hidden.swift")
        
        try "// Test".write(to: visibleFile, atomically: true, encoding: .utf8)
        try "// Test".write(to: hiddenFile, atomically: true, encoding: .utf8)
        
        let files = fileScanner.findSwiftFiles(in: tempDirectory.path)
        
        XCTAssertEqual(files.count, 1, "Should skip hidden files")
        let fileNames = files.map { $0.lastPathComponent }
        XCTAssertTrue(fileNames.contains("Visible.swift"), "Should include visible file")
        XCTAssertFalse(fileNames.contains(".Hidden.swift"), "Should skip hidden file")
    }
    
    func testFindSwiftFiles_NonExistentDirectory() {
        let files = fileScanner.findSwiftFiles(in: "/nonexistent/path")
        XCTAssertEqual(files.count, 0, "Should return empty array for non-existent directory")
    }
    
    // MARK: - fileExists Tests
    
    func testFileExists_ExistingFile() throws {
        let file = tempDirectory.appendingPathComponent("Exists.swift")
        try "// Test".write(to: file, atomically: true, encoding: .utf8)
        
        XCTAssertTrue(fileScanner.fileExists(at: file.path), "Should return true for existing file")
    }
    
    func testFileExists_NonExistentFile() {
        let file = tempDirectory.appendingPathComponent("DoesNotExist.swift")
        XCTAssertFalse(fileScanner.fileExists(at: file.path), "Should return false for non-existent file")
    }
    
    func testFileExists_Directory() {
        XCTAssertTrue(fileScanner.fileExists(at: tempDirectory.path), "Should return true for existing directory")
    }
    
    // MARK: - contentsOfDirectory Tests
    
    func testContentsOfDirectory_EmptyDirectory() throws {
        let contents = try fileScanner.contentsOfDirectory(at: tempDirectory)
        XCTAssertEqual(contents.count, 0, "Should return empty array for empty directory")
    }
    
    func testContentsOfDirectory_WithFiles() throws {
        let file1 = tempDirectory.appendingPathComponent("File1.swift")
        let file2 = tempDirectory.appendingPathComponent("File2.txt")
        
        try "// Test".write(to: file1, atomically: true, encoding: .utf8)
        try "Test".write(to: file2, atomically: true, encoding: .utf8)
        
        let contents = try fileScanner.contentsOfDirectory(at: tempDirectory)
        
        XCTAssertEqual(contents.count, 2, "Should return all files")
        let fileNames = contents.map { $0.lastPathComponent }
        XCTAssertTrue(fileNames.contains("File1.swift"), "Should include Swift file")
        XCTAssertTrue(fileNames.contains("File2.txt"), "Should include text file")
    }
    
    func testContentsOfDirectory_SkipsHiddenFiles() throws {
        let visibleFile = tempDirectory.appendingPathComponent("Visible.swift")
        let hiddenFile = tempDirectory.appendingPathComponent(".Hidden.swift")
        
        try "// Test".write(to: visibleFile, atomically: true, encoding: .utf8)
        try "// Test".write(to: hiddenFile, atomically: true, encoding: .utf8)
        
        let contents = try fileScanner.contentsOfDirectory(
            at: tempDirectory,
            options: [.skipsHiddenFiles]
        )
        
        XCTAssertEqual(contents.count, 1, "Should skip hidden files with option")
        let fileNames = contents.map { $0.lastPathComponent }
        XCTAssertTrue(fileNames.contains("Visible.swift"), "Should include visible file")
    }
    
    // MARK: - attributesOfItem Tests
    
    func testAttributesOfItem_ExistingFile() throws {
        let file = tempDirectory.appendingPathComponent("Test.swift")
        try "// Test".write(to: file, atomically: true, encoding: .utf8)
        
        let attributes = try fileScanner.attributesOfItem(at: file.path)
        
        XCTAssertNotNil(attributes[.size], "Should have file size")
        XCTAssertNotNil(attributes[.modificationDate], "Should have modification date")
        XCTAssertNotNil(attributes[.creationDate], "Should have creation date")
    }
    
    func testAttributesOfItem_NonExistentFile() {
        let file = tempDirectory.appendingPathComponent("DoesNotExist.swift")
        
        XCTAssertThrowsError(try fileScanner.attributesOfItem(at: file.path)) { error in
            XCTAssertTrue(error is CocoaError, "Should throw CocoaError for non-existent file")
        }
    }
}
