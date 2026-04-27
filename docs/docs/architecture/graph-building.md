---
id: graph-building
title: Graph Building
sidebar_label: Graph Building
sidebar_position: 4
---

# Graph Building

The graph building stage takes the fully-populated `[ModelNode]` list from parsing and constructs a directed dependency graph. This graph is then validated and used by the output stage to emit JSON Schema.

## Why a Graph?

Swift models often reference other models:

```swift
@ChimeraSchema(key: "order")
struct Order {
    let customer: Customer    // → depends on Customer
    let items: [OrderItem]    // → depends on OrderItem
}
```

A dependency graph makes it possible to:

1. **Resolve `$ref` targets**: Map Swift type names (`Customer`) to `@ChimeraSchema` keys (`"customer"`)
2. **Detect cycles**: Circular references (`A → B → A`) need special handling
3. **Determine output order**: Some emitters need all dependencies defined before a type that references them

---

## GraphBuilder

**File:** `Sources/GraphBuilding/GraphBuilder.swift`

`GraphBuilder` takes `[ModelNode]` and produces a `ModelGraph`:

```swift
class GraphBuilder {
    func build(from nodes: [ModelNode]) throws -> ModelGraph
}
```

### Algorithm

1. **Index all nodes** by their `@ChimeraSchema` key: `[String: ModelNode]`
2. **For each node**, scan `PropertyInfo.type` for `.reference(typeName:)` entries
3. **Resolve each reference** by querying `SymbolProcessor` (maps type name → key)
4. **Add a directed edge** from the node's key to the referenced node's key
5. **After all edges are built**, run `CycleDetector`

---

## SymbolProcessor

**File:** `Sources/GraphBuilding/SymbolProcessor.swift`

`SymbolProcessor` maps Swift type names to `@ChimeraSchema` keys. It maintains two lookup tables:

- `typeNameToKey: [String: String]` — built from all `ModelNode.typeName → node.key` pairs
- `SymbolRepository` — fallback for types not in the current scan set (looks up the IndexStoreDB)

When a property type like `Customer` is encountered:

1. First checks `typeNameToKey` — fast path for types in the same scan
2. If not found, checks `SymbolRepository` — handles types in other source directories
3. If still not found, the property is treated as an unknown/external type (emitted as `"type": "object"` with no `$ref`)

---

## CycleDetector

**File:** `Sources/GraphBuilding/CycleDetector.swift`

`CycleDetector` runs a depth-first search (DFS) from every node in the graph to detect strongly connected components (cycles).

```swift
class CycleDetector {
    func detectCycles(in graph: ModelGraph) -> [[String]]
    // Returns a list of cycles, each cycle is an ordered list of keys
}
```

### Cycle Handling

When a cycle is detected (e.g., `order → order-item → order`):

- A warning is logged
- The back-edge property is emitted with `"$ref"` but without inlining the full schema (preventing infinite recursion)
- Processing continues — cycles don't abort schema generation

### Example

```swift
@ChimeraSchema(key: "category")
struct Category {
    let parentCategory: Category?   // self-reference — a cycle!
}
```

Emitted schema:

```json
{
  "properties": {
    "parentCategory": {
      "$ref": "#category"           // back-reference, not inlined
    }
  },
  "required": []                    // Optional, so not required
}
```

---

## ModelGraph

**File:** `Sources/Core/Models/ModelGraph.swift`

The output of the graph building stage:

```swift
struct ModelGraph {
    /// All discovered @ChimeraSchema nodes, keyed by @ChimeraSchema key
    let nodes: [String: ModelNode]

    /// Directed edges: source key → [dependency keys]
    let edges: [String: [String]]

    /// Detected cycles (if any)
    let cycles: [[String]]
}
```

The `ModelGraph` is passed directly to the Output stage.

---

## Output Stage Integration

Once the `ModelGraph` is built, `JSONSchemaConverter` (in `Sources/Output/`) traverses it:

1. Iterates `nodes` in a stable order (alphabetical by key)
2. For each node, emits the JSON Schema object
3. For `.reference` properties, looks up the target in `nodes` and emits `"$ref": "#<key>"`
4. For polymorphic properties, emits the full `oneOf` structure with discriminator

See [JSON Schema Output](../guides/json-schema-output) for the full format reference.
