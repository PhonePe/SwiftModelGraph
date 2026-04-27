---
id: quick-start
title: Quick Start
sidebar_label: Quick Start
sidebar_position: 3
---

# Quick Start

Get your first JSON Schema generated in under 5 minutes.

## 1. Create a Swift File with Model Annotations

Create a file called `MyModels.swift` in a directory of your choice:

```swift
import Foundation

// Mark a struct as a root model to generate JSON Schema
@ChimeraMetaData(description: "A user account")
@ChimeraSchema(key: "user")
struct User {
    @ChimeraProperty(description: "Unique user ID")
    let id: String

    @ChimeraProperty(description: "Display name", minLength: 1, maxLength: 100)
    let name: String

    @ChimeraProperty(description: "Email address")
    let email: String

    @ChimeraProperty(description: "Account creation date")
    let createdAt: Date

    @ChimeraProperty(description: "Whether the account is active")
    let isActive: Bool
}

@ChimeraMetaData(description: "A user's post")
@ChimeraSchema(key: "post")
struct Post {
    @ChimeraProperty(description: "Post ID")
    let id: String

    @ChimeraProperty(description: "Post title", minLength: 1)
    let title: String

    @ChimeraProperty(description: "Post body text")
    let body: String

    @ChimeraProperty(description: "Author user ID")
    let authorId: String

    @ChimeraProperty(description: "Tags associated with this post")
    let tags: [String]
}
```

## 2. Run ModelGraphGenerator

Point the CLI at the directory containing your Swift file:

```bash
model-graph-generator \
  --source-path ./MyModels \
  --output ./schema.json \
  --json-schema \
  --macro-only
```

**Flag breakdown:**

| Flag | Purpose |
|------|---------|
| `--source-path` | Directory containing your Swift source files |
| `--output` | Where to write the generated JSON Schema |
| `--json-schema` | Emit JSON Schema Draft 2020-12 format |
| `--macro-only` | Only process files with `@ChimeraSchema` (faster) |

## 3. Inspect the Output

Open `schema.json` to see the generated schemas:

```json
[
  {
    "schemaId": "user",
    "schemaDefinition": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "id": {
          "type": "string",
          "description": "Unique user ID"
        },
        "name": {
          "type": "string",
          "description": "Display name",
          "minLength": 1,
          "maxLength": 100
        },
        "email": {
          "type": "string",
          "description": "Email address"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time",
          "description": "Account creation date"
        },
        "isActive": {
          "type": "boolean",
          "description": "Whether the account is active"
        }
      },
      "required": ["id", "name", "email", "createdAt", "isActive"]
    },
    "metaData": { "description": "A user account" }
  },
  {
    "schemaId": "post",
    "schemaDefinition": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "id": { "type": "string", "description": "Post ID" },
        "title": { "type": "string", "description": "Post title", "minLength": 1 },
        "body": { "type": "string", "description": "Post body text" },
        "authorId": { "type": "string", "description": "Author user ID" },
        "tags": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Tags associated with this post"
        }
      },
      "required": ["id", "title", "body", "authorId", "tags"]
    },
    "metaData": { "description": "A user's post" }
  }
]
```

## 4. Generate Schema for a Single Type

If you only want a schema for one specific type:

```bash
model-graph-generator \
  --source-path ./MyModels \
  --symbol-name User \
  --output ./user-schema.json \
  --json-schema
```

## 5. Enable Verbose Output

For debugging or to understand what the tool is doing internally:

```bash
model-graph-generator \
  --source-path ./MyModels \
  --output ./schema.json \
  --json-schema \
  --verbose
```

You'll see per-file progress, discovered annotations, and property resolution details.

## Next Steps

Now that you've generated your first schema, explore more:

- **[Annotations Guide](guides/annotations)** — Learn all available annotation parameters
- **[CLI Usage](guides/cli-usage)** — Full reference for all command-line options
- **[Polymorphic Types](guides/polymorphic-types)** — Handle inheritance and `oneOf` schemas
- **[JSON Schema Output](guides/json-schema-output)** — Understand the generated schema format
- **[Examples](examples/ecommerce)** — See complete real-world usage
