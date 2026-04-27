# Model Graph Generator - Test Suite

This directory contains comprehensive unit and integration tests for the Model Graph Generator annotation processor.

## Test Structure

### CodingKeysParserTests.swift
Tests for the `CodingKeysParser` class that extracts `CodingKeys` mappings from Swift types.

**Coverage:**
- ✅ Simple CodingKeys with string mappings
- ✅ CodingKeys with no explicit mappings
- ✅ CodingKeys in extensions
- ✅ CodingKeys in classes
- ✅ Multiple CodingKeys in different extensions
- ✅ Nested types isolation
- ✅ Special characters in JSON keys
- ✅ Edge cases (missing files, wrong type names)

### PropertyExtractorTests.swift
Tests for the `PropertyExtractorVisitor` that extracts property declarations from Swift types.

**Coverage:**
- ✅ Simple properties (let/var)
- ✅ Optional properties
- ✅ Array properties
- ✅ Set properties
- ✅ Dictionary properties
- ✅ Custom type properties
- ✅ Enum cases extraction
- ✅ Associated values in enums
- ✅ Class properties
- ✅ Nested type handling
- ✅ Complex generic types

### ModelsTests.swift
Tests for the output model structures (`ModelGraph`, `ModelNode`, `PropertyInfo`, etc.).

**Coverage:**
- ✅ ModelGraph encoding/decoding
- ✅ ModelNode creation and serialization
- ✅ PropertyInfo with various configurations
- ✅ EnumCaseInfo handling
- ✅ InheritedPropertyInfo
- ✅ Complete graph serialization

### IntegrationTests.swift
End-to-end integration tests simulating real-world usage scenarios.

**Coverage:**
- ✅ Real-world CodingKeys extraction
- ✅ Property and CodingKeys coordination
- ✅ Nested types handling
- ✅ Inheritance scenarios
- ✅ Complex multi-type models
- ✅ Edge cases (empty files, multiple types)

## Running Tests

### Run All Tests
```bash
swift test
```

### Run Specific Test File
```bash
swift test --filter CodingKeysParserTests
swift test --filter PropertyExtractorTests
swift test --filter ModelsTests
swift test --filter IntegrationTests
```

### Run Specific Test Case
```bash
swift test --filter CodingKeysParserTests.testSimpleCodingKeysMapping
```

### Run with Verbose Output
```bash
swift test --verbose
```

### Generate Code Coverage
```bash
swift test --enable-code-coverage
```

## Test Conventions

### Naming
- Test methods start with `test`
- Test names describe what is being tested: `test[Feature][Scenario]`
- Example: `testSimpleCodingKeysMapping`, `testCodingKeysInExtension`

### Structure
Each test follows the Arrange-Act-Assert pattern:
```swift
func testExample() {
    // Arrange - Set up test data
    let input = "..."
    
    // Act - Execute the code under test
    let result = SomeClass.someMethod(input)
    
    // Assert - Verify the results
    XCTAssertEqual(result, expectedValue)
}
```

### Assertions Used
- `XCTAssertEqual` - Values are equal
- `XCTAssertNotEqual` - Values are not equal
- `XCTAssertTrue` / `XCTAssertFalse` - Boolean conditions
- `XCTAssertNil` / `XCTAssertNotNil` - Nil checks
- `XCTAssertGreaterThan` / `XCTAssertLessThan` - Comparisons

## Adding New Tests

When adding new functionality:

1. **Write tests first** (TDD approach recommended)
2. **Test happy paths** - Normal expected usage
3. **Test edge cases** - Empty inputs, nil values, boundary conditions
4. **Test error paths** - Invalid inputs, missing files
5. **Update this README** if adding new test files

## Test Data

Tests use temporary files created in `setUp()` and cleaned up in `tearDown()` to avoid polluting the filesystem.

```swift
override func setUp() {
    super.setUp()
    tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
}

override func tearDown() {
    try? FileManager.default.removeItem(at: tempDirectory)
    super.tearDown()
}
```

## Continuous Integration

These tests should be run on every commit. Add to your CI pipeline:

```yaml
- name: Run Tests
  run: swift test --enable-code-coverage
```

## Coverage Goals

Current target: **80%+ code coverage** for core parsing logic.

Priority areas:
1. CodingKeysParser - Critical for JSON mapping
2. PropertyExtractor - Critical for type analysis
3. GraphBuilder - Important for relationship building

## Known Limitations

- IndexStoreDB integration tests require a real index store (not included in unit tests)
- Some edge cases with nested generics may not be fully tested
- Macro expansion testing requires real macro setup

## Contributing

When contributing tests:
1. Ensure all tests pass locally
2. Add descriptive test names
3. Include comments for complex test scenarios
4. Update this README if needed
5. Aim for high coverage of new code
