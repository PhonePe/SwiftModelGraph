---
id: changelog
title: Changelog
sidebar_label: Changelog
sidebar_position: 3
---

# Changelog

All notable changes to ModelGraphGenerator are documented here. This project follows [Semantic Versioning](https://semver.org/) and [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added
- Interactive JSON Schema explorer (planned for v1.1)
- DocC documentation integration (planned for v1.1)

---

## [1.0.0] — 2025-03-10

Initial open-source release of ModelGraphGenerator.

### Added
- `@ChimeraSchema(key:)` annotation for marking Swift types as root schemas
- `@ChimeraMetaData(description:)` annotation for model descriptions
- `@ChimeraProperty(...)` annotation with full constraint support:
  - `description`, `minLength`, `maxLength`, `pattern`
  - `min`, `max`, `exclusiveMin`, `exclusiveMax`
  - `minItems`, `maxItems`, `example`
- `@PolymorphicMapping(key:mappings:)` for polymorphic `oneOf` schemas
- CLI tool `model-graph-generator` with flags:
  - `--source-path`, `--symbol-name`, `--macro-only`
  - `--output`, `--json-schema`, `--verbose`
- Multi-strategy discovery: macro annotations + protocol conformance via IndexStoreDB
- JSON Schema Draft 2020-12 output format
- CodingKeys support for custom JSON property names
- Cycle detection with graceful `$ref` fallback
- Swift type → JSON Schema type mapping:
  - `String` → `"string"`
  - `Int`/`Int32`/`Int64` → `"integer"`
  - `Double`/`Float` → `"number"`
  - `Bool` → `"boolean"`
  - `Date` → `"string"` with `format: "date-time"`
  - `URL` → `"string"` with `format: "uri"`
  - Arrays → `"array"` with `items`
  - Dictionaries → `"object"` with `additionalProperties`
  - Optional → excluded from `required`
  - Enums → `"string"` with `enum` values
- 327 unit and integration tests
- Full documentation site

### Infrastructure
- Swift Package Manager build system
- GitHub Actions CI (build + test on push/PR)
- MIT License
- Contributor Covenant v2.1 Code of Conduct
- CONTRIBUTING.md guide

---

## Format Reference

Entries are grouped as:
- **Added** — new features
- **Changed** — changes to existing behavior
- **Deprecated** — features that will be removed in a future release
- **Removed** — features removed in this release
- **Fixed** — bug fixes
- **Security** — security fixes

[Unreleased]: https://github.com/PhonePe/ModelGraphGenerator/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/PhonePe/ModelGraphGenerator/releases/tag/v1.0.0
