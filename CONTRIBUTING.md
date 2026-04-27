# Contributing to SwiftModelGraph

Thank you for your interest in contributing to SwiftModelGraph! This document provides guidelines and instructions for contributing to the project.

📖 Full contributing guide: **[phonepe.github.io/SwiftModelGraph/docs/contributing](https://phonepe.github.io/SwiftModelGraph/docs/contributing)**

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md) before participating.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Create a feature branch for your changes
4. Make your changes following our coding standards
5. Submit a pull request

## Development Setup

### Prerequisites

- **macOS 13.0+**
- **Xcode 15.0+** (for IndexStoreDB support)
- **Swift 5.9+**

### Building the Project

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/SwiftModelGraph.git
cd SwiftModelGraph

# Build the project
swift build

# Run the executable
swift run swift-model-graph --help
```

### Running Tests

```bash
# Run all tests
swift test

# Run with code coverage
swift test --enable-code-coverage

# Run specific test suite
swift test --filter PropertyParserTests
```

## Code Style Guidelines

### Swift Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use 4 spaces for indentation (no tabs)
- Maximum line length: 120 characters
- Use clear, descriptive variable and function names
- Add documentation comments for public APIs

### Example

```swift
/// Extracts property information from a Swift type declaration
/// - Parameters:
///   - filePath: Absolute path to the source file
///   - typeName: Name of the type to extract properties from
/// - Returns: Array of PropertyInfo objects, or empty array if parsing fails
func extractProperties(from filePath: String, typeName: String) -> [PropertyInfo] {
    // Implementation
}
```

### Code Organization

- Keep files focused on a single responsibility
- Group related functionality in the same directory
- Use MARK comments to organize code within files

```swift
// MARK: - Public Methods

// MARK: - Private Helpers

// MARK: - Protocol Conformance
```

## Testing Requirements

### Test Coverage

- Aim for **80%+ code coverage** for core functionality
- All new features must include tests
- Fix bugs with a test that reproduces the issue

### Test Structure

Follow the Arrange-Act-Assert pattern:

```swift
func testPropertyExtraction() {
    // Arrange - Set up test data
    let sourceCode = """
    struct User {
        let name: String
        let age: Int
    }
    """
    
    // Act - Execute the code under test
    let properties = PropertyExtractor.extract(from: sourceCode)
    
    // Assert - Verify the results
    XCTAssertEqual(properties.count, 2)
    XCTAssertEqual(properties[0].name, "name")
}
```

### Test Naming

- Start test methods with `test`
- Use descriptive names: `test[Feature][Scenario]`
- Example: `testPropertyExtractionWithOptionalTypes`

## Pull Request Process

### Before Submitting

1. **Update documentation** - Add/update README, code comments, and DOCUMENTATION.md as needed
2. **Add tests** - Ensure new functionality has appropriate test coverage
3. **Run tests locally** - All tests must pass before submitting
4. **Update CHANGELOG** - Add entry describing your changes (if applicable)
5. **Check for breaking changes** - Document any breaking changes clearly

### PR Guidelines

- **Keep PRs focused** - One feature or fix per PR
- **Write clear commit messages** - Use present tense ("Add feature" not "Added feature")
- **Provide context** - Explain why the change is needed
- **Reference issues** - Link to related issues using `Closes #123`

### Commit Message Format

```
Brief summary (50 chars or less)

More detailed explanation if needed. Wrap at 72 characters.
Explain the problem this commit solves and why this approach
was chosen.

- Bullet points are okay
- Use present tense

Closes #123
```

### PR Description Template

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to break)
- [ ] Documentation update

## Testing
Describe the tests you added or how you tested your changes.

## Checklist
- [ ] Tests added/updated and passing
- [ ] Documentation updated
- [ ] Code follows project style guidelines
- [ ] No breaking changes (or documented if unavoidable)
- [ ] Commit messages are clear and descriptive

## Related Issues
Closes #

## Screenshots (if applicable)
```

## Code of Conduct

### Our Standards

- **Be respectful** - Treat all contributors with respect and kindness
- **Be constructive** - Provide helpful feedback and suggestions
- **Be collaborative** - Work together toward the best solution
- **Be patient** - Remember that everyone has different skill levels

### Unacceptable Behavior

- Harassment, discrimination, or offensive comments
- Personal attacks or insults
- Publishing others' private information
- Other conduct inappropriate in a professional setting

### Enforcement

Violations of the code of conduct may result in temporary or permanent ban from the project.

## Where to Get Help

### Resources

- **Documentation**: See [DOCUMENTATION.md](DOCUMENTATION.md) for architecture details
- **Examples**: Check the `Examples/` folder for usage examples
- **Tests**: Look at existing tests for patterns and examples

### Questions?

- **GitHub Issues**: Open an issue for bugs or feature requests
- **GitHub Discussions**: Ask questions or discuss ideas
- **Pull Requests**: For clarification on PRs, comment directly on the PR

## Development Workflow

### Feature Development

1. Create a branch from `main`: `git checkout -b feature/my-feature`
2. Make changes and commit regularly
3. Push to your fork: `git push origin feature/my-feature`
4. Open a pull request against `main`

### Bug Fixes

1. Create a branch from `main`: `git checkout -b fix/bug-description`
2. Add a test that reproduces the bug
3. Fix the bug and verify the test passes
4. Submit a pull request

## Areas for Contribution

### Good First Issues

Look for issues labeled `good first issue` - these are beginner-friendly tasks that are well-scoped.

### Help Wanted

Issues labeled `help wanted` are areas where we'd especially appreciate contributions.

### Priority Areas

- **Parser improvements** - Better handling of complex Swift syntax
- **Error handling** - More descriptive error messages
- **Performance** - Optimizations for large codebases
- **Documentation** - Examples, tutorials, and guides
- **Test coverage** - Expanding test coverage

## Release Process

Maintainers will handle releases. Contributors should focus on:

1. Making quality contributions
2. Responding to PR feedback
3. Helping review other PRs (encouraged!)

## Recognition

Contributors will be:
- Listed in the project README
- Credited in release notes
- Appreciated by the community!

---

## Thank You!

Every contribution, no matter how small, helps make SwiftModelGraph better. We appreciate your time and effort!

**Happy Coding!** 🚀
