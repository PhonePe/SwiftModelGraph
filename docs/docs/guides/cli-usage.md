---
id: cli-usage
title: CLI Usage
sidebar_label: CLI Usage
sidebar_position: 3
---

# CLI Usage

`model-graph-generator` is a command-line tool that reads your Swift source files, discovers annotated models, and emits JSON Schema.

## Synopsis

```
model-graph-generator [OPTIONS]
```

## All Options

| Option | Short | Default | Description |
|--------|-------|---------|-------------|
| `--source-path <path>` | | Required | Path to Swift source directory to scan |
| `--symbol-name <name>` | | All symbols | Generate schema for one specific type name |
| `--macro-only` | | `false` | Only process files containing `@ChimeraSchema` |
| `--output <path>` | | stdout | File path for the generated output |
| `--json-schema` | | `false` | Emit JSON Schema Draft 2020-12 format |
| `--verbose` | `-v` | `false` | Enable detailed logging |
| `--help` | `-h` | | Print help and exit |

---

## `--source-path`

**Required.** The directory containing your Swift source files.

```bash
# Scan the entire Sources directory
model-graph-generator --source-path ./Sources --output schema.json --json-schema

# Scan a subdirectory
model-graph-generator --source-path ./Sources/Models --output schema.json --json-schema
```

ModelGraphGenerator scans recursively — all `.swift` files in the directory tree are considered.

---

## `--symbol-name`

Generate schema for only one specific Swift type. Useful when you have a large codebase and only need one schema.

```bash
model-graph-generator \
  --source-path ./Sources \
  --symbol-name ProductModel \
  --output product-schema.json \
  --json-schema
```

The value must exactly match the Swift type name (case-sensitive).

---

## `--macro-only`

Skip files that don't contain `@ChimeraSchema`. This can significantly speed up processing for large codebases.

```bash
model-graph-generator \
  --source-path ./Sources \
  --output schema.json \
  --json-schema \
  --macro-only
```

Use this flag whenever your source directory is large but only a subset of files contain annotated models.

---

## `--output`

File path for the generated schema. If omitted, output is written to stdout.

```bash
# Write to a file
model-graph-generator --source-path ./Sources --output ./schema.json --json-schema

# Write to stdout (useful for piping)
model-graph-generator --source-path ./Sources --json-schema | jq '.[0]'
```

The output directory must exist. ModelGraphGenerator will not create intermediate directories.

---

## `--json-schema`

Emit output in [JSON Schema Draft 2020-12](https://json-schema.org/specification-links#2020-12) format.

```bash
model-graph-generator --source-path ./Sources --output schema.json --json-schema
```

Without this flag, the tool uses its internal graph format. Always use `--json-schema` unless you need the raw graph representation.

---

## `--verbose`

Print detailed progress information to stderr. Does not affect the output file.

```bash
model-graph-generator \
  --source-path ./Sources \
  --output schema.json \
  --json-schema \
  --verbose
```

Verbose output includes:

- Files being scanned
- Annotations discovered
- Properties resolved per model
- Polymorphic mappings found
- Any warnings or skipped files

---

## Common Recipes

### Generate schema for all annotated models

```bash
model-graph-generator \
  --source-path ./Sources \
  --output ./schema.json \
  --json-schema \
  --macro-only
```

### Generate schema for a single type

```bash
model-graph-generator \
  --source-path ./Sources \
  --symbol-name MyModel \
  --output ./my-model-schema.json \
  --json-schema
```

### Pipe output to `jq` for formatting

```bash
model-graph-generator --source-path ./Sources --json-schema | jq '.'
```

### Extract a specific schema by title

```bash
model-graph-generator --source-path ./Sources --json-schema \
  | jq '.[] | select(.title == "Product")'
```

### Generate and validate with `ajv`

```bash
model-graph-generator --source-path ./Sources --json-schema --output schema.json
npx ajv validate -s schema.json -d payload.json
```

### CI pipeline integration

```bash
#!/bin/bash
set -e

model-graph-generator \
  --source-path ./Sources \
  --output ./generated/schema.json \
  --json-schema \
  --macro-only

# Fail if schema changed unexpectedly
if ! git diff --quiet generated/schema.json; then
  echo "Schema has changed. Commit the updated schema.json."
  git diff generated/schema.json
  exit 1
fi

echo "Schema unchanged — OK"
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | General error (invalid arguments, source not found, etc.) |
| `2` | No `@ChimeraSchema` annotations found |

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `SWIFT_MODEL_GRAPH_LOG` | Set to `debug` for extra debug logging (alternative to `--verbose`) |
