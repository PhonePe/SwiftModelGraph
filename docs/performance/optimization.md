---
id: optimization
title: Optimization Guide
sidebar_label: Optimization Guide
sidebar_position: 2
---

# Optimization Guide

Practical, step-by-step advice for making ModelGraphGenerator as fast as possible in your specific setup — CI pipelines, local development, and monorepos.

## Quick Wins Checklist

```
□  Use --macro-only if you annotate consistently with @ChimeraSchema
□  Narrow --source-path to your Models directory only
□  Pass --index-path to skip DerivedData auto-detection
□  Set --max-depth to match your deepest real model graph
□  Run on an SSD; index reads are NVMe-bound on large projects
□  Cache the built index between CI runs (DerivedData artifact)
```

## CI Pipeline Optimisation

### Cache the Xcode index

The most impactful CI optimisation is persisting the Xcode `DerivedData` index between runs. ModelGraphGenerator (and your build) are much faster when the index doesn't need to be rebuilt from scratch.

**GitHub Actions example**:

```yaml
- name: Cache DerivedData Index
  uses: actions/cache@v4
  with:
    path: ~/Library/Developer/Xcode/DerivedData
    key: xcode-index-${{ hashFiles('**/*.swift') }}
    restore-keys: xcode-index-

- name: Generate JSON Schema
  run: |
    model-graph-generator \
      --source-path Sources/Models \
      --macro-only \
      --output schema.json
```

### Use `--macro-only` in CI

In CI you typically want the fastest possible run. If your codebase uses `@ChimeraSchema` everywhere:

```yaml
- run: model-graph-generator --source-path ./Sources --macro-only --output schema.json
```

This reduces the CI schema generation step to **< 1 second** for most projects.

### Separate schema generation from build

Don't rebuild the entire project just to regenerate the schema. ModelGraphGenerator can run on source files even without a build:

```yaml
jobs:
  schema:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Generate schema
        run: model-graph-generator --source-path Sources --macro-only --output schema.json
      - uses: actions/upload-artifact@v4
        with:
          name: schema
          path: schema.json
```

## Local Development Optimisation

### Shell alias with optimal flags

```bash
# ~/.zshrc
alias smg='model-graph-generator \
  --source-path Sources/Models \
  --macro-only \
  --output /tmp/schema.json \
  && echo "✓ schema.json ready"'
```

### Watch mode with `fswatch`

Regenerate the schema automatically when Swift files change:

```bash
fswatch -o Sources/Models | xargs -n1 -I{} \
  model-graph-generator --source-path Sources/Models --macro-only --output schema.json
```

## Monorepo Optimisation

In a monorepo, `--source-path` scoping is critical. Instead of scanning the entire repo:

```bash
# ✗ Slow — scans 10,000 Swift files
model-graph-generator --source-path .

# ✓ Fast — scans 200 model files
model-graph-generator --source-path Modules/Core/Sources/Models
```

If your root models span multiple directories:

```bash
# Run once per module, merge results externally
for module in Modules/*/Sources/Models; do
  model-graph-generator \
    --source-path "$module" \
    --macro-only \
    --output "/tmp/schema_$(basename $(dirname $module)).json"
done

# Merge with jq
jq -s 'reduce .[] as $s ({}; . * $s)' /tmp/schema_*.json > schema.json
```

## Depth Tuning

The default depth limit is **20**, which is deliberately generous. Most real-world API models are ≤ 6 levels deep. Check your actual maximum depth with verbose output:

```bash
model-graph-generator --source-path Sources --verbose --output /dev/null 2>&1 \
  | grep "max depth reached"
```

If you never hit the limit, you can safely lower it:

```bash
--max-depth 8    # Typical API model depth
--max-depth 4    # Shallow/flat models (DTOs)
```

## Troubleshooting Slow Runs

### "Discovery taking > 2 s"

- Add `--macro-only` to skip protocol conformance scanning
- Check if `--source-path` is pointing at a directory with many non-model Swift files (auto-generated code, tests)

### "Parsing taking > 5 s"

- You have large Swift files (> 500 lines). Consider splitting them.
- The graph is recursing into a very wide type tree. Check `--max-depth`.
- You may be scanning a directory that includes vendored Swift packages — narrow `--source-path`.

### "Index auto-detection is slow"

- Your `DerivedData` folder has many stale project entries. Clean it:
  ```bash
  rm -rf ~/Library/Developer/Xcode/DerivedData
  ```
- Or always pass `--index-path` explicitly to skip detection entirely.

## Performance Anti-Patterns

| Anti-pattern | Impact | Fix |
|---|---|---|
| `--source-path ./` on monorepo | Scans thousands of files | Narrow to Models dir |
| No `--macro-only` with consistent `@ChimeraSchema` usage | 2× slower discovery | Add `--macro-only` |
| Stale/missing index, no `--macro-only` | Index auto-detection fails, falls back to regex for all types | Either build first or always use `--macro-only` |
| Very deep object graphs with `--max-depth 20` | Slow graph building | Lower `--max-depth` |
| Running in CI without caching DerivedData | Index rebuilt each run | Cache DerivedData between runs |
