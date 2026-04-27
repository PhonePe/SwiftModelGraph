---
id: graph-building
title: Graph Building
sidebar_label: Graph Building
sidebar_position: 4
---

# Graph Building

Phase 3 turns the flat list of `IndexedSymbol` root models into a recursive **ModelGraph** — a directed acyclic graph (DAG) of every type reachable from each root, with inheritance resolved and polymorphic variants expanded.

## Component Architecture

```mermaid
flowchart TD
    GB["GraphBuilder (Orchestrator)\nbuildGraph(from: [(IndexedSymbol, params)])\n→ ModelGraph"]:::main

    GB --> SP & CD

    subgraph SP ["SymbolProcessor"]
        SP1["processSymbol(…)"]
        SP2["→ extract properties"]
        SP3["→ resolve inheritance"]
        SP4["→ detect polymorphism"]
        SP5["→ recurse children"]
        SP6["→ build ModelNode"]
    end

    subgraph CD ["CycleDetector"]
        CD1["visitedUSRs: Set‹String›"]
        CD2["nodeCache: [String: Node]"]
        CD3["isVisited(_:) → Bool"]
        CD4["getCachedNode(for:)"]
        CD5["markVisited(_:)"]
        CD6["cacheNode(_:for:)"]
        CD7["resetVisited()"]
    end

    classDef main fill:#0066cc,stroke:#004499,color:#fff
```

## Graph Building Flow

```mermaid
flowchart TD
    BG["buildGraph(rootSymbols)"]:::main

    BG --> LOOP["For each rootSymbol"]
    LOOP --> RESET["cycleDetector.resetVisited()"]
    RESET --> PROC["symbolProcessor.processSymbol(symbol, depth: 0)"]
    PROC --> APPEND["rootNodes.append(node)"]
    APPEND --> RET["Return ModelGraph(roots: rootNodes)"]:::output

    classDef main fill:#0066cc,stroke:#004499,color:#fff
    classDef output fill:#34c759,stroke:#248a3d,color:#fff
```

**`processSymbol(symbol, depth)` steps:**

```mermaid
flowchart TD
    S1["1. Guard max depth (20)"] --> S2["2. Check cache → return if exists"]
    S2 --> S3["3. Mark USR as visited"]
    S3 --> S4["4. Locate source file via IndexStoreDB"]
    S4 --> S5["5. Extract properties"]
    S5 --> S6["6. Apply CodingKeys remapping"]
    S6 --> S7["7. Resolve inheritance chain\ngetInheritanceChain → extract + tag"]
    S7 --> S8["8. Detect @PolymorphicMapping\n→ recurse each variant"]
    S8 --> S9["9. Recurse non-primitive property types\nfindSymbolByName → processSymbol(child, depth+1)"]
    S9 --> S10["10. Build ModelNode"]
    S10 --> S11["11. Cache ModelNode"]
    S11 --> S12["12. Return node"]:::output

    classDef output fill:#34c759,stroke:#248a3d,color:#fff
```

## Inheritance Resolution

ModelGraphGenerator tracks _where_ each property was originally declared so the JSON Schema can correctly attribute inherited fields:

```swift
class Animal {
    let name: String    // declared in Animal
}
class Dog: Animal {
    let breed: String   // declared in Dog
}
class Poodle: Dog {
    let color: String   // declared in Poodle
}
```

For `Poodle`, the graph builder:

1. Calls `getInheritanceChain("Poodle")` → `[Dog, Animal]`
2. Extracts `Dog`'s properties → `[breed]`, tagged `declaredIn: "Dog"`
3. Extracts `Animal`'s properties → `[name]`, tagged `declaredIn: "Animal"`
4. Assigns to `ModelNode.inheritedProperties`
5. `Poodle.properties` = `[color]` (own only)

The JSON Schema output then emits `allOf` with `$ref` to each ancestor.

## Polymorphic Variant Expansion

When a property has `@PolymorphicMapping`, the graph builder expands each variant type:

```mermaid
flowchart LR
    O["Order.payment: Payment\n@PolymorphicMapping\ndiscriminator: 'type'"]:::main

    O --> CP["processSymbol\nCreditPayment"]:::variant
    O --> UP["processSymbol\nUPIPayment"]:::variant

    CP --> R["PropertyInfo {\n  typeName: Payment\n  polymorphicInfo: {\n    discriminatorKey: type\n    variants: [Credit, UPI]\n  }\n}"]:::output
    UP --> R

    classDef main fill:#0066cc,stroke:#004499,color:#fff
    classDef variant fill:#ff9f0a,stroke:#c77c02,color:#fff
    classDef output fill:#34c759,stroke:#248a3d,color:#fff
```

The converter then emits a `oneOf` with a discriminator mapping.

## Depth Limiting

The recursion depth limit (default **20**) prevents runaway expansion on pathological codebases. If a type is encountered past the limit, it is included as a terminal node without children — no data is lost for the root structure, only deep nested expansion is bounded.

```swift
guard depth < maxDepth else {
    return ModelNode(name: symbol.name, isTruncated: true)
}
```

## Graph Shape Examples

### Simple linear chain

```mermaid
flowchart TD
    P["Product"]:::model --> C["Category"]:::model --> S["String"]:::leaf

    classDef model fill:#0066cc,stroke:#004499,color:#fff
    classDef leaf fill:#f5f5f7,stroke:#d2d2d7,color:#1d1d1f
```

### Shared type (diamond)

```mermaid
flowchart TD
    O["Order (root)"]:::root --> LI["LineItem"]:::model
    O --> SI["ShippingInfo"]:::model
    LI --> A["Address\n(processed once, cached)"]:::cached
    SI --> A

    classDef root fill:#0066cc,stroke:#004499,color:#fff
    classDef model fill:#5856d6,stroke:#3634a3,color:#fff
    classDef cached fill:#ff9f0a,stroke:#c77c02,color:#fff
```

### Cyclic reference

```mermaid
flowchart TD
    U["User (root)"]:::root --> O["Order"]:::model
    O -. "cyclic $ref" .-> U

    classDef root fill:#0066cc,stroke:#004499,color:#fff
    classDef model fill:#5856d6,stroke:#3634a3,color:#fff
```

The `CyclicNode` carries the name and schema ID but has empty children and is flagged `isCyclic: true`, so the converter emits a `$ref` back to the parent definition instead of re-expanding it.
