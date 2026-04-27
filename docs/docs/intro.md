---
id: intro
title: Introduction
sidebar_label: Introduction
sidebar_position: 1
slug: /
---

# ModelGraphGenerator

**Generate JSON Schema from Swift Models with Ease**

ModelGraphGenerator is an open-source command-line tool that automatically generates [JSON Schema](https://json-schema.org/) from your Swift model types. Simply annotate your models with `@ChimeraSchema`, run the CLI, and get a fully-formed JSON Schema — no manual writing required.

## What Is ModelGraphGenerator?

When building APIs, SDKs, or data contracts, you often need JSON Schema representations of your Swift models. Maintaining these schemas by hand is error-prone and time-consuming. ModelGraphGenerator solves this by reading your Swift source code and generating schemas automatically, keeping your Swift types and JSON Schema always in sync.

```swift
// Annotate once...
@ChimeraMetaData(description: "A product in the catalog")
@ChimeraSchema(key: "product")
struct Product {
    @ChimeraProperty(description: "Unique product identifier")
    let id: String

    @ChimeraProperty(description: "Product name")
    let name: String

    @ChimeraProperty(description: "Price in USD", min: 0.0)
    let price: Double
}
```

```json
// ...get JSON Schema automatically
{
  "schemaId": "product",
  "schemaDefinition": {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "properties": {
      "id": { "type": "string", "description": "Unique product identifier" },
      "name": { "type": "string", "description": "Product name" },
      "price": { "type": "number", "minimum": 0.0, "description": "Price in USD" }
    },
    "required": ["id", "name", "price"]
  },
  "metaData": { "description": "A product in the catalog" }
}
```

## Key Features

| Feature | Description |
|---------|-------------|
| 🎯 **Simple Annotations** | Three annotations — `@ChimeraSchema`, `@ChimeraProperty`, `@ChimeraMetaData` |
| 🔍 **Multi-Strategy Discovery** | Protocol conformance + macro annotation detection |
| 📊 **JSON Schema Output** | Generates JSON Schema Draft 2020-12 format |
| 🔄 **Polymorphic Support** | `@ChimeraPolymorphic` and `@PolymorphicMapping` for `oneOf` schemas |
| ⚡ **Fast CLI** | Single command, seconds to run |
| 🔧 **Customizable** | Control symbol names, output path, verbosity |

## Use Cases

- **API Documentation** — Generate OpenAPI-compatible schemas from your request/response types
- **SDK Generation** — Create client SDKs from your server-side Swift models
- **Testing & Validation** — Validate JSON payloads against your model definitions
- **Data Contracts** — Maintain versioned schema contracts across services
- **Code Review** — Surface model changes as schema diffs in pull requests

## Prerequisites

Before using ModelGraphGenerator, ensure you have:

- **Swift**: 5.9 or later
- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later (for IndexStoreDB support)
- **Command Line Tools**: Installed via `xcode-select --install`

## Quick Navigation

| If you want to... | Go to... |
|-------------------|----------|
| Install the tool | [Installation](/docs/installation) |
| Run your first example | [Quick Start](/docs/quick-start) |
| Learn all annotations | [Annotations Guide](/docs/guides/annotations) |
| Understand CLI options | [CLI Usage](/docs/guides/cli-usage) |
| See real-world examples | [Examples](/docs/examples/ecommerce) |
| Understand the internals | [Architecture](/docs/architecture/overview) |
| Contribute to the project | [Contributing](/docs/contributing) |
