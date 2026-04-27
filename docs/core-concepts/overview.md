---
id: overview
title: Core Concepts
sidebar_label: Overview
sidebar_position: 1
---

# Core Concepts

ModelGraphGenerator works through a **five-phase pipeline** that transforms annotated Swift source code into a complete JSON Schema document. This section explains the fundamental ideas behind each phase so you can reason about what the tool does — and debug it when something unexpected happens.

## The Big Picture

```mermaid
flowchart TD
    SRC["Your Swift Source Code\n@ChimeraSchema struct Product · @ChimeraSchema struct Order"]:::source

    SRC --> P1
    subgraph P1 ["Phase 1 — Discovery"]
        D1["IndexStoreDB\n+ File-system regex scan"]
    end

    P1 -- "[Product, Order, ...]" --> P2
    subgraph P2 ["Phase 2 — Parsing"]
        D2["SwiftSyntax AST\nProperties, types, CodingKeys,\n@PolymorphicMapping"]
    end

    P2 -- "[PropertyInfo, ...]" --> P3
    subgraph P3 ["Phase 3 — Graph Building"]
        D3["ModelGraph\nRecursive DAG of ModelNodes\nwith cycle detection"]
    end

    P3 -- "ModelGraph" --> P4
    subgraph P4 ["Phase 4 — Conversion"]
        D4["JSONSchemaConverter\nDraft 2020-12 $defs + $ref"]
    end

    P4 --> P5
    subgraph P5 ["Phase 5 — Output"]
        D5["schema.json + knots.json"]
    end

    classDef source fill:#f5f5f7,stroke:#d2d2d7,color:#1d1d1f
```

## Five Phases at a Glance

| Phase | Component | Input | Output |
|-------|-----------|-------|--------|
| 1 — Discovery | `DiscoveryCoordinator` | Source root + index path | `[IndexedSymbol]` |
| 2 — Parsing | `PropertyExtractor` + parsers | Swift file paths | `[PropertyInfo]` |
| 3 — Graph Building | `GraphBuilder` + `SymbolProcessor` | `[IndexedSymbol]` | `ModelGraph` |
| 4 — Conversion | `JSONSchemaConverter` | `ModelGraph` | JSON Schema object |
| 5 — Serialization | `Main.swift` | JSON Schema object | File on disk |

## Key Abstractions

### IndexedSymbol

The lightweight handle returned by the Discovery phase. It carries just enough information to locate the Swift declaration:

```swift
struct IndexedSymbol {
    let name: String    // "Product"
    let usr:  String    // Unique Symbol Resolution — "s:7MyApp7ProductV"
    let path: String    // "/path/to/Product.swift"
    let line: Int       // 14
    let kind: Kind      // .struct | .class | .enum
}
```

### ModelNode

A fully resolved node in the graph. Every non-primitive Swift type referenced by a root model becomes a `ModelNode`:

```swift
struct ModelNode {
    let name: String
    let schemaId: String?              // from @ChimeraSchema(key: "…")
    let properties: [PropertyInfo]
    let inheritedProperties: [InheritedPropertyInfo]
    let children: [ModelNode]
    let isCyclic: Bool                 // back-reference detected
    let isPolymorphic: Bool
    let polymorphicVariants: [ModelNode]
}
```

### ModelGraph

The top-level container — a flat list of root `ModelNode` trees plus metadata:

```swift
struct ModelGraph {
    let roots: [ModelNode]
    let generatedAt: Date
    let sourceRoot: String
}
```

---

## Where to go next

| Topic | Page |
|-------|------|
| How symbols are found | [Discovery System](/core-concepts/discovery) |
| How source is parsed | [AST Parsing](/core-concepts/ast-parsing) |
| How the graph is assembled | [Graph Building](/core-concepts/graph-building) |
| Cycles & shared types | [Cycle Detection](/core-concepts/cycle-detection) |
| Polymorphism & discriminators | [Polymorphic Types](/core-concepts/polymorphism) |
