---
id: contributing
title: Contributing
sidebar_label: Contributing
sidebar_position: 1
---

# Contributing to ModelGraphGenerator

We welcome contributions from the community! Whether you're fixing a bug, adding a feature, improving documentation, or writing tests, your help is appreciated.

## Code of Conduct

Please read and follow our [Code of Conduct](code-of-conduct). We expect all contributors to treat each other with respect and create a welcoming environment.

## Getting Started

### 1. Fork and Clone

```bash
# Fork on GitHub, then:
git clone https://github.com/YOUR_USERNAME/ModelGraphGenerator.git
cd ModelGraphGenerator
```

### 2. Build

```bash
swift build
```

### 3. Run Tests

```bash
swift test
```

All 327+ tests should pass before you start making changes.

### 4. Create a Branch

```bash
git checkout -b feature/my-new-feature
# or
git checkout -b fix/issue-123
```

## Development Workflow

### Making Changes

1. Make your changes in a focused, logical commit
2. Write or update tests for any changed behavior
3. Run `swift test` to ensure all tests pass
4. Run `swift build` to ensure it compiles cleanly

### Code Style

- Follow Swift API design guidelines
- Use `swiftformat` for consistent formatting (run `swift package plugin --allow-writing-to-package-directory format`)
- Prefer `let` over `var` where possible
- Use descriptive names — clarity over brevity

### Writing Tests

Tests live in `Tests/`. Structure mirrors `Sources/`:

- `Tests/Unit/` — Unit tests for individual components
- `Tests/Integration/` — End-to-end tests running the full pipeline

When adding a new feature, add:
1. Unit tests in the appropriate `Tests/Unit/` subdirectory
2. Integration test if the feature affects end-to-end output

Test naming convention:

```swift
func test_extractsMinLengthConstraint_whenPropertyHasMinLength() { ... }
func test_emitsOneOf_forPolymorphicProperty() { ... }
```

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add @ChimeraProperty example parameter support
fix: correctly handle optional array properties
docs: improve CLI flags documentation
test: add missing tests for CodingKeys renaming
refactor: simplify TypeAnalyzer enum mapping
```

## Submitting a Pull Request

1. Push your branch to your fork
2. Open a pull request against `main` on `PhonePe/ModelGraphGenerator`
3. Fill in the PR template — describe _what_ changed and _why_
4. Ensure CI passes (build + tests)
5. Request a review from a maintainer

### PR Checklist

- [ ] Tests added/updated for all changed behavior
- [ ] `swift test` passes locally
- [ ] `swift build` produces no warnings
- [ ] Commit messages follow Conventional Commits
- [ ] Documentation updated if adding a new feature or flag

## Reporting Issues

Use [GitHub Issues](https://github.com/PhonePe/ModelGraphGenerator/issues) to report bugs or request features.

### Bug Reports

Include:
- **ModelGraphGenerator version** (`model-graph-generator --version`)
- **Swift version** (`swift --version`)
- **macOS version** (`sw_vers`)
- **Minimal reproduction case**: the smallest Swift snippet that triggers the bug
- **Expected vs. actual behavior**

### Feature Requests

Describe:
- The use case you're trying to solve
- What annotation or CLI change would address it
- Any alternatives you've considered

## Questions

For questions and discussions, use [GitHub Discussions](https://github.com/PhonePe/ModelGraphGenerator/discussions).

For security issues, email **sharang.verma@phonepe.com** directly (do not open a public issue).

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](https://github.com/PhonePe/ModelGraphGenerator/blob/main/LICENSE).
