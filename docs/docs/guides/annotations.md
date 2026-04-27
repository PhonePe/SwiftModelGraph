---
id: annotations
title: Annotations Reference
sidebar_label: Annotations
sidebar_position: 1
---

# Annotations Reference

ModelGraphGenerator uses three annotations to mark Swift types for schema generation. All annotations are applied as Swift macros.

## `@ChimeraSchema`

Marks a Swift struct or class as a top-level schema type.

```swift
@ChimeraSchema(key: "product")
struct Product {
    // ...
}
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `key` | `String` | Yes | The schema `$id` identifier. Used as the root key in the generated schema. |

### Rules

- Apply only to `struct` or `class` types
- The `key` must be unique across all models in your source
- Works alongside `@ChimeraMetaData` (recommended) for descriptions

### Generated Output

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object"
}
```

---

## `@ChimeraMetaData`

Adds a human-readable description to a `@ChimeraSchema` type. Always pair this with `@ChimeraSchema`.

```swift
@ChimeraMetaData(description: "A product in the catalog")
@ChimeraSchema(key: "product")
struct Product {
    // ...
}
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `description` | `String` | Yes | Human-readable description of the model, emitted as `"description"` in the JSON Schema |

### Generated Output

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "description": "A product in the catalog"
}
```

---

## `@ChimeraProperty`

Annotates a property within a `@ChimeraSchema` type to add schema metadata: description, constraints, examples, and more.

```swift
@ChimeraSchema(key: "product")
struct Product {
    @ChimeraProperty(description: "Product name", minLength: 1, maxLength: 200)
    let name: String

    @ChimeraProperty(description: "Price in USD", min: 0.0)
    let price: Double

    @ChimeraProperty(description: "Stock count", min: 0, max: 9999)
    let stockCount: Int
}
```

### Parameters

All parameters are optional except `description`:

| Parameter | Applies To | Description |
|-----------|-----------|-------------|
| `description` | All types | Human-readable property description |
| `minLength` | `String` | Minimum string length |
| `maxLength` | `String` | Maximum string length |
| `pattern` | `String` | Regex pattern the value must match |
| `min` | `Int`, `Double` | Minimum numeric value (inclusive) |
| `max` | `Int`, `Double` | Maximum numeric value (inclusive) |
| `exclusiveMin` | `Int`, `Double` | Minimum value (exclusive) |
| `exclusiveMax` | `Int`, `Double` | Maximum value (exclusive) |
| `minItems` | `Array` | Minimum number of array items |
| `maxItems` | `Array` | Maximum number of array items |
| `example` | All types | Example value for documentation |

### Type Mapping

Swift types are automatically mapped to JSON Schema types:

| Swift Type | JSON Schema Type | Notes |
|------------|-----------------|-------|
| `String` | `"string"` | |
| `Int`, `Int32`, `Int64` | `"integer"` | |
| `Double`, `Float` | `"number"` | |
| `Bool` | `"boolean"` | |
| `Date` | `"string"` | `format: "date-time"` |
| `URL` | `"string"` | `format: "uri"` |
| `[T]` | `"array"` | `items` reflects `T` |
| `[String: T]` | `"object"` | `additionalProperties` reflects `T` |
| `T?` | type of `T` | property not added to `required` |
| Custom `struct`/`class` | `"object"` | nested schema inline or by `$ref` |
| Custom `enum` | `"string"` | `enum` values list |

### Optional Properties

Properties typed as `Optional<T>` (i.e., `T?`) are **not** included in the `required` array:

```swift
@ChimeraSchema(key: "user")
struct User {
    @ChimeraProperty(description: "User ID")
    let id: String           // required

    @ChimeraProperty(description: "Bio")
    let bio: String?         // NOT required — omitted from required[]
}
```

### Nested Types

Properties referencing another `@ChimeraSchema` type are emitted as `$ref`:

```swift
@ChimeraSchema(key: "order")
struct Order {
    @ChimeraProperty(description: "The customer who placed the order")
    let customer: Customer   // → "$ref": "#customer"
}
```

---

## Annotation Order

Always apply `@ChimeraMetaData` before `@ChimeraSchema` and `@ChimeraProperty` to properties:

```swift
// Correct
@ChimeraMetaData(description: "My model")
@ChimeraSchema(key: "my-model")
struct MyModel {
    @ChimeraProperty(description: "A value")
    let value: String
}

// Also valid — @ChimeraMetaData last
@ChimeraSchema(key: "my-model")
@ChimeraMetaData(description: "My model")
struct MyModel { ... }
```

## Complete Example

```swift
@ChimeraMetaData(description: "An item in the shopping cart")
@ChimeraSchema(key: "cart-item")
struct CartItem {
    @ChimeraProperty(description: "Product SKU", minLength: 3, maxLength: 20, pattern: "^[A-Z0-9-]+$")
    let sku: String

    @ChimeraProperty(description: "Quantity ordered", min: 1, max: 100)
    let quantity: Int

    @ChimeraProperty(description: "Unit price in USD at time of purchase", min: 0.0)
    let unitPrice: Double

    @ChimeraProperty(description: "Optional notes from the customer")
    let notes: String?
}
```

Generated schema:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "description": "An item in the shopping cart",
  "properties": {
    "sku": {
      "type": "string",
      "description": "Product SKU",
      "minLength": 3,
      "maxLength": 20,
      "pattern": "^[A-Z0-9-]+$"
    },
    "quantity": {
      "type": "integer",
      "description": "Quantity ordered",
      "minimum": 1,
      "maximum": 100
    },
    "unitPrice": {
      "type": "number",
      "description": "Unit price in USD at time of purchase",
      "minimum": 0.0
    },
    "notes": {
      "type": "string",
      "description": "Optional notes from the customer"
    }
  },
  "required": ["sku", "quantity", "unitPrice"]
}
```
