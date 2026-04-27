---
id: json-schema-output
title: JSON Schema Output Format
sidebar_label: JSON Schema Output
sidebar_position: 4
---

# JSON Schema Output Format

ModelGraphGenerator generates [JSON Schema Draft 2020-12](https://json-schema.org/specification-links#2020-12) compatible output. This page describes the structure of the emitted schemas.

## Top-Level Structure

The output is always a JSON **array** of schema wrapper objects, even when only one model is discovered:

```json
[
  {
    "schemaId": "product",
    "schemaDefinition": { "$schema": "...", "type": "object", ... },
    "metaData": { "description": "..." }
  },
  {
    "schemaId": "order",
    "schemaDefinition": { "$schema": "...", "type": "object", ... },
    "metaData": { "description": "..." }
  }
]
```

## Schema Wrapper Object

Each entry in the array has three fields:

| Field | Source | Description |
|-------|--------|-------------|
| `schemaId` | `@ChimeraSchema(key:)` | Unique schema identifier |
| `schemaDefinition` | Generated | The full JSON Schema object |
| `metaData` | `@ChimeraMetaData` | Metadata object with `description` |

## Schema Definition Structure

The `schemaDefinition` for a regular model follows this structure:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": { ... },
  "required": [ ... ],
  "additionalProperties": false
}
```

### Fields

| Field | Source | Description |
|-------|--------|-------------|
| `$schema` | Fixed | Always `"https://json-schema.org/draft/2020-12/schema"` (root schemas only) |
| `type` | Inferred | `"object"` for models, `"string"` for enums |
| `properties` | `@ChimeraProperty` annotations | Map of property name → property schema |
| `required` | Non-optional properties | Array of property names that are required |
| `additionalProperties` | Fixed | Always `false` — no extra properties allowed |

:::info
The `$schema` field is only emitted on **root-level** schemas. Nested/child schemas omit it, which is correct per the JSON Schema 2020-12 specification.
:::

---

## Property Schema

Each entry in `properties` is a property schema object. The `@ChimeraProperty` annotation supports these overlays:

| Parameter | JSON Schema Keyword | Applies to |
|-----------|-------------------|------------|
| `description` | `description` | All types |
| `isDeprecated` | `deprecated` | All types |
| `regex` | `pattern` / `allOf[].pattern` | Strings |
| `min` | `minimum` | Numeric types |
| `max` | `maximum` | Numeric types |

### String Properties

```swift
@ChimeraProperty(description: "Username", regex: "^[a-z0-9_]+$")
let username: String
```

```json
"username": {
  "type": "string",
  "description": "Username",
  "pattern": "^[a-z0-9_]+$"
}
```

When multiple regex patterns are specified, they are combined with `allOf`:

```json
"code": {
  "type": "string",
  "allOf": [
    { "pattern": "^[A-Z]" },
    { "pattern": "[0-9]$" }
  ]
}
```

### Numeric Properties

```swift
@ChimeraProperty(description: "Price", min: 0.0, max: 99999.99)
let price: Double

@ChimeraProperty(description: "Count", min: 0, max: 1000)
let count: Int
```

```json
"price": {
  "type": "number",
  "description": "Price",
  "minimum": 0.0,
  "maximum": 99999.99
},
"count": {
  "type": "integer",
  "description": "Count",
  "minimum": 0,
  "maximum": 1000
}
```

### Boolean Properties

```swift
@ChimeraProperty(description: "Active status")
let isActive: Bool
```

```json
"isActive": {
  "type": "boolean",
  "description": "Active status"
}
```

### Date Properties

Swift `Date` maps to `string` with `format: "date-time"`:

```swift
@ChimeraProperty(description: "Timestamp")
let createdAt: Date
```

```json
"createdAt": {
  "type": "string",
  "format": "date-time",
  "description": "Timestamp"
}
```

### URL Properties

Swift `URL` maps to `string` with `format: "uri"`:

```swift
@ChimeraProperty(description: "Profile picture URL")
let avatarUrl: URL
```

```json
"avatarUrl": {
  "type": "string",
  "format": "uri",
  "description": "Profile picture URL"
}
```

### UUID Properties

Swift `UUID` maps to `string` with `format: "uuid"`:

```swift
let requestId: UUID
```

```json
"requestId": {
  "type": "string",
  "format": "uuid"
}
```

### Array Properties

```swift
let tags: [String]
```

```json
"tags": {
  "type": "array",
  "items": { "type": "string" }
}
```

### Set Properties

Swift `Set` maps to an array with `uniqueItems: true`:

```json
"categories": {
  "type": "array",
  "items": { "type": "string" },
  "uniqueItems": true
}
```

### Dictionary Properties

Swift `Dictionary` maps to an object with `additionalProperties`:

```json
"metadata": {
  "type": "object",
  "additionalProperties": { "type": "string" }
}
```

For `[Bool: T]` dictionaries, a `propertyNames` constraint is added:

```json
"flags": {
  "type": "object",
  "additionalProperties": { "type": "integer" },
  "propertyNames": { "pattern": "^(true|false)$" }
}
```

### Nested Object Properties

When a property type is itself a model, its schema is **inlined** (not referenced with `$ref`):

```swift
@ChimeraProperty(description: "Shipping address")
let address: Address
```

```json
"address": {
  "type": "object",
  "title": "address",
  "properties": { ... },
  "required": [ ... ],
  "additionalProperties": false,
  "description": "Shipping address"
}
```

### Deprecated Properties

```swift
@ChimeraProperty(description: "Use newField instead", isDeprecated: true)
let oldField: String
```

```json
"oldField": {
  "type": "string",
  "description": "Use newField instead",
  "deprecated": true
}
```

### Optional Properties

Optional properties (`T?`) are excluded from the `required` array:

```swift
@ChimeraProperty(description: "Middle name")
let middleName: String?     // → present in properties, absent from required[]
```

---

## Enum Types

Swift enums with string raw values are emitted as `string` with an `enum` constraint:

```swift
enum Status: String {
    case active, inactive, pending
}
```

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "string",
  "enum": ["active", "inactive", "pending"]
}
```

---

## Polymorphic (oneOf) Schemas

### Type-Level — `@ChimeraPolymorphic`

A type annotated with `@ChimeraPolymorphic` generates a `oneOf` schema with discriminator-based variants:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "additionalProperties": false,
  "oneOf": [
    {
      "type": "object",
      "title": "car",
      "properties": {
        "type": { "const": "car" },
        "doors": { "type": "integer" }
      },
      "required": ["type", "doors"],
      "additionalProperties": false
    },
    {
      "type": "object",
      "title": "truck",
      "properties": {
        "type": { "const": "truck" },
        "payload": { "type": "number" }
      },
      "required": ["type", "payload"],
      "additionalProperties": false
    }
  ]
}
```

Each variant includes the discriminator field with a `const` value, and all variant properties are inlined.

### Property-Level — `@PolymorphicMapping`

A property using `@PolymorphicMapping` generates a nested `oneOf`:

```json
"vehicle": {
  "type": "object",
  "additionalProperties": false,
  "oneOf": [
    {
      "type": "object",
      "title": "Car",
      "properties": {
        "type": { "const": "car" },
        "doors": { "type": "integer" }
      },
      "required": ["type", "doors"],
      "additionalProperties": false
    },
    {
      "type": "object",
      "title": "Truck",
      "properties": {
        "type": { "const": "truck" },
        "payload": { "type": "number" }
      },
      "required": ["type", "payload"],
      "additionalProperties": false
    }
  ]
}
```

---

## Complete Output Example

```json
[
  {
    "schemaId": "product",
    "schemaDefinition": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "name": {
          "type": "string",
          "description": "Product name"
        },
        "price": {
          "type": "number",
          "description": "Price in USD",
          "minimum": 0.0
        },
        "inStock": {
          "type": "boolean"
        }
      },
      "required": ["name", "price", "inStock"],
      "additionalProperties": false
    },
    "metaData": {
      "description": "A product in the catalog"
    }
  }
]
```

---

## Using the Output with OpenAPI

JSON Schema Draft 2020-12 schemas are compatible with OpenAPI 3.1. Extract individual schema definitions with `jq`:

```bash
# Extract the Product schema definition for use in OpenAPI
model-graph-generator --source-path ./Sources --json-schema \
  | jq '.[] | select(.schemaId == "product") | .schemaDefinition' > product-schema.json
```

Then reference in your `openapi.yaml`:

```yaml
components:
  schemas:
    Product:
      $ref: './product-schema.json'
```
