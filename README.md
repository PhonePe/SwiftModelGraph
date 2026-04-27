<p align="center">
  <h1 align="center">SwiftModelGraph</h1>
  <p align="center">
    <strong>Generate JSON Schema from Swift Models — Automatically</strong>
  </p>
  <p align="center">
    <a href="https://github.com/PhonePe/SwiftModelGraph/actions"><img src="https://github.com/PhonePe/SwiftModelGraph/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
    <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.9+-orange.svg" alt="Swift 5.9+"></a>
    <a href="https://developer.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-13.0+-blue.svg" alt="macOS 13.0+"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="MIT License"></a>
  </p>
</p>

---

SwiftModelGraph is an open-source command-line tool that automatically generates [JSON Schema Draft 2020-12](https://json-schema.org/) from your Swift model types. Point it at your source code, run a single command, and get fully-formed JSON Schema — no manual writing required.

## Why SwiftModelGraph?

When building APIs, SDKs, or data contracts, maintaining JSON Schema by hand is error-prone and time-consuming. SwiftModelGraph keeps your Swift types and JSON Schema always in sync by reading your source code and generating schemas automatically.

## Features

| Feature | Description |
|---------|-------------|
| 🔍 **Protocol-First Discovery** | Discovers models via protocol conformance |
| 🎯 **Macro Support** | Also supports macro-based detection (`@SchemaModel`, custom macros) |
| 📊 **JSON Schema Output** | Generates JSON Schema Draft 2020-12 format |
| 🔄 **Polymorphic Support** | `oneOf` schemas with discriminator-based type mapping |
| 🔁 **Cycle Detection** | USR-based tracking prevents infinite loops from circular dependencies |
| 🧬 **Inheritance Tracking** | Track property sources across inheritance chains |
| ⚡ **Fast CLI** | Single command, seconds to run |

## Quick Start

### 1. Define Your Models

**Using protocol conformance (default):**

```swift
protocol SchemaModel {}

struct User: SchemaModel {
    let id: String
    let name: String
    let email: String
    let isActive: Bool
}
```

**Or using macro annotations:**

```swift
@SchemaModel
struct User {
    let id: String
    let name: String
    let email: String
    let isActive: Bool
}
```

### 2. Run the CLI

```bash
# Protocol conformance mode (default)
model-graph-generator \
  --source-path ./Sources \
  --marker-name SchemaModel \
  --output schema.json \
  --json-schema

# Macro mode
model-graph-generator \
  --source-path ./Sources \
  --marker-name SchemaModel \
  --use-macro \
  --output schema.json \
  --json-schema
```

### 3. Get JSON Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "id": { "type": "string" },
    "name": { "type": "string" },
    "email": { "type": "string" },
    "isActive": { "type": "boolean" }
  },
  "required": ["id", "name", "email", "isActive"],
  "additionalProperties": false
}
```

## Requirements

| Requirement | Version |
|-------------|---------|
| Swift | 5.9+ |
| macOS | 13.0 (Ventura)+ |
| Xcode | 15.0+ |
| Xcode Command Line Tools | Latest |

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/PhonePe/SwiftModelGraph.git
cd SwiftModelGraph

# Build
swift build -c release

# The binary is at .build/release/model-graph-generator
```

### Install Globally (Optional)

```bash
sudo cp .build/release/model-graph-generator /usr/local/bin/
```

### As a Swift Package Dependency

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/PhonePe/SwiftModelGraph.git", from: "1.0.0")
]
```

## CLI Usage

```
model-graph-generator [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--source-path` / `-s` | **(Required)** Path to Swift source directory to scan |
| `--index-path` / `-i` | Path to IndexStoreDB (auto-detected if not provided) |
| `--marker-name` / `-m` | Protocol/macro name to search for (default: `ChimeraSchema`) |
| `--use-macro` | Use macro-based detection instead of protocol conformance |
| `--exclude-dirs` | Folder names to exclude from scanning (e.g. `Pods DerivedData`) |
| `--output` / `-o` | Output file path (stdout if omitted) |
| `--json-schema` | Emit JSON Schema Draft 2020-12 format |
| `--verbose` / `-v` | Enable detailed logging |
| `--help` / `-h` | Print help and exit |

### Examples

```bash
# Protocol conformance: find all types conforming to SchemaModel
model-graph-generator --source-path ./Sources --marker-name SchemaModel --output schema.json --json-schema

# Macro mode: find all types annotated with @SchemaModel
model-graph-generator --source-path ./Sources --marker-name SchemaModel --use-macro --output schema.json --json-schema

# Exclude directories from scanning
model-graph-generator --source-path ./Sources --marker-name SchemaModel --exclude-dirs Pods DerivedData --json-schema

# Pipe to jq for formatting
model-graph-generator --source-path ./Sources --marker-name SchemaModel --json-schema | jq '.'
```

## Annotations

SwiftModelGraph supports optional annotations to enrich generated schemas with descriptions, constraints, and metadata. See the [full documentation](https://phonepe.github.io/SwiftModelGraph/docs/guides/annotations) for details.

### Polymorphic Types

Define polymorphic properties with discriminator-based `oneOf` schemas:

```swift
struct Order {
    @PolymorphicMapping(
        discriminator: "type",
        variants: ["credit": CreditPayment.self, "upi": UPIPayment.self]
    )
    let payment: Payment
}
```

This generates a `oneOf` JSON Schema with discriminator mapping. See the [Polymorphic Types guide](https://phonepe.github.io/SwiftModelGraph/docs/guides/polymorphic-types) for more.

## Type Mapping

| Swift Type | JSON Schema Type | Notes |
|------------|-----------------|-------|
| `String` | `"string"` | |
| `Int` | `"integer"` | |
| `Double`, `Float` | `"number"` | |
| `Bool` | `"boolean"` | |
| `Date` | `"string"` | `format: "date-time"` |
| `URL` | `"string"` | `format: "uri"` |
| `UUID` | `"string"` | `format: "uuid"` |
| `[T]` | `"array"` | `items` reflects `T` |
| `Set<T>` | `"array"` | `uniqueItems: true` |
| `[String: T]` | `"object"` | `additionalProperties` reflects `T` |
| `T?` | type of `T` | Not included in `required` |
| Custom struct/class | `"object"` | Nested inline schema |
| Enum (String raw) | `"string"` | With `enum` values list |

## How It Works

SwiftModelGraph operates through a **five-phase pipeline**:

```
Swift Source → Discovery → Parsing → Graph Building → Conversion → JSON Schema
```

1. **Discovery** — Finds types conforming to a marker protocol (or macro-annotated) via IndexStoreDB
2. **Parsing** — Uses SwiftSyntax to extract properties, types, CodingKeys, and annotations
3. **Graph Building** — Constructs a recursive DAG of model nodes with cycle detection
4. **Conversion** — Transforms the model graph into JSON Schema Draft 2020-12
5. **Output** — Writes the generated JSON Schema to disk

## Discovery Modes

SwiftModelGraph supports two discovery strategies:

| Mode | Flag | Description |
|------|------|-------------|
| **Protocol Conformance** (default) | — | Finds all types conforming to a marker protocol (customizable via `--marker-name`) |
| **Macro-based** | `--use-macro` | Finds types with macro annotations |

Protocol conformance is recommended as it integrates naturally with Swift's type system and provides compile-time guarantees.

## Use Cases

- **API Documentation** — Generate OpenAPI 3.1-compatible schemas from request/response types
- **SDK Generation** — Create client SDKs from server-side Swift models
- **Testing & Validation** — Validate JSON payloads against model definitions
- **Data Contracts** — Maintain versioned schema contracts across services
- **CI Integration** — Detect schema drift in pull requests

### CI Pipeline Example

```bash
#!/bin/bash
set -e

model-graph-generator \
  --source-path ./Sources \
  --output ./generated/schema.json \
  --json-schema --macro-only

if ! git diff --quiet generated/schema.json; then
  echo "Schema has changed — commit the updated schema.json"
  exit 1
fi
```

## Documentation

Full documentation is available at **[phonepe.github.io/SwiftModelGraph](https://phonepe.github.io/SwiftModelGraph)**, including:

- [Installation Guide](https://phonepe.github.io/SwiftModelGraph/docs/installation)
- [Quick Start](https://phonepe.github.io/SwiftModelGraph/docs/quick-start)
- [Annotations Reference](https://phonepe.github.io/SwiftModelGraph/docs/guides/annotations)
- [CLI Usage](https://phonepe.github.io/SwiftModelGraph/docs/guides/cli-usage)
- [JSON Schema Output](https://phonepe.github.io/SwiftModelGraph/docs/guides/json-schema-output)
- [Polymorphic Types](https://phonepe.github.io/SwiftModelGraph/docs/guides/polymorphic-types)
- [Architecture & Internals](https://phonepe.github.io/SwiftModelGraph/docs/architecture/overview)
- [Examples (E-Commerce, Blog CMS, Social Media)](https://phonepe.github.io/SwiftModelGraph/docs/examples/ecommerce)

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

```bash
# Clone & build
git clone https://github.com/YOUR_USERNAME/SwiftModelGraph.git
cd SwiftModelGraph
swift build

# Run tests
swift test

# Run with coverage
swift test --enable-code-coverage
```

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before participating.

## Troubleshooting

### Build fails — "cannot find type"
Ensure Swift 5.9+ is installed: `swift --version`

### No schemas generated
Make sure your models conform to the marker protocol (or are annotated with the appropriate macro if using `--use-macro`) and you're using `--json-schema`.

### IndexStoreDB errors
Verify Xcode is installed and `xcode-select -p` points to a valid Xcode installation. Build your target project first so the index exists.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<p align="center">Made with ❤️ by <a href="https://github.com/PhonePe">PhonePe</a></p>
