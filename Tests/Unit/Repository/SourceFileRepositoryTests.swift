import XCTest
@testable import ModelGraphGenerator

final class SourceFileRepositoryTests: XCTestCase {
    var tempDirectory: URL!
    var repository: SourceFileRepository!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        repository = SourceFileRepository(logger: Logger(verbose: false))
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - readFile (path) Tests
    
    func testReadFile_ExistingFile() throws {
        let file = tempDirectory.appendingPathComponent("Test.swift")
        let content = "struct User { let name: String }"
        try content.write(to: file, atomically: true, encoding: .utf8)
        
        let result = repository.readFile(at: file.path)
        
        XCTAssertNotNil(result, "Should successfully read file")
        XCTAssertEqual(result, content, "Should return correct content")
    }
    
    func testReadFile_NonExistentFile() {
        let file = tempDirectory.appendingPathComponent("DoesNotExist.swift")
        
        let result = repository.readFile(at: file.path)
        
        XCTAssertNil(result, "Should return nil for non-existent file")
    }
    
    func testReadFile_EmptyFile() throws {
        let file = tempDirectory.appendingPathComponent("Empty.swift")
        try "".write(to: file, atomically: true, encoding: .utf8)
        
        let result = repository.readFile(at: file.path)
        
        XCTAssertNotNil(result, "Should read empty file")
        XCTAssertEqual(result, "", "Should return empty string")
    }
    
    func testReadFile_MultilineContent() throws {
        let file = tempDirectory.appendingPathComponent("Multiline.swift")
        let content = """
        struct User {
            let name: String
            let email: String
        }
        """
        try content.write(to: file, atomically: true, encoding: .utf8)
        
        let result = repository.readFile(at: file.path)
        
        XCTAssertEqual(result, content, "Should preserve multiline content")
    }
    
    func testReadFile_SpecialCharacters() throws {
        let file = tempDirectory.appendingPathComponent("Special.swift")
        let content = "let emoji = \"🎉\"\nlet symbol = \"©\""
        try content.write(to: file, atomically: true, encoding: .utf8)
        
        let result = repository.readFile(at: file.path)
        
        XCTAssertEqual(result, content, "Should preserve special characters")
    }
    
    // MARK: - readFile (URL) Tests
    
    func testReadFileURL_ExistingFile() throws {
        let file = tempDirectory.appendingPathComponent("Test.swift")
        let content = "class MyClass { }"
        try content.write(to: file, atomically: true, encoding: .utf8)
        
        let result = repository.readFile(at: file)
        
        XCTAssertNotNil(result, "Should successfully read file from URL")
        XCTAssertEqual(result, content, "Should return correct content")
    }
    
    func testReadFileURL_NonExistentFile() {
        let file = tempDirectory.appendingPathComponent("DoesNotExist.swift")
        
        let result = repository.readFile(at: file)
        
        XCTAssertNil(result, "Should return nil for non-existent file URL")
    }
    
    // MARK: - readFileOrThrow Tests
    
    func testReadFileOrThrow_ExistingFile() throws {
        let file = tempDirectory.appendingPathComponent("Test.swift")
        let content = "enum Status { case active }"
        try content.write(to: file, atomically: true, encoding: .utf8)
        
        let result = try repository.readFileOrThrow(at: file.path)
        
        XCTAssertEqual(result, content, "Should return correct content")
    }
    
    func testReadFileOrThrow_NonExistentFile() {
        let file = tempDirectory.appendingPathComponent("DoesNotExist.swift")
        
        XCTAssertThrowsError(try repository.readFileOrThrow(at: file.path)) { error in
            XCTAssertTrue(error is CocoaError, "Should throw CocoaError")
        }
    }
    
    func testReadFileOrThrowURL_ExistingFile() throws {
        let file = tempDirectory.appendingPathComponent("Test.swift")
        let content = "protocol MyProtocol { }"
        try content.write(to: file, atomically: true, encoding: .utf8)
        
        let result = try repository.readFileOrThrow(at: file)
        
        XCTAssertEqual(result, content, "Should return correct content from URL")
    }
    
    func testReadFileOrThrowURL_NonExistentFile() {
        let file = tempDirectory.appendingPathComponent("DoesNotExist.swift")
        
        XCTAssertThrowsError(try repository.readFileOrThrow(at: file)) { error in
            XCTAssertTrue(error is CocoaError, "Should throw CocoaError for URL")
        }
    }
    
    // MARK: - isReadable Tests
    
    func testIsReadable_ExistingFile() throws {
        let file = tempDirectory.appendingPathComponent("Readable.swift")
        try "// Test".write(to: file, atomically: true, encoding: .utf8)
        
        XCTAssertTrue(repository.isReadable(filePath: file.path), "Should return true for readable file")
    }
    
    func testIsReadable_NonExistentFile() {
        let file = tempDirectory.appendingPathComponent("DoesNotExist.swift")
        
        XCTAssertFalse(repository.isReadable(filePath: file.path), "Should return false for non-existent file")
    }
    
    func testIsReadable_Directory() {
        // Note: directories are considered "readable" by FileManager.isReadableFile
        // because you can list their contents, even though you can't read them as text files
        XCTAssertTrue(repository.isReadable(filePath: tempDirectory.path), "Directories are readable (listable)")
        
        // However, trying to read a directory as a file should return nil
        let result = repository.readFile(at: tempDirectory.path)
        XCTAssertNil(result, "Should not be able to read directory as text file")
    }
    
    // MARK: - readFiles (batch) Tests
    
    func testReadFiles_AllSuccessful() throws {
        let file1 = tempDirectory.appendingPathComponent("File1.swift")
        let file2 = tempDirectory.appendingPathComponent("File2.swift")
        let content1 = "struct A { }"
        let content2 = "struct B { }"
        
        try content1.write(to: file1, atomically: true, encoding: .utf8)
        try content2.write(to: file2, atomically: true, encoding: .utf8)
        
        let results = repository.readFiles(at: [file1.path, file2.path])
        
        XCTAssertEqual(results.count, 2, "Should read both files")
        XCTAssertEqual(results[file1.path], content1, "Should read first file correctly")
        XCTAssertEqual(results[file2.path], content2, "Should read second file correctly")
    }
    
    func testReadFiles_PartialSuccess() throws {
        let file1 = tempDirectory.appendingPathComponent("Exists.swift")
        let file2 = tempDirectory.appendingPathComponent("DoesNotExist.swift")
        let content1 = "struct Exists { }"
        
        try content1.write(to: file1, atomically: true, encoding: .utf8)
        
        let results = repository.readFiles(at: [file1.path, file2.path])
        
        XCTAssertEqual(results.count, 1, "Should read only existing file")
        XCTAssertEqual(results[file1.path], content1, "Should read existing file")
        XCTAssertNil(results[file2.path], "Should not include non-existent file")
    }
    
    func testReadFiles_EmptyArray() {
        let results = repository.readFiles(at: [])
        
        XCTAssertEqual(results.count, 0, "Should return empty dictionary for empty input")
    }
    
    func testReadFiles_AllFailed() {
        let file1 = tempDirectory.appendingPathComponent("Missing1.swift")
        let file2 = tempDirectory.appendingPathComponent("Missing2.swift")
        
        let results = repository.readFiles(at: [file1.path, file2.path])
        
        XCTAssertEqual(results.count, 0, "Should return empty dictionary when all reads fail")
    }
    
    // MARK: - Integration Tests
    
    func testIntegration_ReadModifyWrite() throws {
        let file = tempDirectory.appendingPathComponent("Integration.swift")
        let originalContent = "struct Original { let value: Int }"
        try originalContent.write(to: file, atomically: true, encoding: .utf8)
        
        // Read
        let content = try repository.readFileOrThrow(at: file.path)
        XCTAssertEqual(content, originalContent)
        
        // Modify
        let modifiedContent = content.replacingOccurrences(of: "Original", with: "Modified")
        try modifiedContent.write(to: file, atomically: true, encoding: .utf8)
        
        // Read again
        let newContent = repository.readFile(at: file.path)
        XCTAssertEqual(newContent, modifiedContent)
        XCTAssertTrue(newContent!.contains("Modified"))
    }
    
    func testIntegration_LargeFile() throws {
        let file = tempDirectory.appendingPathComponent("Large.swift")
        
        // Generate large content (10,000 lines)
        var largeContent = ""
        for i in 1...10000 {
            largeContent += "struct Model\(i) { let id: Int }\n"
        }
        
        try largeContent.write(to: file, atomically: true, encoding: .utf8)
        
        let result = repository.readFile(at: file.path)
        
        XCTAssertNotNil(result, "Should read large file")
        XCTAssertEqual(result?.count, largeContent.count, "Should read entire large file")
        XCTAssertTrue(result!.contains("struct Model1 "), "Should contain first line")
        XCTAssertTrue(result!.contains("struct Model10000 "), "Should contain last line")
    }
}
