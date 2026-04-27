---
id: overview
title: Performance
sidebar_label: Overview
sidebar_position: 1
---

# Performance

ModelGraphGenerator is designed to run in **seconds**, not minutes, even on large Swift codebases. This page explains the architectural choices that make that possible, what affects runtime, and how to squeeze extra speed out of the tool on big projects.

## Benchmark Reference

| Codebase size | Models | Run time | Mode |
|---------------|--------|----------|------|
| Small — 30 models | 30 | ~0.3 s | `--macro-only` |
| Medium — 150 models | 150 | ~1.2 s | default |
| Large — 500+ models | 500 | ~4–7 s | default |
| Large — 500+ models | 500 | ~1.5 s | `--macro-only` |

> Measured on Apple M-series hardware. Results vary by storage speed and index freshness.

## What Drives Runtime

```
 Total time ≈ Discovery  +  Parsing  +  Graph Building  +  I/O
              (index r/w)   (SwiftSyntax per file)   (JSON write)

 Dominant term for most codebases: Parsing
```

### 1. Discovery — O(symbols in index)

IndexStoreDB lookups are extremely fast (sub-millisecond). The file-system regex fallback scans every `.swift` file linearly — O(files × avg lines).

On a 500-file project the regex scan typically takes **< 0.2 s**.

### 2. Parsing — O(unique types referenced)

SwiftSyntax parses each referenced `.swift` file exactly once. For a model graph that touches 200 unique types across 150 files, that's 150 `Parser.parse()` calls.

Each parse call is proportional to file size. SwiftSyntax is fast (written in C++) but parsing is still the dominant cost for large graphs.

### 3. Graph Building — O(unique types × avg properties)

Recursive descent is bounded by:
- The `nodeCache` — each type is processed **once**
- The depth limit (default 20) — prevents runaway expansion
- The set of primitive / system types — leaf nodes are skipped immediately

In practice graph building adds < 5 % of total time for typical codebases.

### 4. I/O — O(output size)

Writing the JSON output is typically negligible (< 0.05 s) even for multi-MB schema files.

## Speed Levers

### `--macro-only` flag

The biggest single performance win. When this flag is set:

- Discovery **skips** the protocol conformance scan entirely (no IndexStoreDB `.baseOf` queries)
- Discovery **skips** all file-system regex scans for protocol patterns
- Only the `@ChimeraSchema` macro annotation scan runs

If your codebase uses `@ChimeraSchema` consistently, this cuts discovery time in half and eliminates the need for a built index.

```bash
model-graph-generator \
  --source-path ./Sources \
  --macro-only \
  --output schema.json
```

### `--source-path` scoping

The regex file-system scan walks _every_ `.swift` file under `--source-path`. Narrow it to just the directory containing your models:

```bash
# Slower — scans all sources including tests, generated code
--source-path ./

# Faster — scans only the models directory
--source-path ./Sources/Models
```

### Pre-built index (`--index-path`)

Providing a path to an existing Xcode `Index.noindex/DataStore` skips the library search and database initialisation:

```bash
--index-path ~/Library/Developer/Xcode/DerivedData/MyApp-xxx/Index.noindex/DataStore
```

Without this flag, ModelGraphGenerator auto-detects the most recent index — adding ~50–100 ms for the `DerivedData` directory scan.

### Depth limit tuning

The default depth of **20** is conservative. If your model graph is shallow (most real-world APIs are ≤ 6 levels), lowering it cuts graph building time:

```bash
--max-depth 8
```

## Caching in the Graph Builder

The `CycleDetector.nodeCache` is the most important optimisation in the graph building phase. Consider a typical e-commerce model:

```
Order      → Address (shipTo)
Order      → Address (billTo)
LineItem   → Order
Invoice    → Order
Shipment   → Address
```

Without caching, `Address` would be parsed and processed **4 times**. With the cache, it's processed **once** and reused. For a codebase where many models share common types (`User`, `Address`, `Currency`, `Timestamp`), this can reduce total parse calls by **60–80 %**.

## Memory Footprint

ModelGraphGenerator holds the entire `ModelGraph` in memory before serialising it. The memory cost is roughly:

```
≈ 2 KB × (number of unique types in graph)
```

A 500-type graph uses ~1 MB, well within normal CLI tool budgets.

## Profiling Tips

If you need to diagnose a slow run:

```bash
# Enable verbose logging to see which phase is slow
model-graph-generator --source-path ./Sources --verbose --output /dev/null
```

Verbose output includes per-phase timing:

```
[Discovery]  Found 47 root models in 0.18 s
[Parsing]    Processed 312 types in 2.14 s
[Graph]      Built graph (500 nodes) in 0.09 s
[Output]     Wrote schema.json (1.2 MB) in 0.04 s
[Total]      2.45 s
```

If Parsing dominates and you have many large files, consider splitting your model files into smaller focused files — SwiftSyntax's per-call cost scales with file size, not just the number of properties extracted.
