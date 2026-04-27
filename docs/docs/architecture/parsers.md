---
id: parsers
title: Parsers
sidebar_label: Parsers
sidebar_position: 3
---

# Parsers

The parser stage takes the stubs produced by discovery and enriches each `ModelNode` with full property, enum, and structural data. All parsers use `SwiftSyntax` AST visitors.

## Parser Overview

| Parser | File | Responsibility |
|--------|------|----------------|
| `PropertyExtractor` | `PropertyExtractor.swift` | Extract `@ChimeraProperty` annotations and types |
| `EnumExtractor` | `EnumExtractor.swift` | Extract enum cases and raw values |
| `PolymorphicParser` | `PolymorphicParser.swift` | Parse `@PolymorphicMapping` |
| `CodingKeysParser` | `CodingKeysParser.swift` | Resolve custom CodingKeys names |
| `TypeAnalyzer` | `TypeAnalyzer.swift` | Normalize Swift type strings to JSON types |

---

## PropertyExtractor

**File:** `Sources/Parser/PropertyExtractor.swift`

The primary parser. For each `ModelNode`, `PropertyExtractor` opens its source file, parses it with `SwiftSyntax`, and visits all stored property declarations via `PropertyExtractorVisitor`.

### PropertyExtractorVisitor

**File:** `Sources/Parser/Syntax/PropertyExtractorVisitor.swift`

Visits `VariableDeclSyntax` nodes (i.e., `let` and `var` declarations). For each property:

1. Reads all attached attributes, looking for `@ChimeraProperty(...)`
2. Extracts the `description`, and any constraint arguments (`minLength`, `max`, etc.)
3. Reads the type annotation (e.g., `String`, `Int?`, `[Product]`)
4. Passes the type string to `TypeAnalyzer` for normalization
5. Checks `isOptional` by inspecting `OptionalTypeSyntax` or `ImplicitlyUnwrappedOptionalTypeSyntax`
6. Creates a `PropertyInfo` value

### Constraint Extraction

`@ChimeraProperty` arguments are parsed from `LabeledExprListSyntax`. Each labeled argument maps to a field on `PropertyConstraints`:

```swift
struct PropertyConstraints {
    var minLength: Int?
    var maxLength: Int?
    var pattern: String?
    var minimum: Double?
    var maximum: Double?
    var exclusiveMinimum: Double?
    var exclusiveMaximum: Double?
    var minItems: Int?
    var maxItems: Int?
    var example: String?
}
```

---

## TypeAnalyzer

**File:** `Sources/Parser/TypeAnalyzer.swift`

`TypeAnalyzer` converts Swift type strings to the internal type representation used for JSON Schema mapping:

| Input Swift type | Output |
|-----------------|--------|
| `"String"` | `.string` |
| `"Int"`, `"Int32"`, `"Int64"` | `.integer` |
| `"Double"`, `"Float"` | `.number` |
| `"Bool"` | `.boolean` |
| `"Date"` | `.dateTime` |
| `"URL"` | `.uri` |
| `"[T]"` | `.array(element: T)` |
| `"[String: T]"` | `.dictionary(value: T)` |
| `"T?"` | `.optional(wrapped: T)` |
| Custom type name | `.reference(typeName: T)` |

References (custom types) are resolved later during graph building, where `SymbolProcessor` maps type names to `@ChimeraSchema` keys.

---

## EnumExtractor

**File:** `Sources/Parser/EnumExtractor.swift`

Handles Swift enums used as property types. When `TypeAnalyzer` returns `.reference("Status")` and `Status` is an enum, `EnumExtractor` parses the enum to collect its cases.

### EnumExtractorVisitor *(internal)*

Visits `EnumDeclSyntax` and its `EnumCaseDeclSyntax` children. For string-backed enums (`enum Status: String`), it reads the raw value string if present, otherwise uses the case name.

Output:

```swift
struct EnumCaseInfo {
    let name: String        // Swift case name
    let rawValue: String    // String raw value (or case name if none)
}
```

---

## PolymorphicParser

**File:** `Sources/Parser/PolymorphicParser.swift`

Reads `@PolymorphicMapping` annotations on protocols and class hierarchies.

### PolymorphicVisitor

**File:** `Sources/Parser/Syntax/PolymorphicVisitor.swift`

Visits protocol and class declarations with `@PolymorphicMapping`. Extracts:

- `key`: The discriminator property name
- `mappings`: The `[String: Any.Type]` dictionary literal, reading string keys and type name references

The parser cross-references the type names in `mappings` against the `MacroRepository` to confirm they have `@ChimeraSchema` annotations. Missing `@ChimeraSchema` on a concrete type triggers a warning.

Output:

```swift
struct PolymorphicInfo {
    let discriminatorKey: String
    let mappings: [String: String]   // discriminator value → @ChimeraSchema key
}
```

---

## CodingKeysParser

**File:** `Sources/Parser/CodingKeysParser.swift`

When a model defines a nested `CodingKeys` enum, the JSON property names should use those custom keys rather than the Swift property names.

### CodingKeysVisitor

**File:** `Sources/Parser/Syntax/CodingKeysVisitor.swift`

Looks for `enum CodingKeys: String, CodingKey` nested inside a `@ChimeraSchema` type. Extracts the mapping from Swift property name → JSON key name using raw values:

```swift
enum CodingKeys: String, CodingKey {
    case firstName = "first_name"   // Swift "firstName" → JSON "first_name"
    case lastName  = "last_name"
}
```

`CodingKeysParser` returns a `[String: String]` dictionary that the property extraction stage uses to rename `PropertyInfo.name` in the output.

---

## ChimeraPropertyParser / Visitors

**Files:** `ChimeraPropertyParser.swift`, `ChimeraMetaDataVisitor.swift`, `ChimeraPropertyVisitor.swift`

An alternative property parsing strategy supporting an earlier annotation format. Operates similarly to `PropertyExtractor` but looks for a different annotation syntax. This is used when `MacroDiscovery` is not applicable.

---

## Parser Integration

After all parsers complete for a given `ModelNode`:

1. `PropertyInfo` list is attached to the node
2. `EnumCaseInfo` list is attached for any enum-typed properties
3. `PolymorphicInfo` is set if applicable
4. CodingKey renames are applied

The fully-populated `[ModelNode]` is then passed to the Graph Building stage.
