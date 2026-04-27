---
id: cycle-detection
title: Cycle Detection
sidebar_label: Cycle Detection
sidebar_position: 5
---

# Cycle Detection

Real-world Swift models frequently contain circular references — a `User` owner that holds `Order` records, which in turn reference the `User` who placed them. Without explicit cycle detection, the graph builder would recurse infinitely.

ModelGraphGenerator uses a **two-level state strategy** inside `CycleDetector` to handle this correctly without losing type information.

## Two-Level State

```mermaid
flowchart TD
    CD["CycleDetector"]:::main

    CD --> V["visitedUSRs: Set‹String›\nCurrent DFS path (per root)"]:::path
    CD --> NC["nodeCache: [String: Node]\nAll fully-built nodes (global)"]:::cache

    classDef main fill:#0066cc,stroke:#004499,color:#fff
    classDef path fill:#ff9f0a,stroke:#c77c02,color:#fff
    classDef cache fill:#34c759,stroke:#248a3d,color:#fff
```

| | `visitedUSRs` | `nodeCache` |
|---|---|---|
| **Scope** | Current DFS path | Entire graph build |
| **Reset?** | Yes — between roots | No — persists forever |
| **Purpose** | Cycle detection | Work deduplication |

## Decision Tree

Every time `processSymbol` is called, `CycleDetector` is consulted:

```mermaid
flowchart TD
    PS["processSymbol(symbol)"]:::main

    PS --> Q1{"isVisited\n(symbol.usr)?"}
    Q1 -- "YES" --> CYC["Return CyclicNode\nisCyclic: true, children: []"]:::cyclic

    Q1 -- "NO" --> Q2{"getCachedNode\n(symbol.usr)?"}
    Q2 -- "Found" --> CACHED["Return cachedNode\n(already fully built)"]:::cache

    Q2 -- "Not found" --> PROC["Full processing:\nmarkVisited → build children\n→ cacheNode → return"]:::process

    classDef main fill:#0066cc,stroke:#004499,color:#fff
    classDef cyclic fill:#ff3b30,stroke:#c02b24,color:#fff
    classDef cache fill:#ff9f0a,stroke:#c77c02,color:#fff
    classDef process fill:#34c759,stroke:#248a3d,color:#fff
```

## Worked Example — Mutual Reference

```swift
struct User {
    let orders: [Order]
}

struct Order {
    let placedBy: User    // ← back-reference
}
```

### Step-by-step trace

```mermaid
sequenceDiagram
    participant BG as buildGraph
    participant SP as processSymbol
    participant CD as CycleDetector

    BG->>CD: resetVisited()
    Note over CD: visited = {} · cache = {}

    BG->>SP: processSymbol(User)
    SP->>CD: markVisited("USR-User")
    Note over CD: visited = {User}

    SP->>SP: property: orders → [Order]
    SP->>SP: processSymbol(Order)
    SP->>CD: markVisited("USR-Order")
    Note over CD: visited = {User, Order}

    SP->>SP: property: placedBy → User
    SP->>SP: processSymbol(User)
    SP->>CD: isVisited("USR-User")?
    CD-->>SP: YES — cycle detected!

    Note over SP: Return CyclicNode{isCyclic: true}
    Note over SP: Order fully built → cacheNode(Order)
    Note over SP: User fully built → cacheNode(User)
```

**Resulting ModelGraph:**

```mermaid
flowchart TD
    U["User"]:::root --> O["orders: Order[]"]:::model
    O -. "placedBy: User (cyclic $ref)" .-> U

    classDef root fill:#0066cc,stroke:#004499,color:#fff
    classDef model fill:#5856d6,stroke:#3634a3,color:#fff
```

## Worked Example — Shared Type (Diamond)

```swift
struct Order {
    let shipTo:   Address
    let billTo:   Address
}
```

```mermaid
sequenceDiagram
    participant SP as processSymbol
    participant CD as CycleDetector

    SP->>SP: processSymbol(Order)

    SP->>SP: processSymbol(Address) [shipTo]
    SP->>CD: markVisited(Address)
    Note over SP: Build Address node…
    SP->>CD: cacheNode(Address)

    SP->>SP: processSymbol(Address) [billTo]
    SP->>CD: isVisited? → NO
    SP->>CD: getCachedNode? → YES
    Note over SP: Return cached AddressNode immediately
```

Both `shipTo` and `billTo` point to the _same_ `ModelNode` object — no duplicate work, no duplicate `$defs` entry.

## Cyclic Node in JSON Schema

When the converter encounters `isCyclic: true`, it emits a `$ref` pointing back to the already-defined `$defs` entry rather than inline-expanding the type:

```json
"placedBy": {
  "$ref": "#/$defs/User"
}
```

This produces valid, non-recursive JSON Schema that validators can process without infinite loops.

## Edge Cases

### Self-referential types

```swift
struct TreeNode {
    let children: [TreeNode]   // ← self-reference
}
```

Handled identically: on the recursive call with `TreeNode`'s USR, `isVisited` returns `true` immediately, emitting a `$ref` back to `#/$defs/TreeNode`.

### Protocol-backed polymorphism

Polymorphic variants are processed at a _higher_ recursion frame before the main property recursion. Each variant gets its own `markVisited` / `cacheNode` cycle, but they are processed as siblings rather than as nested children, so a variant referencing the parent root does not create a false cycle.

### Generic types

Generic placeholder types (`T`, `U`, `Element`) are classified as `genericPlaceholder` by `TypeAnalyzer` and are **skipped entirely** — they never enter the cycle detector because they cannot be resolved to a concrete symbol.
