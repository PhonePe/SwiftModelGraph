# ModelGraphGenerator - Complete Technical Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture & Design](#architecture--design)
3. [Core Components](#core-components)
4. [How It Works: Step-by-Step](#how-it-works-step-by-step)
5. [Technical Deep Dive](#technical-deep-dive)
6. [Usage Guide](#usage-guide)
7. [Output Format](#output-format)
8. [Troubleshooting](#troubleshooting)

---

## Project Overview

### What is ModelGraphGenerator?

ModelGraphGenerator is a **command-line tool** written in Swift that automatically analyzes your Swift codebase and generates a **hierarchical relationship graph** of your data models. It identifies "root models" (either through protocol conformance or macro annotations) and recursively discovers all child models referenced through their properties.

### Purpose & Use Cases

This tool is invaluable for:
- **Documentation**: Automatically visualize the complete structure of your data models
- **Code Understanding**: Quickly understand relationships between different models in a large codebase
- **Refactoring**: Identify dependencies before making structural changes
- **Onboarding**: Help new developers understand the model architecture
- **API Design**: Visualize the complete data graph exposed by your API

### Key Features

1. **Smart Discovery**: Uses Xcode's IndexStoreDB to find models without manual configuration
2. **Deep Analysis**: Uses SwiftSyntax to accurately parse property types including generics
3. **Cycle Detection**: Handles circular references without infinite loops
4. **Flexible Markers**: Supports both protocol conformance and macro annotations
5. **Rich Output**: Generates JSON with complete type information and file locations
6. **Schema ID Support**: Extract custom schema IDs from `@ChimeraSchema(key: "...")` macro parameters
7. **CodingKeys Mapping**: Parse `CodingKeys` enums for JSON property name mappings
8. **Inheritance Tracking**: Track property sources across inheritance chains
9. **Polymorphic Support**: Handle `@PolymorphicMapping` annotations with discriminator fields
10. **Protocol Conformance**: Detect polymorphic types through protocol conformance
11. **JSON Schema Format**: Generate JSON Schema Draft 2020-12 compliant output
12. **Knot Annotations**: Support `@ChimeraMultiKnot` and `@ChimeraMapKnot` for sub-schema organization

### Knot Annotations

Knot annotations allow you to define relationships between a parent model and multiple sub-schemas:

```swift
// Multi-Knot: Define multiple sub-schemas for a type
@ChimeraMultiKnot(schemaId = "payment_method_knot", subSchemas = [CreditCard.class, DebitCard.class, UPI.class])
@ChimeraSchema(key: "payment_methods")
struct PaymentMethodKnot {
    let supportedMethods: [String]
    let defaultMethod: String
}

// Map-Knot: Define a mapping of sub-schemas
@ChimeraMapKnot(schemaId = "vehicle_types_map", subSchemas = [Car.class, Bike.class, Truck.class])
struct VehicleTypeMap {
    let registryId: String
    let totalVehicles: Int
}
```

**Key Points:**
- Knot schemas are output to a separate file: `output-knots.json`
- Both `@ChimeraMultiKnot` and `@ChimeraMapKnot` are supported
- Sub-schemas are specified as `TypeName.class` or just `TypeName`
- The tool extracts only type names (no `.class` suffix in output)
- Knot schemas use the same JSON Schema format with custom structure
- Models can have both `@ChimeraSchema` and a knot annotation (appear in both files)
- Empty `associatedKeys` array as required by the schema format

---

## Architecture & Design

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Command Line Interface                  │
│                      (ArgumentParser)                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                        Main.swift                            │
│  • Argument Parsing                                          │
│  • Index Store Path Resolution                               │
│  • Orchestration of Pipeline                                 │
└──────────┬────────────────────────┬─────────────────────────┘
           │                        │
           ▼                        ▼
┌──────────────────────┐   ┌──────────────────────┐
│  IndexStoreManager   │   │    GraphBuilder      │
│  • Symbol Discovery  │◄──┤  • Graph Construction│
│  • Index Queries     │   │  • Recursion Control │
└──────────┬───────────┘   └───────┬──────────────┘
           │                       │
           ▼                       ▼
┌──────────────────────┐   ┌──────────────────────┐
│  IndexStoreDB API    │   │ SwiftFileParser      │
│  (Xcode's Index)     │   │  • Property Extract. │
└──────────────────────┘   └──────────┬───────────┘
                                      │
                                      ▼
                           ┌──────────────────────┐
                           │    SwiftSyntax       │
                           │  • AST Parsing       │
                           │  • Type Analysis     │
                           └──────────────────────┘
```

### Design Philosophy

The tool follows a **layered architecture** with clear separation of concerns:

**Layered Architecture:**

1. **Core Layer** - Fundamental models and utilities
   - Models: ModelGraph, ModelNode, PropertyInfo, etc.
   - Common utilities: Logger, GraphGeneratorError

2. **Repository Layer** - Data access abstraction
   - IndexStoreManager (Facade)
   - SymbolRepository - Basic symbol lookups
   - InheritanceRepository - Inheritance chain queries

3. **Discovery Layer** - Symbol finding strategies
   - ProtocolDiscovery - Find protocol conformances
   - MacroDiscovery - Find macro annotations
   - KnotDiscovery - Find knot annotations
   - DiscoveryCoordinator - Orchestrates all discovery

4. **GraphBuilding Layer** - Relationship graph construction
   - GraphBuilder - High-level orchestration
   - SymbolProcessor - Recursive symbol processing
   - CycleDetector - Circular reference detection

5. **Parser Layer** - SwiftSyntax-based code analysis
   - SwiftFileParser - Property extraction
   - CodingKeysParser - Parse CodingKeys enums
   - PolymorphicParser - Parse polymorphic annotations
   - KnotParser - Parse knot schemas

6. **Output Layer** - Format conversion
   - JSONSchemaConverter - Generate JSON Schema format
   - KnotSchemaConverter - Generate knot schemas

7. **Utility Layer** - Supporting utilities
   - PathResolver, FileScanner, RegexHelper, TypeUtilities

**Execution Pipeline:**

1. **Phase 1: Discovery** - Find root models and knots
2. **Phase 2: Parsing** - Extract properties and metadata
3. **Phase 3: Graph Building** - Recursively build relationships
4. **Phase 4: Conversion** - Generate output format
5. **Phase 5: Serialization** - Write to files

This architecture enables:
- Independent testing of each layer
- Easy addition of new features
- Clear dependency flow
- Better maintainability

---

## Low-Level Design & Flow Diagrams

### System Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         MAIN ENTRY POINT                             │
│                         (Main.swift)                                 │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │ Parse CLI Args │
                    └────────┬───────┘
                             │
                             ▼
                ┌────────────────────────┐
                │ Resolve Index Path?    │
                │  - Auto-detect or      │
                │  - Use provided path   │
                └────────┬───────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  Initialize IndexStoreManager      │
        │  - Load libIndexStore.dylib        │
        │  - Open IndexStoreDB connection    │
        └────────┬───────────────────────────┘
                 │
                 ▼
     ┌───────────────────────────┐
     │  Find Root Symbols        │
     │  (IndexStoreManager)      │
     └───────┬───────────────────┘
             │
             ├─── useMacro? ────┐
             │                   │
             ▼                   ▼
    ┌──────────────────┐  ┌─────────────────────┐
    │ Find by Protocol │  │ Find by Macro       │
    │  1. Find protocol│  │  1. Search @Macro   │
    │  2. Find .baseOf │  │  2. Find annotated  │
    │  3. Fallback scan│  │  3. Direct file scan│
    └────────┬─────────┘  └──────────┬──────────┘
             │                       │
             └───────────┬───────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │ rootSymbols: [Symbol]  │
            └────────┬───────────────┘
                     │
                     ▼
        ┌────────────────────────────┐
        │  Initialize GraphBuilder   │
        │  - Set up parser           │
        │  - Initialize caches       │
        └────────┬───────────────────┘
                 │
                 ▼
        ┌────────────────────────────────────┐
        │  Initialize GraphBuilder           │
        │  - Create SwiftFileParser          │
        │  - Create CycleDetector            │
        │  - Create SymbolProcessor          │
        └────────┬───────────────────────────┘
                 │
                 ▼
        ┌────────────────────────────────────┐
        │  Phase 3: Build Graph              │
        │  ┌──────────────────────────────┐  │
        │  │ For Each Root Symbol:        │  │
        │  │  1. Reset cycle detector     │  │
        │  │  2. Extract schema ID        │  │
        │  │  3. Call SymbolProcessor     │  │
        │  │     ├─ Check cycles          │  │
        │  │     ├─ Parse with SwiftSyntax│  │
        │  │     ├─ Extract properties    │  │
        │  │     ├─ Get inheritance       │  │
        │  │     ├─ Parse CodingKeys      │  │
        │  │     ├─ Check polymorphic     │  │
        │  │     ├─ Process children      │  │
        │  │     └─ Cache node            │  │
        │  │  4. Add to root nodes        │  │
        │  └──────────────────────────────┘  │
        └────────┬───────────────────────────┘
                 │
                 ▼
        ┌────────────────────────────────────┐
        │  Find Knot Schemas (if jsonSchema) │
        │  - FindAllKnots()                  │
        │  - Process each knot symbol        │
        │  - Build KnotSchemaInfo            │
        └────────┬───────────────────────────┘
                 │
                 ▼
        ┌────────────────────────────────────┐
        │  Phase 4: Convert & Serialize      │
        │  ┌──────────────────────────────┐  │
        │  │ if jsonSchema:               │  │
        │  │   JSONSchemaConverter        │  │
        │  │ else:                        │  │
        │  │   JSONEncoder (raw)          │  │
        │  └──────────────────────────────┘  │
        └────────┬───────────────────────────┘
                 │
                 ▼
        ┌────────────────────────────────────┐
        │  Phase 5: Write Output             │
        │  - Write main graph file           │
        │  - Write knot schemas (if any)     │
        └────────┬───────────────────────────┘
                 │
                 ▼
        ┌────────────────────────────┐
        │  Serialize to JSON         │
        │  - Pretty print            │
        │  - Sort keys               │
        └────────┬───────────────────┘
                 │
                 ▼
        ┌────────────────────────────┐
        │  Write to File/Stdout      │
        └────────────────────────────┘
```

---

## Core Components

### 1. Main.swift - The Orchestrator

**Purpose**: Entry point that parses arguments and coordinates the entire pipeline.

#### Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      Main.swift Flow                             │
└─────────────────────────────────────────────────────────────────┘

START
  │
  ▼
┌─────────────────────────────────┐
│ ArgumentParser.main()           │
│ - Parse all CLI arguments       │
│ - Validate required params      │
└─────────┬───────────────────────┘
          │
          ▼
┌─────────────────────────────────┐     ┌──────────────────────────┐
│ indexPath provided?             │────▶│ Use provided path        │
└─────────┬───────────────────────┘ No  └──────────┬───────────────┘
          │ Yes                                     │
          ▼                                         │
┌─────────────────────────────────┐                │
│ findDefaultIndexStore()         │                │
│  ├─ Get ~/Library/.../          │                │
│  │   DerivedData                │                │
│  ├─ List all project folders    │                │
│  ├─ Check Index.noindex/        │                │
│  │   DataStore in each          │                │
│  ├─ Get modification dates      │                │
│  └─ Return most recent          │                │
└─────────┬───────────────────────┘                │
          │                                         │
          └────────────────┬────────────────────────┘
                           │
                           ▼
                  ┌────────────────┐
                  │ indexStorePath │
                  └────────┬───────┘
                           │
                           ▼
          ┌────────────────────────────────┐
          │ IndexStoreManager.init()       │
          │  ├─ findIndexStoreLibrary()    │
          │  │   • Try /Applications/      │
          │  │     Xcode.app/.../          │
          │  │     libIndexStore.dylib     │
          │  │   • Try xcode-select -p     │
          │  ├─ Load IndexStoreLibrary     │
          │  └─ Initialize IndexStoreDB    │
          └────────┬───────────────────────┘
                   │
                   ▼
          ┌────────────────────────────────┐
          │ Find Root Symbols              │
          ├────────────────────────────────┤
          │ if useMacro:                   │
          │   findSymbolsWithMacro()       │
          │ else:                          │
          │   findSymbolsConformingTo      │
          │   Protocol()                   │
          └────────┬───────────────────────┘
                   │
                   ▼
          ┌────────────────────────────────┐
          │ rootSymbols.isEmpty?           │───Yes──▶ Print empty JSON
          └────────┬───────────────────────┘           └─▶ EXIT
                   │ No
                   ▼
          ┌────────────────────────────────┐
          │ GraphBuilder.init()            │
          │  - Store indexManager          │
          │  - Store sourceRoot            │
          │  - Create SwiftFileParser      │
          │  - Init visitedUSRs set        │
          │  - Init nodeCache dict         │
          └────────┬───────────────────────┘
                   │
                   ▼
          ┌────────────────────────────────┐
          │ graphBuilder.buildGraph()      │
          │  - Process each root symbol    │
          │  - Build recursive tree        │
          └────────┬───────────────────────┘
                   │
                   ▼
          ┌────────────────────────────────┐
          │ Encode to JSON                 │
          │  - JSONEncoder()               │
          │  - .prettyPrinted              │
          │  - .sortedKeys                 │
          └────────┬───────────────────────┘
                   │
                   ▼
          ┌────────────────────────────────┐
          │ Determine output path          │
          ├────────────────────────────────┤
          │ if output provided:            │
          │   use output                   │
          │ else:                          │
          │   sourcePath/model-graph-      │
          │   {timestamp}.json             │
          └────────┬───────────────────────┘
                   │
                   ▼
          ┌────────────────────────────────┐
          │ Write to file                  │
          │  - try jsonString.write()      │
          │  - Print success message       │
          └────────┬───────────────────────┘
                   │
                   ▼
                  EXIT

ERROR HANDLING at each step:
├─ IndexStoreNotFound → throw error
├─ FailedToOpenIndex → throw error
├─ No symbols found → print empty JSON
└─ Write failed → throw error
```

#### State Transitions

```
State Machine for Main.swift:

[INIT] ──parse_args──▶ [ARGS_PARSED]
                              │
                    resolve_index_path
                              │
                              ▼
                      [INDEX_RESOLVED]
                              │
                     initialize_manager
                              │
                              ▼
                      [MANAGER_READY]
                              │
                       find_symbols
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
      [SYMBOLS_FOUND]                  [NO_SYMBOLS]
              │                               │
        build_graph                    return_empty
              │                               │
              ▼                               │
      [GRAPH_BUILT]                           │
              │                               │
       serialize_json                         │
              │                               │
              ▼                               │
      [JSON_READY]                            │
              │                               │
        write_output                          │
              │                               │
              ▼                               ▼
          [SUCCESS] ◀────────────────────[COMPLETED]
```

**Key Responsibilities**:
- Parse command-line arguments using ArgumentParser
- Resolve IndexStore path (auto-detect or use provided path)
- Initialize the IndexStoreManager
- Coordinate GraphBuilder to build the model graph
- Serialize output to JSON

**Configuration Options**:
```swift
struct ModelGraphGenerator: ParsableCommand {
    @Option var indexPath: String?        // Path to Index.noindex/DataStore
    @Option var sourcePath: String        // Source code directory (required)
    @Option var markerName: String        // Protocol/Macro name (default: "RootModel")
    @Flag var useMacro: Bool              // Use @RootModel vs protocol conformance
    @Option var output: String?           // Output file path
    @Flag var verbose: Bool               // Enable detailed logging
}
```

**Index Store Auto-Detection**:
The tool can automatically find Xcode's index by:
1. Looking in `~/Library/Developer/Xcode/DerivedData/`
2. Scanning all project folders
3. Finding the most recently modified `Index.noindex/DataStore`

This eliminates manual path configuration in most cases.

---

### 2. IndexStoreManager.swift - Facade for Symbol Discovery

**Purpose**: Acts as a facade that coordinates specialized repositories and discovery services.

#### New Architecture (Facade Pattern)

The IndexStoreManager no longer performs all operations directly. Instead, it delegates to specialized components:

**Current Class Architecture:**

```
┌───────────────────────────────────────────────────────────────────┐
│                    IndexStoreManager (Facade)                      │
├───────────────────────────────────────────────────────────────────┤
│ Public Properties:                                                 │
│  + indexStore: IndexStoreDB         // Shared IndexStore reference│
│  + logger: Logger                   // Shared logger              │
├───────────────────────────────────────────────────────────────────┤
│ Private Properties (Delegated Components):                         │
│  - sourceRoot: String                                              │
│  - symbolRepository: SymbolRepository                              │
│  - inheritanceRepository: InheritanceRepository                    │
│  - protocolDiscovery: ProtocolDiscovery                            │
│  - macroDiscovery: MacroDiscovery                                  │
├───────────────────────────────────────────────────────────────────┤
│ Public Methods (Delegation):                                       │
│  + init(indexStorePath, sourceRoot, logger)                        │
│  + findSymbolsConforming(to: String) -> [IndexedSymbol]           │
│    └─▶ Delegates to protocolDiscovery                             │
│  + findSymbolsWithMacro(_ name) -> [IndexedSymbol]                │
│    └─▶ Delegates to macroDiscovery                                │
│  + findSymbolByName(_ name) -> IndexedSymbol?                     │
│    └─▶ Delegates to symbolRepository                              │
│  + getInheritanceChain(of: String) -> [IndexedSymbol]             │
│    └─▶ Delegates to inheritanceRepository                         │
└───────────────────────────────────────────────────────────────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
            ▼                ▼                ▼
  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
  │SymbolRepository  │ │InheritanceRepo.  │ │DiscoveryServices │
  │                  │ │                  │ │  - Protocol      │
  │• findByName()    │ │• getInheritance()│ │  - Macro         │
  │• findByUSR()     │ │• getParent()     │ │  - Knot          │
  └──────────────────┘ └──────────────────┘ └──────────────────┘
```

**Key Design Change:**
- **Before**: IndexStoreManager did everything
- **After**: IndexStoreManager coordinates specialized services
- **Benefit**: Better separation of concerns, easier testing, cleaner code

#### Initialization Flow

```
┌────────────────────────────────────────────────────────────────┐
│              IndexStoreManager Initialization                   │
└────────────────────────────────────────────────────────────────┘

init(indexStorePath, sourceRoot, logger)
  │
  ▼
┌─────────────────────────────────┐
│ Store parameters                │
│  - self.sourceRoot = sourceRoot │
│  - self.logger = logger         │
└─────────┬───────────────────────┘
          │
          ▼
┌─────────────────────────────────┐
│ Validate index path exists      │
│  FileManager.fileExists()       │
└─────────┬───────────────────────┘
          │ No
          ├───────────▶ Log warning
          │
          ▼
┌─────────────────────────────────┐
│ Create temp database path       │
│  NSTemporaryDirectory() +       │
│  "model-graph-db-{UUID}"        │
└─────────┬───────────────────────┘
          │
          ▼
┌─────────────────────────────────┐
│ findIndexStoreLibrary()         │
│  ┌───────────────────────────┐  │
│  │ Try common paths:         │  │
│  │ 1. /Applications/Xcode    │  │
│  │    .app/.../              │  │
│  │    libIndexStore.dylib    │  │
│  │ 2. /Applications/         │  │
│  │    Xcode-beta.app/...     │  │
│  │ 3. /Library/.../          │  │
│  │    swift-latest/...       │  │
│  └───────────┬───────────────┘  │
│              │                   │
│              ▼                   │
│  ┌───────────────────────────┐  │
│  │ Fallback: xcode-select    │  │
│  │  - Run xcode-select -p    │  │
│  │  - Append toolchain path  │  │
│  │  - Check if exists        │  │
│  └───────────┬───────────────┘  │
│              │                   │
│              ▼                   │
│         Found/Throw error        │
└─────────┬───────────────────────┘
          │
          ▼
┌─────────────────────────────────┐
│ Load IndexStoreLibrary          │
│  try IndexStoreLibrary(         │
│    dylibPath: libPath           │
│  )                              │
└─────────┬───────────────────────┘
          │ Failed
          ├───────────▶ throw FailedToOpenIndex
          │ Success
          ▼
┌─────────────────────────────────┐
│ Create IndexStoreDB             │
│  try IndexStoreDB(              │
│    storePath: indexStorePath,   │
│    databasePath: dbPath,        │
│    library: library,            │
│    waitUntilDoneInitializing:   │
│      true,                      │
│    listenToUnitEvents: false    │
│  )                              │
└─────────┬───────────────────────┘
          │ Failed
          ├───────────▶ throw FailedToOpenIndex
          │ Success
          ▼
┌─────────────────────────────────┐
│ Store indexStore reference      │
│  self.indexStore = indexStore   │
└─────────┬───────────────────────┘
          │
          ▼
       READY
```

#### What is IndexStoreDB?

IndexStoreDB is Xcode's index database that powers:
- Code completion
- Jump to Definition
- Find References
- Symbol search

By tapping into this index, we can efficiently find symbols without parsing every file.

#### Protocol Conformance Discovery Flow

```
┌────────────────────────────────────────────────────────────────┐
│        findSymbolsConformingToProtocol(protocolName)           │
└────────────────────────────────────────────────────────────────┘

START
  │
  ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 1: Find Protocol's USR                                     │
├─────────────────────────────────────────────────────────────────┤
│ indexStore.forEachCanonicalSymbolOccurrence(                    │
│   containing: protocolName,                                     │
│   anchorStart: true, anchorEnd: true                            │
│ ) { occurrence in                                               │
│   if occurrence.symbol.kind == .protocol &&                     │
│      occurrence.symbol.name == protocolName {                   │
│     protocolUSR = occurrence.symbol.usr                         │
│     return false  // Stop iteration                             │
│   }                                                             │
│   return true  // Continue                                      │
│ }                                                               │
└─────────┬───────────────────────────────────────────────────────┘
          │
          ▼
     protocolUSR?
          │
          ├── nil ────────────────────┐
          │                           │
          ▼ Some(usr)                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 2: Find Conforming Types via .baseOf role                 │
├─────────────────────────────────────────────────────────────────┤
│ indexStore.forEachSymbolOccurrence(                             │
│   byUSR: protocolUSR,                                           │
│   roles: .baseOf                                                │
│ ) { occurrence in                                               │
│   // occurrence.location = where conformance is declared        │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ findTypeAtLocation(                                     │  │
│   │   filePath: occurrence.location.path,                   │  │
│   │   line: occurrence.location.line                        │  │
│   │ )                                                       │  │
│   │  │                                                      │  │
│   │  ▼                                                      │  │
│   │ ┌────────────────────────────────────────────────────┐ │  │
│   │ │ Search index for struct/class definition           │ │  │
│   │ │ at or near the line number                         │ │  │
│   │ └────────────────────────────────────────────────────┘ │  │
│   │  │                                                      │  │
│   │  ├─ Found ──▶ Add to foundSymbols                      │  │
│   │  │                                                      │  │
│   │  └─ Not Found ▼                                        │  │
│   │ ┌────────────────────────────────────────────────────┐ │  │
│   │ │ Read source file lines                             │ │  │
│   │ │ Extract type name from declaration                 │ │  │
│   │ │ Look up in index by name                           │ │  │
│   │ └────────────────────────────────────────────────────┘ │  │
│   └─────────────────────────────────────────────────────────┘  │
│   return true  // Continue iteration                            │
│ }                                                               │
└─────────┬───────────────────────────────────────────────────────┘
          │
          ▼
   foundSymbols.isEmpty?
          │
          ├── false ─────────────────┐
          │                          │
          ▼ true                     │
┌─────────────────────────────────────────────────────────────────┐
│ STEP 3: Fallback - Direct File System Scan                     │
├─────────────────────────────────────────────────────────────────┤
│ findSymbolsByProtocolFileScan(protocolName)                     │
│  │                                                              │
│  ▼                                                              │
│ ┌────────────────────────────────────────────────────────────┐ │
│ │ 1. Enumerate all .swift files in sourceRoot               │ │
│ │    FileManager.enumerator()                                │ │
│ └────────────────────┬───────────────────────────────────────┘ │
│                      ▼                                          │
│ ┌────────────────────────────────────────────────────────────┐ │
│ │ 2. For each .swift file:                                   │ │
│ │    Read content                                            │ │
│ └────────────────────┬───────────────────────────────────────┘ │
│                      ▼                                          │
│ ┌────────────────────────────────────────────────────────────┐ │
│ │ 3. Apply regex pattern:                                    │ │
│ │    (struct|class)\s+(\w+)\s*:\s*[^{]*\bProtocolName\b     │ │
│ │    Matches:                                                │ │
│ │      struct User: RootModel                                │ │
│ │      class Org: Codable, RootModel                         │ │
│ └────────────────────┬───────────────────────────────────────┘ │
│                      ▼                                          │
│ ┌────────────────────────────────────────────────────────────┐ │
│ │ 4. For each match:                                         │ │
│ │    - Extract type name                                     │ │
│ │    - Calculate line number                                 │ │
│ │    - Try to find in index for USR                          │ │
│ │    - If not in index, create synthetic symbol              │ │
│ │    - Add to foundSymbols                                   │ │
│ └────────────────────────────────────────────────────────────┘ │
└─────────┬───────────────────────────────────────────────────────┘
          │
          └──────────────────────────┐
                                     │
                                     ▼
                    ┌────────────────────────────────┐
                    │ Remove duplicates by USR       │
                    │ - Use Set<String> for tracking │
                    │ - Filter foundSymbols array    │
                    └────────────┬───────────────────┘
                                 │
                                 ▼
                        Return [IndexedSymbol]
```

#### Macro Annotation Discovery Flow

```
┌────────────────────────────────────────────────────────────────┐
│              findSymbolsWithMacro(macroName)                    │
└────────────────────────────────────────────────────────────────┘

START
  │
  ▼
┌─────────────────────────────────────────────────────────────────┐
│ APPROACH 1: Search Index for Macro References                  │
├─────────────────────────────────────────────────────────────────┤
│ indexStore.forEachCanonicalSymbolOccurrence(                    │
│   containing: macroName,                                        │
│   anchorStart: true, anchorEnd: true                            │
│ ) { occurrence in                                               │
│   if occurrence.roles.contains(.reference) {                    │
│     // This is where @MacroName is used                         │
│     ┌──────────────────────────────────────────────────────┐   │
│     │ findSymbolNearLocation(                              │   │
│     │   filePath: occurrence.location.path,                │   │
│     │   line: occurrence.location.line                     │   │
│     │ )                                                    │   │
│     │  │                                                   │   │
│     │  ▼                                                   │   │
│     │ Search for struct/class/enum definitions            │   │
│     │ within ±3 lines of macro reference                  │   │
│     │  │                                                   │   │
│     │  └─ Found ──▶ Add to foundSymbols                   │   │
│     └──────────────────────────────────────────────────────┘   │
│   }                                                             │
│   return true  // Continue                                      │
│ }                                                               │
└─────────┬───────────────────────────────────────────────────────┘
          │
          ▼
   foundSymbols.isEmpty?
          │
          ├── false ─────────────────┐
          │                          │
          ▼ true                     │
┌─────────────────────────────────────────────────────────────────┐
│ APPROACH 2: Scan All Definitions, Check Source                 │
├─────────────────────────────────────────────────────────────────┤
│ findSymbolsByScanning(macroName)                                │
│  │                                                              │
│  ▼                                                              │
│ indexStore.forEachCanonicalSymbolOccurrence { occurrence in    │
│   if (occurrence.symbol.kind in [.struct, .class, .enum]) &&   │
│      occurrence.roles.contains(.definition) {                   │
│     ┌──────────────────────────────────────────────────────┐   │
│     │ sourceContainsMacro(                                 │   │
│     │   filePath: occurrence.location.path,                │   │
│     │   symbolName: occurrence.symbol.name,                │   │
│     │   macroName: macroName,                              │   │
│     │   nearLine: occurrence.location.line                 │   │
│     │ )                                                    │   │
│     │  │                                                   │   │
│     │  ▼                                                   │   │
│     │ ┌────────────────────────────────────────────────┐  │   │
│     │ │ 1. Read source file                            │  │   │
│     │ │ 2. Check lines [nearLine-5 ... nearLine+1]    │  │   │
│     │ │ 3. Look for @MacroName                         │  │   │
│     │ │ 4. Verify symbol name appears nearby           │  │   │
│     │ └────────────────────────────────────────────────┘  │   │
│     │  │                                                   │   │
│     │  └─ true ──▶ Add symbol to foundSymbols             │   │
│     └──────────────────────────────────────────────────────┘   │
│   }                                                             │
│   return true                                                   │
│ }                                                               │
└─────────┬───────────────────────────────────────────────────────┘
          │
          ▼
   foundSymbols.isEmpty?
          │
          ├── false ─────────────────┐
          │                          │
          ▼ true                     │
┌─────────────────────────────────────────────────────────────────┐
│ APPROACH 3: Direct File System Scan (Most Reliable)            │
├─────────────────────────────────────────────────────────────────┤
│ findSymbolsByDirectFileScan(macroName)                          │
│  │                                                              │
│  ▼                                                              │
│ ┌────────────────────────────────────────────────────────────┐ │
│ │ 1. Enumerate all .swift files                              │ │
│ │    FileManager.enumerator(at: sourceRoot, ...)             │ │
│ └────────────────────┬───────────────────────────────────────┘ │
│                      ▼                                          │
│ ┌────────────────────────────────────────────────────────────┐ │
│ │ 2. For each .swift file:                                   │ │
│ │    Read content                                            │ │
│ └────────────────────┬───────────────────────────────────────┘ │
│                      ▼                                          │
│ ┌────────────────────────────────────────────────────────────┐ │
│ │ 3. Apply regex pattern:                                    │ │
│ │    @MacroName\s*\n?\s*                                     │ │
│ │    (public\s+|private\s+|...)?                             │ │
│ │    (struct|class)\s+(\w+)                                  │ │
│ │                                                            │ │
│ │    Matches:                                                │ │
│ │      @RootModel                                            │ │
│ │      struct User                                           │ │
│ │                                                            │ │
│ │      @RootModel                                            │ │
│ │      public class Organization                             │ │
│ └────────────────────┬───────────────────────────────────────┘ │
│                      ▼                                          │
│ ┌────────────────────────────────────────────────────────────┐ │
│ │ 4. For each match:                                         │ │
│ │    - Extract type kind (struct/class)                      │ │
│ │    - Extract type name                                     │ │
│ │    - Calculate line number                                 │ │
│ │    - Try findSymbolByName() for USR                        │ │
│ │    - If found: use indexed symbol                          │ │
│ │    - If not: create synthetic symbol                       │ │
│ │      with USR = "file://{path}#{name}"                     │ │
│ │    - Add to foundSymbols                                   │ │
│ └────────────────────────────────────────────────────────────┘ │
└─────────┬───────────────────────────────────────────────────────┘
          │
          └──────────────────────────┐
                                     │
                                     ▼
                    ┌────────────────────────────────┐
                    │ Remove duplicates by USR       │
                    └────────────┬───────────────────┘
                                 │
                                 ▼
                        Return [IndexedSymbol]
```

#### Symbol Lookup Flow

```
┌────────────────────────────────────────────────────────────────┐
│                  findSymbolByName(name)                         │
└────────────────────────────────────────────────────────────────┘

START: name = "User"
  │
  ▼
┌─────────────────────────────────────────────────────────────────┐
│ indexStore.forEachCanonicalSymbolOccurrence(                    │
│   containing: name,                                             │
│   anchorStart: true,  // Must start with "name"                 │
│   anchorEnd: true     // Must end with "name"                   │
│ ) { occurrence in                                               │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Check conditions:                                       │  │
│   │  1. occurrence.symbol.name == name  (exact match)       │  │
│   │  2. occurrence.symbol.kind in [.struct, .class, .enum]  │  │
│   │  3. occurrence.roles.contains(.definition)              │  │
│   └─────────────────┬───────────────────────────────────────┘  │
│                     │                                           │
│                     ├── All true ──▶ Create IndexedSymbol       │
│                     │                 return false (stop)       │
│                     │                                           │
│                     └── Any false ──▶ return true (continue)    │
│ }                                                               │
└─────────────────────────────────────────────────────────────────┘
  │
  ▼
Return IndexedSymbol? (nil if not found)

Example:
  Query: "User"
  Matches: "User", "UserManager", "AppUser"
  Filters to: "User" only (exact match)
  Returns: IndexedSymbol(name: "User", usr: "...", ...)
```

#### Key Concepts

**USR (Unified Symbol Resolution)**:
A unique identifier for every symbol in Swift. Think of it as a UUID for code elements.
Example: `s:14MyApp8UserV4nameSSmvp` identifies the `name` property in `User` struct.

**Symbol Kinds**:
- `.struct` - Structure types
- `.class` - Class types
- `.enum` - Enumeration types
- `.protocol` - Protocol definitions

**Symbol Roles**:
- `.definition` - Where the symbol is defined
- `.reference` - Where the symbol is used
- `.baseOf` - Protocol conformance relationships

#### Main Functions

**1. Finding Symbols by Protocol Conformance**:
```swift
func findSymbolsConformingToProtocol(protocolName: String) -> [IndexedSymbol]
```

**3-Step Process**:

**Step 1**: Find the protocol's USR
```swift
indexStore.forEachCanonicalSymbolOccurrence(containing: "RootModel") { occurrence in
    if occurrence.symbol.kind == .protocol && occurrence.symbol.name == "RootModel" {
        protocolUSR = occurrence.symbol.usr
    }
}
```

**Step 2**: Find conformances using the `.baseOf` role
```swift
indexStore.forEachSymbolOccurrence(byUSR: protocolUSR, roles: .baseOf) { occurrence in
    // This protocol is a base of another type
    // Find the conforming type at this location
}
```

**Step 3**: Fallback to direct file scanning
If IndexStoreDB doesn't have the relationships indexed (can happen with fresh builds), scan source files using regex:
```swift
let pattern = #"(struct|class)\s+(\w+)\s*:\s*[^{]*\bRootModel\b"#
// Matches: struct User: RootModel
//          class User: Codable, RootModel
```

**2. Finding Symbols with Macro Annotations**:
```swift
func findSymbolsWithMacro(macroName: String) -> [IndexedSymbol]
```

This is more complex because macros are a newer Swift feature and IndexStoreDB indexing of macros can vary.

**3-Approach Strategy**:

**Approach 1**: Search for macro references in the index
```swift
indexStore.forEachCanonicalSymbolOccurrence(containing: macroName) { occurrence in
    if occurrence.roles.contains(.reference) {
        // Found @RootModel macro usage
        // Find the type it's attached to
    }
}
```

**Approach 2**: Scan all definitions and check their source
```swift
indexStore.forEachCanonicalSymbolOccurrence { occurrence in
    if occurrence.symbol.kind == .struct || occurrence.symbol.kind == .class {
        // Check if source contains @RootModel near this symbol
    }
}
```

**Approach 3**: Direct file system scan (most reliable)
```swift
let pattern = #"@RootModel\s*\n?\s*(struct|class)\s+(\w+)"#
// Matches: @RootModel
//          struct User
```

**3. Finding Symbols by Name**:
```swift
func findSymbolByName(_ name: String) -> IndexedSymbol?
```

Used during graph building to find child types. Searches for exact name matches with struct/class/enum kind.

#### IndexedSymbol Data Structure

```swift
struct IndexedSymbol {
    let name: String           // "User"
    let usr: String            // "s:14MyApp4UserV"
    let kind: IndexSymbolKind  // .struct, .class, .enum
    let filePath: String       // "/path/to/User.swift"
    let line: Int              // 15
    let column: Int            // 8
}
```

**Complete Execution Flow:**

```
Main.run()
  └─▶ findDefaultIndexStore() if needed
  └─▶ Initialize IndexStoreManager
      └─▶ Load libIndexStore.dylib
      └─▶ Initialize IndexStoreDB
      └─▶ Create SymbolRepository
      └─▶ Create InheritanceRepository
      └─▶ Create DiscoveryCoordinator
          └─▶ Initialize ProtocolDiscovery
          └─▶ Initialize MacroDiscovery
          └─▶ Initialize KnotDiscovery
  └─▶ Find Root Symbols (Phase 1)
      └─▶ if useMacro:
          └─▶ indexManager.findSymbolsWithMacroUsingSourceKit()
              └─▶ MacroDiscovery.findSymbolsAnnotated()
              └─▶ Extract parameters from annotations
              └─▶ Returns [(symbol, parameters)]
      └─▶ else:
          └─▶ indexManager.findSymbolsConformingToProtocol()
              └─▶ ProtocolDiscovery.findSymbolsConforming()
              └─▶ Returns [symbol]
  └─▶ Initialize GraphBuilder (Phase 2)
      └─▶ Create SwiftFileParser
      └─▶ Create CycleDetector
      └─▶ Create SymbolProcessor
  └─▶ Build Graph (Phase 3)
      └─▶ graphBuilder.buildGraph(rootSymbolsWithParams)
          └─▶ For each (symbol, parameters):
              └─▶ cycleDetector.resetVisited()
              └─▶ symbolProcessor.processSymbol(symbol, schemaId, 0)
                  ├─▶ Check if visited (cycle)
                  ├─▶ Check cache
                  ├─▶ Mark as visited
                  ├─▶ Get inheritance chain
                  ├─▶ Collect inherited properties
                  ├─▶ parser.extractProperties()
                  ├─▶ CodingKeysParser.extractCodingKeys()
                  ├─▶ processProperties()
                  │   └─▶ For each property:
                  │       ├─▶ Check @PolymorphicMapping
                  │       ├─▶ Build PropertyInfo with codingKey
                  │       ├─▶ If polymorphic:
                  │       │   └─▶ Process variants recursively
                  │       ├─▶ If custom type:
                  │       │   └─▶ Find in index
                  │       │   └─▶ Recurse: processSymbol(child)
                  │       └─▶ Add child to children
                  ├─▶ Build ModelNode
                  └─▶ Cache node
  └─▶ Find Knot Schemas (Phase 3b, if jsonSchema)
      └─▶ knotDiscovery.findAllKnotSymbols()
      └─▶ Process each knot with graphBuilder
  └─▶ Convert to Output Format (Phase 4)
      └─▶ if jsonSchema:
          └─▶ JSONSchemaConverter.convert(graph)
          └─▶ KnotSchemaConverter.convert(knots)
      └─▶ else:
          └─▶ JSONEncoder.encode(graph)
  └─▶ Write Files (Phase 5)
      └─▶ Write main output file
      └─▶ Write knot schemas file (if any)
```

---

### 2a. Discovery Layer - Specialized Symbol Finders

**Purpose**: Encapsulate different strategies for finding symbols in the codebase.

#### Architecture

The Discovery Layer consists of three specialized services coordinated by DiscoveryCoordinator:

```
┌─────────────────────────────────────────────────────────────────┐
│                    DiscoveryCoordinator                          │
├─────────────────────────────────────────────────────────────────┤
│ Public Methods:                                                  │
│  + findRootModels() -> [IndexedSymbol]                          │
│  + findAllKnots() -> [KnotType: [IndexedSymbol]]               │
│  + findSymbolsConforming(to:) -> [IndexedSymbol]               │
│  + findSymbolsWithMacro(_:) -> [IndexedSymbol]                 │
└───────────────┬────────────────┬────────────────┬──────────────┘
                │                │                │
                ▼                ▼                ▼
    ┌───────────────────┐ ┌──────────────┐ ┌─────────────┐
    │ProtocolDiscovery  │ │MacroDiscovery│ │KnotDiscovery│
    └───────────────────┘ └──────────────┘ └─────────────┘
```

#### 1. ProtocolDiscovery

**Purpose**: Find types conforming to specified protocols.

**Strategy:**
1. Find protocol's USR in IndexStoreDB
2. Query all symbols with `.baseOf` relationship to that protocol
3. Resolve symbol details for each conformance
4. Fallback to direct file scanning if index is incomplete

**Example:**
```swift
let discovery = ProtocolDiscovery(indexStore: indexStore, ...)
let symbols = try discovery.findSymbolsConforming(to: "RootModel")
// Returns all struct/class types that conform to RootModel protocol
```

#### 2. MacroDiscovery

**Purpose**: Find types annotated with specified macros.

**Multi-Strategy Approach:**

**Approach 1**: Search index for macro references
- Fast but may miss some annotations (index limitations)

**Approach 2**: Scan all type definitions and check source
- More reliable, checks actual source code near definitions

**Approach 3**: Direct file system scan with regex
- Most reliable, finds all @Macro annotations in source files
- Used as primary strategy

**Example:**
```swift
let discovery = MacroDiscovery(indexStore: indexStore, ...)
let symbols = try discovery.findSymbolsAnnotated(with: "ChimeraSchema")
// Returns all types with @ChimeraSchema annotation
```

**Parameter Extraction:**
Can also extract macro parameters from annotations:
```swift
let results = try discovery.findSymbolsWithMacroUsingSourceKit(
    macroName: "ChimeraSchema",
    sourcePath: sourcePath
)
// Returns [(symbol, parameters)] where parameters includes "key", etc.
```

#### 3. KnotDiscovery

**Purpose**: Find Knot-annotated schemas (@ChimeraMultiKnot, @ChimeraMapKnot).

**Knot Types:**
- `multiKnot` - @ChimeraMultiKnot(schemaId="...", subSchemas=[...])
- `mapKnot` - @ChimeraMapKnot(schemaId="...", subSchemas=[...])

**Process:**
1. Delegates to MacroDiscovery to find all knot annotations
2. Parses macro parameters to extract schemaId and subSchemas
3. Returns dictionary mapping knot types to symbols with metadata

**Example:**
```swift
let discovery = KnotDiscovery(macroDiscovery: macroDiscovery, ...)
let knots = try discovery.findAllKnotSymbols()
// Returns [.multiKnot: [...], .mapKnot: [...]]
```

#### 4. DiscoveryCoordinator

**Purpose**: Unified interface for all discovery operations.

**Key Features:**
- Coordinates between different discovery strategies
- Deduplicates results (same symbol found via different methods)
- Provides consistent logging across all discoveries
- Handles discovery failures gracefully

**Usage in Main.swift:**
```swift
let coordinator = DiscoveryCoordinator(
    indexStore: indexStore,
    symbolRepository: symbolRepository,
    sourceRoot: sourcePath,
    logger: logger
)

// Find all root models using any available strategy
let rootSymbols = try coordinator.findRootModels()

// Find all knot schemas
let knotSymbols = try coordinator.findAllKnots()
```

**Benefits of Separation:**
- Each discovery strategy is independently testable
- Easy to add new discovery methods
- Clear single responsibility for each service
- Better error handling per strategy

---

### 3. PropertyExtractor.swift - AST Analysis Engine

**Purpose**: Parse Swift source files using SwiftSyntax to extract properties and their types.

#### Class Architecture

```
┌───────────────────────────────────────────────────────────────────┐
│                    PropertyExtractorVisitor                        │
│                    : SyntaxVisitor                                 │
├───────────────────────────────────────────────────────────────────┤
│ Private Properties:                                                │
│  - properties: [ExtractedProperty]                                 │
│  - enumCases: [EnumCaseInfo]                                       │
│  - targetTypeName: String?                                         │
│  - insideTargetType: Bool                                          │
│  - scopeDepth: Int                                                 │
├───────────────────────────────────────────────────────────────────┤
│ Visit Methods (from SyntaxVisitor):                                │
│  • visit(_ node: StructDeclSyntax)                                 │
│  • visitPost(_ node: StructDeclSyntax)                             │
│  • visit(_ node: ClassDeclSyntax)                                  │
│  • visitPost(_ node: ClassDeclSyntax)                              │
│  • visit(_ node: EnumDeclSyntax)                                   │
│  • visitPost(_ node: EnumDeclSyntax)                               │
│  • visit(_ node: VariableDeclSyntax)                               │
├───────────────────────────────────────────────────────────────────┤
│ Private Methods:                                                   │
│  - extractTypeInfo(from: TypeSyntax) -> TypeInfo?                  │
│  - inferType(from: ExprSyntax) -> TypeInfo?                        │
└───────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────┐
│                    SwiftFileParser                                 │
├───────────────────────────────────────────────────────────────────┤
│ Private Properties:                                                │
│  - logger: Logger                                                  │
├───────────────────────────────────────────────────────────────────┤
│ Public Methods:                                                    │
│  + extractProperties(fromFile, typeName)                           │
│    -> (properties, enumCases)                                      │
│  + extractProperties(from sourceCode, typeName)                    │
│    -> (properties, enumCases)                                      │
│  + extractTypeNames(fromFile) -> [String]                          │
└───────────────────────────────────────────────────────────────────┘
```

#### SwiftFileParser Flow

```
┌────────────────────────────────────────────────────────────────┐
│         extractProperties(fromFile, typeName)                   │
└────────────────────────────────────────────────────────────────┘

START: filePath, typeName = "User"
  │
  ▼
┌─────────────────────────────────┐
│ Validate file exists            │
│  FileManager.fileExists()       │
└─────────┬───────────────────────┘
          │ No
          ├────────▶ throw SourceFileNotFound
          │ Yes
          ▼
┌─────────────────────────────────┐
│ Read file contents              │
│  String(contentsOf: url)        │
└─────────┬───────────────────────┘
          │
          ▼
┌─────────────────────────────────┐
│ Parse Swift source              │
│  Parser.parse(source: code)     │
│  Returns: SourceFileSyntax      │
└─────────┬───────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│ Create PropertyExtractorVisitor                             │
│  visitor = PropertyExtractorVisitor(                        │
│    targetTypeName: typeName                                 │
│  )                                                          │
└─────────┬───────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│ Walk the syntax tree                                        │
│  visitor.walk(sourceFile)                                   │
│   │                                                         │
│   └─▶ Triggers visit() methods for each node               │
│       as it traverses the AST                               │
└─────────┬───────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────┐
│ Extract results                 │
│  properties = visitor.properties│
│  enumCases = visitor.enumCases  │
└─────────┬───────────────────────┘
          │
          ▼
    Return (properties, enumCases)
```

#### PropertyExtractorVisitor - AST Traversal Flow

```
┌────────────────────────────────────────────────────────────────┐
│              AST Traversal for "struct User"                    │
└────────────────────────────────────────────────────────────────┘

SourceFileSyntax
  │
  ├─ visit(SourceFileSyntax) ────▶ Continue
  │
  └─▶ CodeBlockItemListSyntax
       │
       ├─ visit(...) ────▶ Continue
       │
       └─▶ StructDeclSyntax (name: "User")
            │
            ├─ visit(StructDeclSyntax)
            │   │
            │   ├─ node.name.text == "User"
            │   ├─ targetTypeName == "User"
            │   ├─ Match! ──▶ insideTargetType = true
            │   └─ Return .visitChildren
            │
            └─▶ MemberBlockSyntax
                 │
                 └─▶ MemberBlockItemListSyntax
                      │
                      ├─▶ VariableDeclSyntax (let id: String)
                      │    │
                      │    ├─ visit(VariableDeclSyntax)
                      │    │   │
                      │    │   ├─ insideTargetType? Yes
                      │    │   ├─ Check modifiers (static/class) ─ None
                      │    │   ├─ Check accessor block ─ None
                      │    │   ├─ Process bindings:
                      │    │   │   ├─ Pattern: "id"
                      │    │   │   ├─ Type annotation: "String"
                      │    │   │   ├─ extractTypeInfo("String")
                      │    │   │   │    └─▶ IdentifierTypeSyntax
                      │    │   │   │         └─▶ TypeInfo(
                      │    │   │   │              typeName: "String",
                      │    │   │   │              isOptional: false,
                      │    │   │   │              isArray: false, ...
                      │    │   │   │            )
                      │    │   │   └─ Create ExtractedProperty
                      │    │   │       properties.append(...)
                      │    │   └─ Return .skipChildren
                      │    │
                      │    
                      ├─▶ VariableDeclSyntax (let name: String?)
                      │    │
                      │    ├─ visit(VariableDeclSyntax)
                      │    │   ├─ Pattern: "name"
                      │    │   ├─ Type: OptionalTypeSyntax
                      │    │   ├─ extractTypeInfo(OptionalTypeSyntax)
                      │    │   │    ├─ Unwrap to IdentifierTypeSyntax
                      │    │   │    └─▶ TypeInfo(
                      │    │   │         typeName: "String",
                      │    │   │         isOptional: true, ...
                      │    │   │       )
                      │    │   └─ properties.append(...)
                      │
                      ├─▶ VariableDeclSyntax (let orders: [Order])
                      │    │
                      │    ├─ visit(VariableDeclSyntax)
                      │    │   ├─ Pattern: "orders"
                      │    │   ├─ Type: ArrayTypeSyntax
                      │    │   ├─ extractTypeInfo(ArrayTypeSyntax)
                      │    │   │    ├─ Extract element type
                      │    │   │    └─▶ TypeInfo(
                      │    │   │         typeName: "Order",
                      │    │   │         isArray: true, ...
                      │    │   │       )
                      │    │   └─ properties.append(...)
                      │
                      └─▶ VariableDeclSyntax (var computed: String { ... })
                           │
                           ├─ visit(VariableDeclSyntax)
                           │   ├─ Pattern: "computed"
                           │   ├─ Has accessor block
                           │   ├─ Check accessors:
                           │   │   ├─ Has getter: true
                           │   │   ├─ Has setter: false
                           │   │   ├─ Has willSet: false
                           │   │   ├─ Has didSet: false
                           │   ├─ Only getter ──▶ Computed property
                           │   └─ SKIP (don't add to properties)
                           │
            ├─ visitPost(StructDeclSyntax)
            │   └─▶ insideTargetType = false
            │
            ▼
      END: visitor.properties = [id, name, orders]
```

#### Type Extraction Algorithm

```
┌────────────────────────────────────────────────────────────────┐
│             extractTypeInfo(from: TypeSyntax)                   │
└────────────────────────────────────────────────────────────────┘

Input: TypeSyntax node
  │
  ▼
┌──────────────────────────────────┐
│ Is OptionalTypeSyntax? (Type?)   │
└──────┬───────────────────────────┘
       │ Yes
       ├─▶ Extract wrappedType
       │   Recursively call extractTypeInfo(wrappedType)
       │   Return TypeInfo(..., isOptional: true)
       │
       │ No
       ▼
┌──────────────────────────────────┐
│ Is ImplicitlyUnwrapped? (Type!)  │
└──────┬───────────────────────────┘
       │ Yes
       ├─▶ Extract wrappedType
       │   Return TypeInfo(..., isOptional: true)
       │
       │ No
       ▼
┌──────────────────────────────────┐
│ Is ArrayTypeSyntax? ([Type])     │
└──────┬───────────────────────────┘
       │ Yes
       ├─▶ Extract element type
       │   Recursively call extractTypeInfo(element)
       │   Return TypeInfo(..., isArray: true)
       │
       │ No
       ▼
┌──────────────────────────────────┐
│ Is DictionaryTypeSyntax?         │
│ ([Key: Value])                   │
└──────┬───────────────────────────┘
       │ Yes
       ├─▶ Extract key and value types
       │   key = extractTypeInfo(dict.key)
       │   value = extractTypeInfo(dict.value)
       │   Return TypeInfo(
       │     typeName: value.typeName,
       │     isDictionary: true,
       │     genericTypes: [key, value]
       │   )
       │
       │ No
       ▼
┌──────────────────────────────────────────────────────────────┐
│ Is IdentifierTypeSyntax?                                     │
│ (SimpleType or Generic<Type>)                                │
└──────┬───────────────────────────────────────────────────────┘
       │
       ├─ Has generic arguments?
       │   │
       │   ├─ Yes ─▶ baseName = identifier.name.text
       │   │         args = genericArgumentClause.arguments
       │   │         │
       │   │         ├─ baseName == "Array"?
       │   │         │   └─▶ Return TypeInfo(..., isArray: true)
       │   │         │
       │   │         ├─ baseName == "Set"?
       │   │         │   └─▶ Return TypeInfo(..., isSet: true)
       │   │         │
       │   │         ├─ baseName == "Optional"?
       │   │         │   └─▶ Return TypeInfo(..., isOptional: true)
       │   │         │
       │   │         ├─ baseName == "Dictionary"?
       │   │         │   └─▶ Return TypeInfo(..., isDictionary: true)
       │   │         │
       │   │         └─ Other generic
       │   │             └─▶ Return TypeInfo(typeName: baseName, ...)
       │   │
       │   └─ No ──▶ Simple identifier
       │             Return TypeInfo(typeName: baseName, ...)
       │
       │ No
       ▼
┌──────────────────────────────────┐
│ Is MemberTypeSyntax?             │
│ (Module.Type)                    │
└──────┬───────────────────────────┘
       │ Yes
       ├─▶ Return TypeInfo(
       │     typeName: fullName,  // "Swift.String"
       │     ...
       │   )
       │
       │ No
       ▼
┌──────────────────────────────────┐
│ Is TupleTypeSyntax?              │
│ ((Type, Type))                   │
└──────┬───────────────────────────┘
       │ Yes
       ├─▶ Return TypeInfo(
       │     typeName: "Tuple",
       │     ...
       │   )
       │
       │ No
       ▼
┌──────────────────────────────────┐
│ Is AttributedTypeSyntax?         │
│ (@escaping Type)                 │
└──────┬───────────────────────────┘
       │ Yes
       ├─▶ Extract baseType
       │   Recursively call extractTypeInfo(baseType)
       │
       │ No
       ▼
┌──────────────────────────────────┐
│ Fallback: Use trimmedDescription│
│ Return TypeInfo(                 │
│   typeName: type.description,    │
│   ...                            │
│ )                                │
└──────────────────────────────────┘

Example Flows:

String? ──▶ OptionalTypeSyntax
            └─▶ wrappedType: IdentifierTypeSyntax("String")
                └─▶ TypeInfo(typeName: "String", isOptional: true)

[User] ──▶ ArrayTypeSyntax
           └─▶ element: IdentifierTypeSyntax("User")
               └─▶ TypeInfo(typeName: "User", isArray: true)

Set<String>? ──▶ OptionalTypeSyntax
                 └─▶ IdentifierTypeSyntax("Set")
                     └─▶ genericArgs: ["String"]
                         └─▶ TypeInfo(typeName: "String", 
                                      isSet: true, 
                                      isOptional: true)

[String: User] ──▶ DictionaryTypeSyntax
                   ├─▶ key: "String"
                   └─▶ value: "User"
                       └─▶ TypeInfo(typeName: "User",
                                    isDictionary: true,
                                    genericTypes: ["String", "User"])
```

#### Property Filtering Logic

```
┌────────────────────────────────────────────────────────────────┐
│          Property Classification Decision Tree                 │
└────────────────────────────────────────────────────────────────┘

VariableDeclSyntax
  │
  ├─ Check: insideTargetType?
  │   └─ No ──▶ SKIP (return .skipChildren)
  │
  ├─ Check: Has "static" modifier?
  │   └─ Yes ──▶ SKIP (static properties excluded)
  │
  ├─ Check: Has "class" modifier?
  │   └─ Yes ──▶ SKIP (class properties excluded)
  │
  ├─ Check: Has accessor block?
  │   │
  │   ├─ No ──▶ STORED PROPERTY
  │   │         (Continue to type extraction)
  │   │
  │   └─ Yes ──▶ Analyze accessors
  │              │
  │              ├─ Has only getter (no setter/willSet/didSet)?
  │              │   └─ Yes ──▶ COMPUTED PROPERTY ──▶ SKIP
  │              │
  │              └─ Has setter or observers?
  │                  └─ Yes ──▶ STORED WITH OBSERVERS
  │                            (Continue to type extraction)
  │
  └─ Extract type information
      │
      ├─ Has type annotation? (let x: Type)
      │   └─ Yes ──▶ extractTypeInfo(typeAnnotation.type)
      │              └─▶ Create ExtractedProperty
      │
      └─ No type annotation? (let x = value)
          └─▶ Try inferType(from: initializer.value)
              ├─ Success ──▶ Create ExtractedProperty
              └─ Failure ──▶ SKIP

Examples:

✓ INCLUDE:
  let name: String
  var age: Int
  var count: Int { didSet { ... } }
  var value: String { willSet { ... } }
  lazy var data: Data = ...

✗ EXCLUDE:
  static let shared = ...
  class var count = 0
  var computed: String { return "..." }
  var getOnly: Int { get { return 42 } }
```

#### Why SwiftSyntax?

While IndexStoreDB knows about symbols and their locations, it doesn't give us detailed property information. SwiftSyntax parses the actual Swift syntax tree (AST) to extract:
- Property names
- Property types (including generics)
- Optional/Array/Set/Dictionary wrappers
- Enum cases with associated values

#### Core Components

**1. PropertyExtractorVisitor**

A `SyntaxVisitor` that walks through the Abstract Syntax Tree (AST) and collects properties.

**Visitor Pattern**:
```swift
class PropertyExtractorVisitor: SyntaxVisitor {
    // Called when entering a struct declaration
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind
    
    // Called when entering a variable declaration
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind
    
    // Called when entering an enum declaration
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind
}
```

**Scope Tracking**:
The visitor tracks whether it's inside the target type to avoid capturing properties from nested types:
```swift
private var insideTargetType = false

override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    if node.name.text == targetTypeName {
        insideTargetType = true
    }
}
```

**2. Type Information Extraction**

This is the most complex part - accurately determining property types.

**Supported Type Patterns**:

**Simple Types**:
```swift
let name: String        // -> typeName: "String", isOptional: false
```

**Optional Types**:
```swift
let name: String?       // -> typeName: "String", isOptional: true
let name: String!       // -> typeName: "String", isOptional: true
let name: Optional<String> // -> typeName: "String", isOptional: true
```

**Array Types**:
```swift
let tags: [String]      // -> typeName: "String", isArray: true
let tags: Array<String> // -> typeName: "String", isArray: true
```

**Set Types**:
```swift
let ids: Set<String>    // -> typeName: "String", isSet: true
```

**Dictionary Types**:
```swift
let map: [String: Int]  // -> typeName: "Int", isDictionary: true
                        //    genericTypes: ["String", "Int"]
```

**Nested Generics**:
```swift
let items: [User]?      // -> typeName: "User", isArray: true, isOptional: true
let data: Set<User?>    // -> typeName: "User", isSet: true, isOptional: true
```

**3. Type Extraction Algorithm**

The `extractTypeInfo` function uses recursive pattern matching:

```swift
private func extractTypeInfo(from type: TypeSyntax) -> TypeInfo? {
    // 1. Check if it's Optional (Type?)
    if let optionalType = type.as(OptionalTypeSyntax.self) {
        let inner = extractTypeInfo(from: optionalType.wrappedType)
        return TypeInfo(typeName: inner.typeName, isOptional: true, ...)
    }
    
    // 2. Check if it's Array ([Type])
    if let arrayType = type.as(ArrayTypeSyntax.self) {
        let element = extractTypeInfo(from: arrayType.element)
        return TypeInfo(typeName: element.typeName, isArray: true, ...)
    }
    
    // 3. Check if it's Dictionary ([Key: Value])
    if let dictType = type.as(DictionaryTypeSyntax.self) {
        // Extract both key and value types
    }
    
    // 4. Check if it's Generic (Array<Type>, Set<Type>, etc.)
    if let identifierType = type.as(IdentifierTypeSyntax.self) {
        let baseName = identifierType.name.text
        if let genericArgs = identifierType.genericArgumentClause {
            // Handle Array<T>, Set<T>, Optional<T>, Dictionary<K,V>
        }
    }
}
```

**4. Property Filtering**

Not all `var` declarations are stored properties:

**Excluded**:
- Static properties: `static var count = 0`
- Class properties: `class var shared = ...`
- Computed properties: `var fullName: String { ... }`
- Properties with only getter: `var computed: String { get { ... } }`

**Included**:
- Stored properties: `let name: String`
- Properties with observers: `var age: Int { didSet { ... } }`
- Properties with explicit storage: `var count: Int = 0`

**Detection Logic**:
```swift
// Skip static/class modifiers
for modifier in node.modifiers {
    if modifier.name.text == "static" || modifier.name.text == "class" {
        return .skipChildren
    }
}

// Check accessor block
if let accessor = binding.accessorBlock {
    if case .accessors(let accessors) = accessor.accessors {
        let hasGetter = accessors.contains { $0.accessorSpecifier.text == "get" }
        let hasSetter = accessors.contains { $0.accessorSpecifier.text == "set" }
        
        // If only getter without setter/observers, it's computed
        if hasGetter && !hasSetter && !hasWillSet && !hasDidSet {
            continue
        }
    }
}
```

**5. Enum Case Extraction**

For enum types, the visitor also extracts case information:

```swift
enum Status {
    case active                          // Simple case
    case pending(reason: String)         // Associated value
    case failed(code: Int, message: String)  // Multiple values
}

// Extracted as:
[
    EnumCaseInfo(name: "active", associatedValues: [], rawValue: nil),
    EnumCaseInfo(name: "pending", associatedValues: ["String"], rawValue: nil),
    EnumCaseInfo(name: "failed", associatedValues: ["Int", "String"], rawValue: nil)
]
```

**6. SwiftFileParser Wrapper**

The high-level interface for using the visitor:

```swift
class SwiftFileParser {
    func extractProperties(fromFile filePath: String, typeName: String) 
        -> (properties: [ExtractedProperty], enumCases: [EnumCaseInfo])
}
```

**Usage**:
```swift
let parser = SwiftFileParser(logger: logger)
let result = try parser.extractProperties(
    fromFile: "/path/to/User.swift",
    typeName: "User"
)
// result.properties: [ExtractedProperty]
// result.enumCases: [EnumCaseInfo]
```

---

### 3a. Additional Parser Components

The Parser layer includes several specialized parsers beyond PropertyExtractor:

#### 1. CodingKeysParser

**Purpose**: Extract custom JSON key mappings from `CodingKeys` enums.

**How It Works:**
```swift
// In Swift code:
struct User: Codable {
    let firstName: String
    let lastName: String
    
    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"  // Maps to different JSON key
        case lastName = "last_name"
    }
}

// CodingKeysParser extracts:
[
    "firstName": "first_name",
    "lastName": "last_name"
]
```

**Usage:**
```swift
let codingKeys = CodingKeysParser.extractCodingKeys(
    from: filePath,
    typeName: "User"
)
// Returns: [String: String?]
// nil value means no custom mapping (uses property name)
```

**Implementation:**
- Parses file with SwiftSyntax
- Uses `CodingKeysVisitor` to find CodingKeys enum inside target type
- Supports both type declarations and extensions
- Extracts string raw values from enum cases

#### 2. PolymorphicParser

**Purpose**: Extract `@PolymorphicMapping` annotation details for runtime type discrimination.

**What Is Polymorphic Mapping:**
```swift
struct Order {
    @PolymorphicMapping(
        discriminator: "type",
        variants: [
            "credit": CreditPayment.self,
            "debit": DebitPayment.self,
            "upi": UPIPayment.self
        ]
    )
    let payment: Payment  // Can be any variant at runtime
}
```

**Extracted Information:**
```swift
struct PolymorphicMapping {
    let discriminatorKey: String     // "type"
    let variants: [String: String]   // ["credit": "CreditPayment", ...]
}
```

**Usage:**
```swift
let mapping = PolymorphicParser.extractPolymorphicMapping(
    from: filePath,
    typeName: "Order",
    propertyName: "payment"
)
// mapping contains discriminator key and variant mappings
```

**Features:**
- SwiftSyntax-based parsing (primary)
- Regex-based fallback for reliability
- Handles protocol-based polymorphism detection
- Validates variant type names

#### 3. KnotParser

**Purpose**: Parse knot schema metadata from `@ChimeraMultiKnot` and `@ChimeraMapKnot` annotations.

**Knot Types:**
```swift
// Multi-Knot: Defines sub-schema array
@ChimeraMultiKnot(
    schemaId: "payment_methods",
    subSchemas: [CreditCard.class, DebitCard.class, UPI.class]
)
struct PaymentMethodsKnot { ... }

// Map-Knot: Defines sub-schema map
@ChimeraMapKnot(
    schemaId: "vehicle_registry",
    subSchemas: [Car.class, Bike.class, Truck.class]
)
struct VehicleRegistry { ... }
```

**Extracted Information:**
```swift
struct KnotInfo {
    let knotType: KnotType               // .multiKnot or .mapKnot
    let schemaId: String                 // "payment_methods"
    let subSchemas: [String]             // ["CreditCard", "DebitCard", "UPI"]
    let originalSubSchemas: [String]     // Original with .class suffix
}
```

**Usage:**
```swift
let knotInfo = KnotParser.extractKnotInfo(
    from: filePath,
    typeName: "PaymentMethodsKnot"
)
```

**Processing:**
- Removes `.class` suffix from type names
- Supports both ClassName.class and ClassName formats
- Validates schemaId presence
- Returns nil for non-knot types

#### 4. EnumExtractor

**Purpose**: Extract enum cases with their associated values and raw values.

**What It Extracts:**
```swift
enum Status: String {
    case active = "ACTIVE"
    case pending = "PENDING"
    case cancelled(reason: String)
    case failed(code: Int, message: String)
}

// Extracted as:
[
    EnumCaseInfo(
        name: "active",
        associatedValues: [],
        rawValue: "ACTIVE"
    ),
    EnumCaseInfo(
        name: "pending",
        associatedValues: [],
        rawValue: "PENDING"
    ),
    EnumCaseInfo(
        name: "cancelled",
        associatedValues: ["String"],
        rawValue: nil
    ),
    EnumCaseInfo(
        name: "failed",
        associatedValues: ["Int", "String"],
        rawValue: nil
    )
]
```

**Features:**
- Handles simple enums
- Extracts associated value types
- Captures raw values (String, Int, etc.)
- Supports labeled and unlabeled associated values

#### 5. TypeAnalyzer

**Purpose**: Analyze and classify Swift types for proper handling.

**Type Classification:**
```swift
TypeAnalyzer.classify("String")      // .primitive
TypeAnalyzer.classify("User")        // .custom
TypeAnalyzer.classify("[User]")      // .array(elementType: "User")
TypeAnalyzer.classify("User?")       // .optional(wrappedType: "User")
TypeAnalyzer.classify("Set<User>")   // .set(elementType: "User")
TypeAnalyzer.classify("[String: User]") // .dictionary(key: "String", value: "User")
```

**Utilities:**
- `isPrimitive(typeName:)` - Check if type is Swift/Foundation primitive
- `isSystemType(typeName:)` - Check if type is from system frameworks
- `isGenericPlaceholder(typeName:)` - Check for T, U, V generic parameters
- `stripOptional(typeName:)` - Remove optional wrapper
- `extractGenericTypes(typeName:)` - Parse generic parameters

**Usage in SymbolProcessor:**
```swift
if TypeAnalyzer.isPrimitive(property.typeName) {
    // Skip, don't explore primitive types
} else if TypeAnalyzer.isSystemType(property.typeName) {
    // Skip, don't explore framework types
} else {
    // Custom type, explore recursively
    indexManager.findSymbolByName(property.typeName)
}
```

---

### 4. GraphBuilding Layer - Complete Architecture

The GraphBuilding layer is now separated into three specialized components working together:

#### Component Overview

```
┌────────────────────────────────────────────────────────────────┐
│                      GraphBuilder                               │
│                    (Orchestrator)                               │
│                                                                 │
│  - Initializes all components                                  │
│  - Handles root symbol iteration                               │
│  - Coordinates between SymbolProcessor and CycleDetector       │
│  - Builds final ModelGraph                                     │
└────────────┬───────────────────────────────┬───────────────────┘
             │                               │
             ▼                               ▼
┌────────────────────────────┐  ┌──────────────────────────────┐
│    SymbolProcessor         │  │      CycleDetector           │
│   (Processing Logic)       │  │   (State Management)         │
│                            │  │                              │
│  - Process symbols         │  │  - Track visited USRs        │
│  - Extract properties      │  │  - Cache nodes               │
│  - Handle inheritance      │  │  - Create cyclic nodes       │
│  - Check polymorphism      │  │  - Reset between roots       │
│  - Recurse children        │  │                              │
│  - Build ModelNode         │  │                              │
└────────────────────────────┘  └──────────────────────────────┘
```

#### 4a. SymbolProcessor - The Core Processor

**Purpose**: Recursively process symbols and build their node representations.

**Key Features:**
- Polymorphic type support with depth limits
- Inheritance chain handling
- CodingKeys integration
- Polymorphic mapping detection
- Recursive child processing with cycle prevention

**Complete Processing Flow:**

```
processSymbol(symbol, schemaId, depth, isPolymorphic, polymorphicDepth)
  │
  ├─▶ [1] Check polymorphic depth limit (max 10)
  │     └─ if exceeded: return nil
  │
  ├─▶ [2] Check if visited (cycle detection)
  │     └─ if visited: return cyclicNode placeholder
  │
  ├─▶ [3] Check cache
  │     └─ if cached: return cached as cyclic (different branch)
  │
  ├─▶ [4] Mark as visited (BEFORE processing children!)
  │
  ├─▶ [5] Get inheritance chain
  │     └─ indexManager.getInheritanceChain()
  │
  ├─▶ [6] Collect inherited properties
  │     └─ collectInheritedProperties(inheritanceChain)
  │         └─ For each parent:
  │             ├─ Extract parent properties
  │             ├─ Find original declaration in chain
  │             ├─ Get CodingKeys for parent
  │             └─ Build InheritedPropertyInfo
  │
  ├─▶ [7] Extract properties and enum cases
  │     └─ parser.extractProperties(filePath, typeName)
  │
  ├─▶ [8] Extract CodingKeys
  │     └─ CodingKeysParser.extractCodingKeys(filePath, typeName)
  │
  ├─▶ [9] Process properties to find children
  │     └─ processProperties(properties, symbol, codingKeys, depth, ...)
  │         └─ For each property:
  │             ├─ Check for @PolymorphicMapping
  │             │   └─ PolymorphicParser.extractPolymorphicMapping()
  │             ├─ Get CodingKey
  │             ├─ Build PropertyInfo with codingKey
  │             ├─ If polymorphic:
  │             │   └─ processPolymorphicVariants()
  │             │       └─ For each variant:
  │             │           └─ Recurse: processSymbol(variant, depth+1, poly+1)
  │             └─ If custom type (not primitive/system):
  │                 ├─ Find in index: indexManager.findSymbolByName()
  │                 └─ Recurse: processSymbol(child, depth+1)
  │
  ├─▶ [10] Build ModelNode
  │     └─ ModelNode(name, kind, filePath, schemaId, inheritsFrom, 
  │                  inheritedProperties, properties, enumCases,
  │                  children, isCyclic, isPolymorphic)
  │
  ├─▶ [11] Cache the node
  │     └─ cycleDetector.cacheNode(node, for: usr)
  │
  └─▶ [12] Return node
```

**Polymorphic Handling:**
```swift
// When @PolymorphicMapping found on property:
@PolymorphicMapping(
    discriminator: "type",
    variants: ["dog": Dog.self, "cat": Cat.self]
)
let animal: Animal

// SymbolProcessor:
1. Extracts mapping: {discriminator: "type", variants: ["dog": "Dog", "cat": "Cat"]}
2. For each variant:
   - Finds variant symbol in index
   - Processes recursively with isPolymorphic=true, polymorphicDepth+1
   - Tags resulting nodes as polymorphic
3. Attaches variants to parent property
```

**Inheritance Handling:**
```swift
// Example hierarchy:
class Animal { let name: String }
class Dog: Animal { let breed: String }
class Poodle: Dog { let color: String }

// For Poodle:
1. Get chain: [Dog, Animal]
2. Extract properties from Dog: [breed]
3. Extract properties from Animal: [name]
4. Walk chain to find original declarations
5. Build InheritedPropertyInfo for each:
   - name: declaredIn="Animal", originallyDeclaredIn="Animal"
   - breed: declaredIn="Dog", originallyDeclaredIn="Dog"
6. Poodle's ModelNode has:
   - inheritedProperties: [name, breed]
   - properties: [color]
```

#### 4b. CycleDetector - State Management

**Purpose**: Manage visitation state and node caching to prevent infinite recursion.

**State Tracking:**
```swift
class CycleDetector {
    private var visitedUSRs: Set<String> = []       // Current path
    private var nodeCache: [String: ModelNode] = [] // All processed nodes
}
```

**Why Both Visited and Cache?**

**visitedUSRs**: Tracks the *current path* through the graph
- Detects cycles within a single traversal branch
- Cleared between root symbols
- Example: User → Order → User (cycle!)

**nodeCache**: Stores all *completed nodes*
- Reuses processing results for shared types
- Persists across entire graph building
- Example: Multiple types reference Address

**Cycle Detection Logic:**

```
Processing User → Order → Address → User

Step 1: Process User
  visitedUSRs = {User}
  cache = {}
  
Step 2: Process Order (child of User)
  visitedUSRs = {User, Order}
  cache = {}
  
Step 3: Process Address (child of Order)
  visitedUSRs = {User, Order, Address}
  cache = {}
  
Step 4: Try to process User again (child of Address)
  Check: Is User in visitedUSRs? YES!
  Action: Return cyclic placeholder
  Result: Prevents infinite loop
  
Step 5: Complete Address node
  cache[Address] = AddressNode
  
Step 6: Complete Order node
  cache[Order] = OrderNode
  
Step 7: Complete User node
  cache[User] = UserNode


Later: Processing Organization → Address

Step 1: Process Address
  Check: Is Address in visitedUSRs? NO (different root)
  Check: Is Address in cache? YES!
  Action: Return cached node (no re-parsing)
  Benefit: Fast, avoids duplicate work
```

**API Methods:**

```swift
// Check if symbol is in current path (cycle)
func isVisited(_ usr: String) -> Bool

// Get cached node (different path)
func getCachedNode(for usr: String) -> ModelNode?

// Mark symbol as visited in current path
func markVisited(_ usr: String)

// Store completed node
func cacheNode(_ node: ModelNode, for usr: String)

// Reset visited for new root (keep cache)
func resetVisited()

// Clear everything (rarely used)
func clearAll()

// Create placeholder for cyclic reference
func createCyclicNode(for symbol, schemaId, isPolymorphic) -> ModelNode

// Create cyclic node from cached (mark as reference)
func createCyclicNodeFromCache(_ cached) -> ModelNode
```

**Cyclic Node Representation:**
```swift
// When cycle detected:
ModelNode(
    name: "User",
    kind: "struct",
    filePath: "...",
    line: 10,
    properties: [],      // Empty - reference only
    children: [],        // Empty - breaks cycle
    isCyclic: true       // Flag: this is a reference
)
```

---

### 4. GraphBuilder.swift - Relationship Graph Orchestrator

**Purpose**: High-level orchestration of graph building, delegating to specialized processors.

#### New Architecture (Delegation Pattern)

**Current Class Structure:**

```
┌───────────────────────────────────────────────────────────────────┐
│                         GraphBuilder                               │
├───────────────────────────────────────────────────────────────────┤
│ Private Properties:                                                │
│  - indexManager: IndexStoreManager                                 │
│  - sourceRoot: String                                              │
│  - parser: SwiftFileParser                                         │
│  - logger: Logger                                                  │
│  - cycleDetector: CycleDetector        // Separated!               │
│  - symbolProcessor: SymbolProcessor    // Separated!               │
├───────────────────────────────────────────────────────────────────┤
│ Public Methods:                                                    │
│  + init(indexManager, sourceRoot, logger)                          │
│  + buildGraph(from rootSymbolsWithParams) -> ModelGraph            │
│  + buildGraph(from rootSymbols) -> ModelGraph  // Compatibility    │
│  + processSymbol(_ symbol, depth) -> ModelNode?  // Delegated      │
└───────────────────────────────────────────────────────────────────┘
                             │
            ┌────────────────┴────────────────┐
            │                                 │
            ▼                                 ▼
  ┌──────────────────┐           ┌──────────────────────┐
  │ SymbolProcessor  │           │   CycleDetector      │
  │                  │           │                      │
  │• processSymbol() │           │• markVisited()       │
  │• collectProps()  │           │• isVisited()         │
  │• buildNode()     │           │• resetVisited()      │
  └──────────────────┘           │• getCachedNode()     │
                                 │• createCyclicNode()  │
                                 └──────────────────────┘
```

**Key Responsibilities:**

1. **GraphBuilder**:
   - Initialize components (parser, cycleDetector, symbolProcessor)
   - Coordinate the graph building process
   - Handle root symbols with their parameters (schema IDs)
   - Reset cycle detection between roots

2. **SymbolProcessor**:
   - Process individual symbols recursively
   - Extract properties and enum cases
   - Handle inheritance chains
   - Process polymorphic types
   - Build ModelNode structures

3. **CycleDetector**:
   - Track visited symbols by USR
   - Maintain node cache for performance
   - Create cyclic placeholder nodes
   - Reset visited state between root symbols

#### Graph Building Flow

```
┌────────────────────────────────────────────────────────────────┐
│           buildGraph(from: [IndexedSymbol])                     │
└────────────────────────────────────────────────────────────────┘

Input: rootSymbols = [User, Organization]
  │
  ▼
┌─────────────────────────────────┐
│ Initialize rootNodes: []        │
└─────────┬───────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│ For each rootSymbol in rootSymbols:                             │
│  │                                                              │
│  ├─▶ Log: "Processing root symbol: {name}"                     │
│  │                                                              │
│  ├─▶ Clear visitedUSRs set                                     │
│  │   (Each root has independent cycle tracking)                │
│  │                                                              │
│  ├─▶ processSymbol(rootSymbol, depth: 0)                       │
│  │    │                                                         │
│  │    ├─ Returns: ModelNode?                                   │
│  │    │                                                         │
│  │    └─ if node != nil:                                       │
│  │        rootNodes.append(node)                               │
│  │                                                              │
└──┴──────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────┐
│ Create ModelGraph               │
│  - generatedAt: ISO8601 now     │
│  - roots: rootNodes             │
└─────────┬───────────────────────┘
          │
          ▼
    Return ModelGraph
```

#### processSymbol - Recursive Algorithm

```
┌────────────────────────────────────────────────────────────────┐
│         processSymbol(symbol, depth) -> ModelNode?              │
└────────────────────────────────────────────────────────────────┘

Input: symbol = IndexedSymbol("User", usr: "s:User...")
       depth = 0
  │
  ▼
┌─────────────────────────────────────────────────────────────────┐
│ CYCLE CHECK #1: Already visited in current path?               │
│  if visitedUSRs.contains(symbol.usr):                           │
└──────┬──────────────────────────────────────────────────────────┘
       │ Yes (CYCLE DETECTED!)
       ├─▶ Log: "Cycle detected for {name}"
       │   Create cyclic marker node:
       │   ┌──────────────────────────────────────────────────┐
       │   │ ModelNode(                                       │
       │   │   name: symbol.name,                             │
       │   │   kind: symbol.kind,                             │
       │   │   filePath: symbol.filePath,                     │
       │   │   line: symbol.line,                             │
       │   │   properties: [],                                │
       │   │   children: [],                                  │
       │   │   isCyclic: true  ◀─── MARKER                    │
       │   │ )                                                │
       │   └──────────────────────────────────────────────────┘
       │   Return cyclic node
       │
       │ No (First visit)
       ▼
┌─────────────────────────────────────────────────────────────────┐
│ CYCLE CHECK #2: Already in cache?                              │
│  if let cached = nodeCache[symbol.usr]:                         │
└──────┬──────────────────────────────────────────────────────────┘
       │ Yes (Visited in different branch)
       ├─▶ Log: "Cycle detected (from cache)"
       │   var cyclicNode = cached
       │   cyclicNode.isCyclic = true
       │   cyclicNode.children = []  // Don't duplicate
       │   Return cyclic node
       │
       │ No (Not cached)
       ▼
┌─────────────────────────────────────────────────────────────────┐
│ MARK AS VISITED (Before processing children!)                  │
│  visitedUSRs.insert(symbol.usr)                                 │
└─────────┬───────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│ PARSE SOURCE FILE                                               │
│  try parser.extractProperties(                                  │
│    fromFile: symbol.filePath,                                   │
│    typeName: symbol.name                                        │
│  )                                                              │
│  ├─▶ Success: (properties, enumCases)                           │
│  └─▶ Error: Log warning, return nil                             │
└─────────┬───────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│ Initialize collections:                                         │
│  - propertyInfos: [PropertyInfo] = []                           │
│  - children: [ModelNode] = []                                   │
└─────────┬───────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│ FOR EACH property in properties:                                │
│  │                                                              │
│  ├─▶ Create PropertyInfo:                                      │
│  │   PropertyInfo(                                             │
│  │     name: property.name,                                    │
│  │     typeName: property.typeName,                            │
│  │     isOptional: property.isOptional,                        │
│  │     isArray: property.isArray,                              │
│  │     isSet: property.isSet,                                  │
│  │     isDictionary: property.isDictionary                     │
│  │   )                                                         │
│  │   propertyInfos.append(...)                                 │
│  │                                                              │
│  └─▶ Should explore this type?                                 │
│      │                                                          │
│      ├─ shouldExploreType(property.typeName)                   │
│      │   │                                                      │
│      │   ├─ isPrimitive(typeName)? ──▶ No, skip                │
│      │   ├─ isFrameworkType(typeName)? ──▶ No, skip            │
│      │   ├─ isGenericPlaceholder(typeName)? ──▶ No, skip       │
│      │   └─ Yes, explore!                                      │
│      │                                                          │
│      └─ Yes ──▶ Find in index:                                 │
│          │                                                      │
│          ├─▶ indexManager.findSymbolByName(property.typeName)  │
│          │    │                                                 │
│          │    ├─ Found ──▶ childSymbol                          │
│          │    │             │                                   │
│          │    │             ├─ RECURSIVE CALL:                  │
│          │    │             │   processSymbol(                  │
│          │    │             │     childSymbol,                  │
│          │    │             │     depth: depth + 1              │
│          │    │             │   )                               │
│          │    │             │   │                               │
│          │    │             │   └─▶ Returns childNode?          │
│          │    │             │                                   │
│          │    │             └─ if childNode != nil:             │
│          │    │                 var nodeWithProperty = childNode│
│          │    │                 nodeWithProperty.               │
│          │    │                   parentPropertyName =          │
│          │    │                   property.name                 │
│          │    │                 children.append(               │
│          │    │                   nodeWithProperty              │
│          │    │                 )                               │
│          │    │                                                 │
│          │    └─ Not Found ──▶ Log: "Could not find in index"  │
│          │                                                      │
└──────────┴──────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────┐
│ BUILD MODEL NODE                                                │
│  let node = ModelNode(                                          │
│    name: symbol.name,                                           │
│    kind: kindString,  // "struct", "class", or "enum"           │
│    filePath: symbol.filePath,                                   │
│    line: symbol.line,                                           │
│    properties: propertyInfos,                                   │
│    enumCases: enumCases,                                        │
│    children: children,                                          │
│    isCyclic: false                                              │
│  )                                                              │
└─────────┬───────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│ CACHE THE NODE                                                  │
│  nodeCache[symbol.usr] = node                                   │
└─────────┬───────────────────────────────────────────────────────┘
          │
          ▼
    Return node

NOTE: We do NOT remove from visitedUSRs after processing.
This ensures we detect cycles within the same branch.
```

#### Cycle Detection - Visual Example

```
Graph with cycle: User → Order → User

Initial State:
  visitedUSRs = {}
  nodeCache = {}

Step 1: Process User
  ┌─────────────────────────────────────┐
  │ processSymbol(User, depth: 0)       │
  ├─────────────────────────────────────┤
  │ visitedUSRs.contains(User)?  NO     │
  │ visitedUSRs.insert(User) ──▶ {User} │
  │ Parse User.swift                    │
  │ Properties: [id, orders]            │
  │   orders: [Order] ──▶ Explore Order │
  └───────────┬─────────────────────────┘
              │
              ▼ RECURSE
  ┌─────────────────────────────────────┐
  │ processSymbol(Order, depth: 1)      │
  ├─────────────────────────────────────┤
  │ visitedUSRs.contains(Order)?  NO    │
  │ visitedUSRs.insert(Order)           │
  │   ──▶ {User, Order}                 │
  │ Parse Order.swift                   │
  │ Properties: [id, buyer]             │
  │   buyer: User ──▶ Explore User      │
  └───────────┬─────────────────────────┘
              │
              ▼ RECURSE
  ┌─────────────────────────────────────┐
  │ processSymbol(User, depth: 2)       │
  ├─────────────────────────────────────┤
  │ visitedUSRs.contains(User)?  YES ✓  │
  │ ┌───────────────────────────────┐   │
  │ │ CYCLE DETECTED!               │   │
  │ │ Return ModelNode(             │   │
  │ │   name: "User",               │   │
  │ │   isCyclic: true,             │   │
  │ │   children: []                │   │
  │ │ )                             │   │
  │ └───────────────────────────────┘   │
  └───────────┬─────────────────────────┘
              │ Return cyclic marker
              ▼
  ┌─────────────────────────────────────┐
  │ Back in Order processing            │
  │ children = [cyclic User node]       │
  │ Build Order node with cyclic child  │
  │ Cache Order node                    │
  │ Return Order node                   │
  └───────────┬─────────────────────────┘
              │ Return
              ▼
  ┌─────────────────────────────────────┐
  │ Back in User processing             │
  │ children = [Order node]             │
  │ Build User node                     │
  │ Cache User node                     │
  │ Return User node                    │
  └─────────────────────────────────────┘

Final Graph Structure:
  User
   ├─ properties: [id, orders]
   └─ children:
       └─ Order
           ├─ properties: [id, buyer]
           └─ children:
               └─ User (isCyclic: true, children: [])
```

#### shouldExploreType Decision Flow

```
┌────────────────────────────────────────────────────────────────┐
│              shouldExploreType(typeName) -> Bool                │
└────────────────────────────────────────────────────────────────┘

Input: typeName = "User"
  │
  ▼
┌─────────────────────────────────────────────────────────────────┐
│ Check 1: Is it a primitive type?                                │
│  isPrimitiveType(typeName)                                      │
│  ├─ Primitives: Int, String, Bool, Double, Float               │
│  │              Date, Data, URL, UUID, Decimal                  │
│  └─ YES ──▶ return false (don't explore)                        │
└──────┬──────────────────────────────────────────────────────────┘
       │ NO
       ▼
┌─────────────────────────────────────────────────────────────────┐
│ Check 2: Is it a known framework type?                          │
│  frameworkTypes.contains(typeName)                              │
│  ├─ Framework types:                                            │
│  │   • SwiftUI: View, Color, Image, Text, Font                  │
│  │   • Swift: Error, Result, Codable, Hashable                  │
│  │   • Foundation: NSString, NSNumber                           │
│  └─ YES ──▶ return false (don't explore)                        │
└──────┬──────────────────────────────────────────────────────────┘
       │ NO
       ▼
┌─────────────────────────────────────────────────────────────────┐
│ Check 3: Is it a generic placeholder?                           │
│  typeName.count == 1 && typeName.first.isUppercase             │
│  ├─ Placeholders: T, U, V, E, K                                 │
│  └─ YES ──▶ return false (don't explore)                        │
└──────┬──────────────────────────────────────────────────────────┘
       │ NO
       ▼
    return true (explore as custom type)

Examples:
  "User"      ──▶ true  (custom type)
  "String"    ──▶ false (primitive)
  "Int"       ──▶ false (primitive)
  "Date"      ──▶ false (primitive)
  "View"      ──▶ false (framework)
  "T"         ──▶ false (generic placeholder)
  "Address"   ──▶ true  (custom type)
  "OrderItem" ──▶ true  (custom type)
```

#### Complete Example Trace

```
Input: rootSymbols = [User]

User.swift:
  struct User {
    let id: String
    let name: String
    let address: Address
  }

Address.swift:
  struct Address {
    let street: String
    let city: String
  }

Execution Trace:
═══════════════════════════════════════════════════════════════

buildGraph([User])
│
├─ visitedUSRs = {}
├─ nodeCache = {}
│
└─▶ processSymbol(User, depth: 0)
    │
    ├─ visitedUSRs.contains(User)? NO
    ├─ visitedUSRs.insert(User) ──▶ {User}
    │
    ├─ parser.extractProperties("User.swift", "User")
    │   └─▶ properties = [
    │         ExtractedProperty(name: "id", typeName: "String", ...),
    │         ExtractedProperty(name: "name", typeName: "String", ...),
    │         ExtractedProperty(name: "address", typeName: "Address", ...)
    │       ]
    │
    ├─ Process property "id" (String)
    │   ├─ Create PropertyInfo
    │   └─ shouldExploreType("String")? NO (primitive)
    │
    ├─ Process property "name" (String)
    │   ├─ Create PropertyInfo
    │   └─ shouldExploreType("String")? NO (primitive)
    │
    ├─ Process property "address" (Address)
    │   ├─ Create PropertyInfo
    │   ├─ shouldExploreType("Address")? YES
    │   │
    │   ├─ indexManager.findSymbolByName("Address")
    │   │   └─▶ Found: IndexedSymbol("Address", ...)
    │   │
    │   └─▶ processSymbol(Address, depth: 1)
    │       │
    │       ├─ visitedUSRs.contains(Address)? NO
    │       ├─ visitedUSRs.insert(Address) ──▶ {User, Address}
    │       │
    │       ├─ parser.extractProperties("Address.swift", "Address")
    │       │   └─▶ properties = [
    │       │         ExtractedProperty(name: "street", typeName: "String", ...),
    │       │         ExtractedProperty(name: "city", typeName: "String", ...)
    │       │       ]
    │       │
    │       ├─ Process property "street" (String)
    │       │   └─ shouldExploreType("String")? NO
    │       │
    │       ├─ Process property "city" (String)
    │       │   └─ shouldExploreType("String")? NO
    │       │
    │       ├─ Build Address node:
    │       │   ModelNode(
    │       │     name: "Address",
    │       │     properties: [street, city],
    │       │     children: [],
    │       │     isCyclic: false
    │       │   )
    │       │
    │       ├─ nodeCache[Address.usr] = Address node
    │       │
    │       └─ Return Address node
    │
    ├─ children = [Address node]
    │
    ├─ Build User node:
    │   ModelNode(
    │     name: "User",
    │     properties: [id, name, address],
    │     children: [Address],
    │     isCyclic: false
    │   )
    │
    ├─ nodeCache[User.usr] = User node
    │
    └─ Return User node

rootNodes = [User node]

ModelGraph(
  generatedAt: "2025-12-21T10:30:00Z",
  roots: [User node]
)
```

#### The Graph Building Algorithm

**High-Level Flow**:
```
For each root symbol:
    1. Parse properties using SwiftFileParser
    2. For each property:
        a. Check if it's a custom type (not primitive)
        b. Find the type in IndexStoreDB
        c. Recursively process (becomes child node)
    3. Build ModelNode with children
    4. Detect cycles using USR tracking
```

#### Cycle Detection Strategy

**The Problem**: Models can reference each other circularly:
```swift
struct User {
    let orders: [Order]
}

struct Order {
    let user: User  // Cycle!
}
```

Without cycle detection, this would recurse infinitely.

**The Solution**: Track visited USRs

```swift
private var visitedUSRs: Set<String> = []

func processSymbol(_ symbol: IndexedSymbol) -> ModelNode? {
    // Check if already visited in current path
    if visitedUSRs.contains(symbol.usr) {
        // Create cyclic marker node
        return ModelNode(
            name: symbol.name,
            isCyclic: true,
            children: []
        )
    }
    
    // Mark as visited BEFORE processing children (prevents infinite recursion)
    visitedUSRs.insert(symbol.usr)
    
    // Process children...
    
    // Note: We DON'T remove from visitedUSRs after processing
    // This prevents revisiting in the same branch
}
```

**Why Use USR Instead of Name?**
- Names can be reused in different modules
- Generic types have the same name with different specializations
- USR is guaranteed unique across the entire codebase

#### Node Caching

To improve performance and handle shared types:

```swift
private var nodeCache: [String: ModelNode] = [:]

func processSymbol(_ symbol: IndexedSymbol) -> ModelNode? {
    // Check cache first
    if let cached = nodeCache[symbol.usr] {
        var cyclicNode = cached
        cyclicNode.isCyclic = true  // Mark as cyclic reference
        cyclicNode.children = []    // Don't duplicate children
        return cyclicNode
    }
    
    // Process and cache...
    let node = ModelNode(...)
    nodeCache[symbol.usr] = node
    return node
}
```

#### Type Exploration Logic

Not all types should be explored as children:

**Explored Types** (Custom Models):
- User-defined structs
- User-defined classes
- User-defined enums

**Skipped Types**:

**1. Swift Primitives**:
```swift
static func isPrimitiveType(_ typeName: String) -> Bool {
    let primitives = [
        "Int", "String", "Bool", "Double", "Float",
        "Date", "Data", "URL", "UUID", "Decimal"
    ]
    return primitives.contains(typeName)
}
```

**2. Framework Types**:
```swift
let frameworkTypes = [
    "View", "Color", "Image", "Text",  // SwiftUI
    "Error", "Result", "Codable",      // Swift
    "NSString", "NSNumber"             // Foundation
]
```

**3. Generic Placeholders**:
```swift
if typeName.count == 1 && typeName.first?.isUppercase == true {
    return false  // Skip T, U, V, etc.
}
```

#### Recursive Processing Flow

```
processSymbol(User):
    ├─ Parse User.swift
    ├─ Extract properties: [id: String, name: String, orders: [Order]]
    ├─ For property "id" (String):
    │   └─ isPrimitive → Skip
    ├─ For property "name" (String):
    │   └─ isPrimitive → Skip
    ├─ For property "orders" (Order):
    │   ├─ findSymbolByName("Order") → Found
    │   └─ processSymbol(Order):
    │       ├─ Parse Order.swift
    │       ├─ Extract properties: [id: String, user: User]
    │       ├─ For property "id" (String):
    │       │   └─ isPrimitive → Skip
    │       └─ For property "user" (User):
    │           ├─ findSymbolByName("User") → Found
    │           └─ visitedUSRs.contains(User.usr) → TRUE
    │               └─ Return cyclic marker node
    └─ Build ModelNode
```

#### Parent Property Association

Child nodes track which parent property references them:

```swift
for property in properties {
    if shouldExploreType(property.typeName) {
        if let childNode = try processSymbol(childSymbol) {
            var nodeWithProperty = childNode
            nodeWithProperty.parentPropertyName = property.name  // Link property
            children.append(nodeWithProperty)
        }
    }
}
```

This enables output like:
```json
{
    "name": "Order",
    "parentPropertyName": "orders",  // Referenced via User.orders
    ...
}
```

#### Alternative: WorklistGraphBuilder

The file also includes `WorklistGraphBuilder` - an alternative implementation using an iterative worklist algorithm instead of recursion:

**Advantages**:
- No stack overflow for deep hierarchies
- Explicit cycle detection
- Easier to debug

**Trade-off**: More complex code

---

### 5. Output Layer - Format Converters

The Output layer is responsible for converting the internal ModelGraph representation into various output formats.

#### Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                      Output Layer                               │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ModelGraph (internal representation)                          │
│       │                                                         │
│       ├─────────────────┬──────────────────┐                  │
│       │                 │                  │                   │
│       ▼                 ▼                  ▼                   │
│  ┌──────────┐  ┌──────────────┐  ┌─────────────────┐         │
│  │   Raw    │  │ JSON Schema  │  │  Knot Schemas   │         │
│  │   JSON   │  │  Converter   │  │   Converter     │         │
│  └──────────┘  └──────────────┘  └─────────────────┘         │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

#### 5a. JSONSchemaConverter

**Purpose**: Convert ModelGraph to JSON Schema Draft 2020-12 format.

**Output Structure:**
```json
[
  {
    "schemaId": "user",
    "schemaDefinition": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "user",
      "type": "object",
      "title": "User",
      "description": "Generated from struct User at User.swift:10",
      "properties": {
        "id": {"type": "string"},
        "name": {"type": "string"},
        "email": {"type": "string"}
      },
      "required": ["id", "name", "email"]
    },
    "status": "APPROVED",
    "associatedKeys": [],
    "metaData": {
      "description": "Generated from struct User",
      "filePath": "/path/to/User.swift",
      "line": 10
    }
  }
]
```

**Key Features:**

1. **Type Mapping:**
```swift
Swift Type → JSON Schema Type
String     → {"type": "string"}
Int        → {"type": "integer"}
Double     → {"type": "number"}
Bool       → {"type": "boolean"}
[Type]     → {"type": "array", "items": {...}}
[K: V]     → {"type": "object", "additionalProperties": {...}}
Custom     → {"$ref": "#/definitions/CustomType"}
```

2. **Inheritance Support (allOf):**
```swift
// Swift:
class Dog: Animal { let breed: String }

// JSON Schema:
{
  "allOf": [
    {"$ref": "#/definitions/Animal"},
    {
      "properties": {
        "breed": {"type": "string"}
      }
    }
  ]
}
```

3. **Polymorphic Support (oneOf):**
```swift
// Swift with @PolymorphicMapping:
@PolymorphicMapping(discriminator: "type", variants: ["dog": Dog.self])
let pet: Pet

// JSON Schema:
{
  "oneOf": [
    {"$ref": "#/definitions/Dog"},
    {"$ref": "#/definitions/Cat"}
  ],
  "discriminator": {
    "propertyName": "type",
    "mapping": {
      "dog": "#/definitions/Dog",
      "cat": "#/definitions/Cat"
    }
  }
}
```

4. **CodingKeys Integration:**
```swift
// Swift:
struct User {
    let firstName: String
    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
    }
}

// JSON Schema uses "first_name":
{
  "properties": {
    "first_name": {"type": "string"}  // Uses CodingKey!
  }
}
```

5. **Definitions (Shared Types):**
```swift
// Multiple references to Address:
{
  "definitions": {
    "Address": {
      "type": "object",
      "properties": {...}
    }
  },
  "properties": {
    "homeAddress": {"$ref": "#/definitions/Address"},
    "workAddress": {"$ref": "#/definitions/Address"}
  }
}
```

**Conversion Process:**
```
convertNode(node, definitions)
  │
  ├─▶ Build base schema
  ├─▶ if inheritsFrom:
  │     └─ Use allOf with parent reference
  ├─▶ if isPolymorphic:
  │     └─ Use oneOf with variants
  ├─▶ For each property:
  │     ├─ Use codingKey if available
  │     ├─ Convert type to JSON Schema type
  │     ├─ if custom type:
  │     │   ├─ Add to definitions
  │     │   └─ Use $ref
  │     └─ Add to properties
  ├─▶ For each child:
  │     └─ Add to definitions recursively
  └─▶ Return schema object
```

#### 5b. KnotSchemaConverter

**Purpose**: Convert knot schemas to specialized format for sub-schema relationships.

**Input:** KnotSchemaInfo from discovery
```swift
struct KnotSchemaInfo {
    let symbol: IndexedSymbol
    let knotInfo: KnotInfo
    let modelNode: ModelNode?
}

struct KnotInfo {
    let knotType: KnotType           // .multiKnot or .mapKnot
    let schemaId: String
    let subSchemas: [String]         // Type names
}
```

**Output Structure:**
```json
[
  {
    "schemaId": "payment_methods_knot",
    "schemaDefinition": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "title": "PaymentMethodsKnot",
      "properties": {...},
      "x-knot-metadata": {
        "knotType": "multiKnot",
        "subSchemas": ["CreditCard", "DebitCard", "UPI"]
      }
    },
    "status": "APPROVED",
    "associatedKeys": [],
    "metaData": {
      "knotType": "multiKnot",
      "subSchemaIds": ["credit_card", "debit_card", "upi"]
    }
  }
]
```

**Key Features:**

1. **Knot Metadata:**
   - Includes knot type (multi or map)
   - Lists sub-schema references
   - Maps sub-schema class names to schema IDs

2. **Schema ID Resolution:**
```swift
// Uses className → schemaId mapping from root schemas
classNameToSchemaId = [
    "CreditCard": "credit_card",
    "DebitCard": "debit_card"
]

// Converts class names to schema IDs in metadata
```

3. **Dual Output:**
   - Main graph file: `output.json`
   - Knot schemas file: `output-knots.json`
   - Keeps knot schemas separate for specialized handling

**Conversion Process:**
```
convert(knotSchemas, classNameToSchemaId)
  │
  └─▶ For each knotSchema:
      ├─ Get schemaId from knotInfo
      ├─ Convert ModelNode if available
      ├─ Add knot metadata to schema
      ├─ Map subSchema class names to IDs
      ├─ Build schema object with:
      │   ├─ schemaId
      │   ├─ schemaDefinition (with x-knot-metadata)
      │   ├─ status: "APPROVED"
      │   ├─ associatedKeys: []
      │   └─ metaData with knotType and subSchemaIds
      └─ Add to output array
```

---

### 6. Models.swift - Data Structures

**Purpose**: Define the output data structures and utilities.

#### Data Model Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        ModelGraph                                │
│                        : Codable                                 │
├─────────────────────────────────────────────────────────────────┤
│ Properties:                                                      │
│  + generatedAt: String          // ISO 8601 timestamp            │
│  + roots: [ModelNode]           // Root model nodes              │
├─────────────────────────────────────────────────────────────────┤
│ Extensions:                                                      │
│  • prettyPrint() -> String                                       │
│  • statistics -> GraphStatistics                                 │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ contains
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                        ModelNode                                 │
│                        : Codable                                 │
├─────────────────────────────────────────────────────────────────┤
│ Properties:                                                      │
│  + name: String                 // "User", "Address"             │
│  + kind: String                 // "struct", "class", "enum"     │
│  + filePath: String             // "/path/to/User.swift"         │
│  + line: Int                    // Line number                   │
│  + properties: [PropertyInfo]   // All properties                │
│  + enumCases: [EnumCaseInfo]    // Enum cases (if enum)          │
│  + children: [ModelNode]        // Recursive!                    │
│  + isCyclic: Bool               // Cycle marker                  │
│  + parentPropertyName: String?  // "address", "orders"           │
├─────────────────────────────────────────────────────────────────┤
│ Extensions:                                                      │
│  • prettyPrint(indent: Int) -> String                            │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ contains
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      PropertyInfo                                │
│                      : Codable                                   │
├─────────────────────────────────────────────────────────────────┤
│ Properties:                                                      │
│  + name: String                 // "email", "orders"             │
│  + typeName: String             // "String", "Order"             │
│  + isOptional: Bool             // true for Type?                │
│  + isArray: Bool                // true for [Type]               │
│  + isSet: Bool                  // true for Set<Type>            │
│  + isDictionary: Bool           // true for [Key: Value]         │
├─────────────────────────────────────────────────────────────────┤
│ Computed:                                                        │
│  • typeDescription: String      // "[Order]?", "String"          │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      EnumCaseInfo                                │
│                      : Codable                                   │
├─────────────────────────────────────────────────────────────────┤
│ Properties:                                                      │
│  + name: String                 // "active", "pending"           │
│  + associatedValues: [String]   // ["String", "Int"]             │
│  + rawValue: String?            // "active" for raw value enums  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    GraphStatistics                               │
│                    : Codable                                     │
├─────────────────────────────────────────────────────────────────┤
│ Properties:                                                      │
│  + rootCount: Int               // Number of root models         │
│  + totalNodes: Int              // Total nodes in graph          │
│  + totalProperties: Int         // Total properties              │
│  + cyclicReferences: Int        // Number of cycles              │
│  + maxDepth: Int                // Maximum tree depth            │
│  + typeOccurrences: [String: Int]  // Type frequency map         │
└─────────────────────────────────────────────────────────────────┘
```

#### JSON Serialization Flow

```
┌────────────────────────────────────────────────────────────────┐
│                 JSON Encoding Process                           │
└────────────────────────────────────────────────────────────────┘

ModelGraph object in memory
  │
  ▼
┌─────────────────────────────────┐
│ Create JSONEncoder              │
│  encoder = JSONEncoder()        │
└─────────┬───────────────────────┘
          │
          ▼
┌─────────────────────────────────┐
│ Configure formatting            │
│  encoder.outputFormatting = [   │
│    .prettyPrinted,              │
│    .sortedKeys                  │
│  ]                              │
└─────────┬───────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│ Encode ModelGraph                                               │
│  let jsonData = try encoder.encode(graph)                       │
│  │                                                              │
│  └─▶ Calls Codable implementation:                             │
│      ┌──────────────────────────────────────────────────────┐  │
│      │ encode(to encoder: Encoder)                          │  │
│      │  ├─ Encode generatedAt as String                     │  │
│      │  └─ Encode roots as Array                            │  │
│      │      └─ For each ModelNode:                          │  │
│      │          ├─ Encode name, kind, filePath, line        │  │
│      │          ├─ Encode properties array                  │  │
│      │          │   └─ For each PropertyInfo:               │  │
│      │          │       ├─ Encode name                      │  │
│      │          │       ├─ Encode typeName                  │  │
│      │          │       ├─ Encode isOptional               │  │
│      │          │       ├─ Encode isArray                   │  │
│      │          │       ├─ Encode isSet                     │  │
│      │          │       └─ Encode isDictionary              │  │
│      │          ├─ Encode enumCases array                   │  │
│      │          ├─ Encode children array (RECURSIVE!)       │  │
│      │          ├─ Encode isCyclic                          │  │
│      │          └─ Encode parentPropertyName (if present)   │  │
│      └──────────────────────────────────────────────────────┘  │
└─────────┬───────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────┐
│ Convert Data to String          │
│  String(data: jsonData,         │
│         encoding: .utf8)        │
└─────────┬───────────────────────┘
          │
          ▼
    JSON String output
```

#### Statistics Computation Flow

```
┌────────────────────────────────────────────────────────────────┐
│              ModelGraph.statistics Computation                  │
└────────────────────────────────────────────────────────────────┘

START
  │
  ▼
┌─────────────────────────────────┐
│ Initialize counters:            │
│  - totalNodes = 0               │
│  - totalProperties = 0          │
│  - cyclicReferences = 0         │
│  - maxDepth = 0                 │
│  - typeOccurrences: [String:Int]│
└─────────┬───────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│ Define recursive traverse function:                             │
│                                                                  │
│  func traverse(node: ModelNode, depth: Int) {                   │
│    totalNodes += 1                                              │
│    totalProperties += node.properties.count                     │
│    maxDepth = max(maxDepth, depth)                              │
│    typeOccurrences[node.name, default: 0] += 1                  │
│    │                                                             │
│    ├─ if node.isCyclic:                                         │
│    │   cyclicReferences += 1                                    │
│    │   return  // Don't traverse children                       │
│    │                                                             │
│    └─ else:                                                      │
│        for child in node.children:                              │
│          traverse(node: child, depth: depth + 1)  // RECURSE    │
│  }                                                               │
└─────────┬───────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────┐
│ For each root in roots:         │
│   traverse(node: root, depth: 0)│
└─────────┬───────────────────────┘
          │
          ▼
┌─────────────────────────────────┐
│ Create GraphStatistics          │
│  GraphStatistics(               │
│    rootCount: roots.count,      │
│    totalNodes: totalNodes,      │
│    totalProperties: ...,        │
│    cyclicReferences: ...,       │
│    maxDepth: maxDepth,          │
│    typeOccurrences: ...         │
│  )                              │
└─────────┬───────────────────────┘
          │
          ▼
    Return GraphStatistics

Example with cycle:
  User (depth 0)
   ├─ properties: [id, name, orders]
   └─ Order (depth 1)
       ├─ properties: [id, buyer]
       └─ User (cyclic, depth 2)

Result:
  totalNodes = 3          // User, Order, User(cyclic)
  totalProperties = 5     // 3 from User + 2 from Order
  cyclicReferences = 1    // User(cyclic)
  maxDepth = 2
  typeOccurrences = {
    "User": 2,            // Original + cyclic reference
    "Order": 1
  }
```

#### Pretty Print Algorithm

```
┌────────────────────────────────────────────────────────────────┐
│              ModelNode.prettyPrint(indent: Int)                 │
└────────────────────────────────────────────────────────────────┘

Input: node = User, indent = 0
  │
  ▼
┌─────────────────────────────────────────────────────────────────┐
│ Create prefix string                                            │
│  let prefix = String(repeating: "  ", count: indent)            │
│  Example: indent=0 → "", indent=1 → "  ", indent=2 → "    "     │
└─────────┬───────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│ Build node header                                               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ cyclicMarker = isCyclic ? " ⚠️ [CYCLIC]" : ""            │   │
│  │ propertyRef = parentPropertyName?                        │   │
│  │               " (via: \(name))" : ""                     │   │
│  │                                                          │   │
│  │ output = "\(prefix)📦 \(name) (\(kind))                  │   │
│  │           \(propertyRef)\(cyclicMarker)\n"              │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Example: "📦 User (struct)\n"                                   │
│  Example: "  📦 Address (struct) (via: address)\n"               │
│  Example: "    📦 User (struct) (via: buyer) ⚠️ [CYCLIC]\n"     │
└─────────┬───────────────────────────────────────────────────────┘
          │
          ▼
     isCyclic?
          │
          ├── Yes ──▶ Return output (don't show properties/children)
          │
          │ No
          ▼
┌─────────────────────────────────────────────────────────────────┐
│ Add properties section                                          │
│  if !properties.isEmpty:                                        │
│    output += "\(prefix)  Properties:\n"                         │
│    │                                                             │
│    └─ For each prop in properties:                              │
│       ├─ Determine marker:                                      │
│       │   isPrimitive(prop.typeName)?                           │
│       │     → marker = "📝"   // Primitive                       │
│       │     → marker = "🔗"   // Reference                       │
│       │                                                          │
│       └─ output += "\(prefix)    \(marker) \(prop.name):        │
│                     \(prop.typeDescription)\n"                  │
│                                                                  │
│  Example:                                                        │
│    Properties:                                                   │
│      📝 id: String                                               │
│      📝 name: String?                                            │
│      🔗 address: Address                                         │
│      🔗 orders: [Order]                                          │
└─────────┬───────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│ Add children section                                            │
│  if !children.isEmpty:                                          │
│    output += "\(prefix)  Children:\n"                           │
│    │                                                             │
│    └─ For each child in children:                               │
│       output += child.prettyPrint(indent: indent + 2) // RECURSE│
└─────────┬───────────────────────────────────────────────────────┘
          │
          ▼
    Return output

Complete Example Output:
═══════════════════════════════════════════════════════════════
📦 User (struct)
  Properties:
    📝 id: String
    📝 name: String
    🔗 address: Address
    🔗 orders: [Order]
  Children:
    📦 Address (struct) (via: address)
      Properties:
        📝 street: String
        📝 city: String
    📦 Order (struct) (via: orders)
      Properties:
        📝 id: String
        🔗 buyer: User
      Children:
        📦 User (struct) (via: buyer) ⚠️ [CYCLIC]
```

#### Property Type Description Computation

```
┌────────────────────────────────────────────────────────────────┐
│         PropertyInfo.typeDescription (computed)                 │
└────────────────────────────────────────────────────────────────┘

Input: PropertyInfo(
  name: "orders",
  typeName: "Order",
  isOptional: true,
  isArray: true,
  isSet: false,
  isDictionary: false
)
  │
  ▼
┌─────────────────────────────────┐
│ Start with base type name       │
│  var desc = typeName            │
│  desc = "Order"                 │
└─────────┬───────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│ Apply collection wrapper                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ if isArray:                                              │   │
│  │   desc = "[\(desc)]"      // Order → [Order]             │   │
│  │                                                          │   │
│  │ else if isSet:                                           │   │
│  │   desc = "Set<\(desc)>"   // Order → Set<Order>          │   │
│  │                                                          │   │
│  │ else if isDictionary:                                    │   │
│  │   desc = "[Key: \(desc)]" // Order → [Key: Order]        │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  desc = "[Order]"                                                │
└─────────┬───────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────┐
│ Apply optional marker           │
│  if isOptional:                 │
│    desc += "?"                  │
│                                 │
│  desc = "[Order]?"              │
└─────────┬───────────────────────┘
          │
          ▼
    Return desc

Examples:
  (typeName: "String", none) ──────────────────────▶ "String"
  (typeName: "String", isOptional) ────────────────▶ "String?"
  (typeName: "Order", isArray) ────────────────────▶ "[Order]"
  (typeName: "Order", isArray, isOptional) ────────▶ "[Order]?"
  (typeName: "User", isSet) ───────────────────────▶ "Set<User>"
  (typeName: "User", isSet, isOptional) ───────────▶ "Set<User>?"
  (typeName: "Value", isDictionary) ───────────────▶ "[Key: Value]"
  (typeName: "Int", isDictionary, isOptional) ─────▶ "[Key: Int]?"
```

#### Core Models

**1. ModelGraph** - Root Container
```swift
struct ModelGraph: Codable {
    let generatedAt: String     // ISO 8601 timestamp
    let roots: [ModelNode]      // Array of root model nodes
}
```

**2. ModelGraph** - Complete Output Structure
```swift
struct ModelGraph: Codable {
    let generatedAt: String        // ISO 8601 timestamp
    let roots: [ModelNode]         // Root models (@ChimeraSchema or command line specified)
}

extension ModelGraph {
    func prettyPrint() -> String   // Human-readable tree format
    var statistics: GraphStatistics // Node counts, depth, type frequency
}
```

**3. ModelNode** - Represents a Type
```swift
struct ModelNode: Codable {
    // Basic identifiers
    let name: String               // Type name: "User", "OrderStatus"
    let kind: String               // "struct", "class", or "enum"
    let filePath: String           // Absolute path to source file
    let line: Int                  // Line number of definition
    
    // Schema metadata
    var schemaId: String?          // From @ChimeraSchema(key: "...")
    
    // Inheritance support
    var inheritsFrom: String?      // Parent class name
    var inheritedProperties: [InheritedPropertyInfo] // Properties from ancestors
    
    // Properties and structure
    let properties: [PropertyInfo] // Declared properties (includes codingKey mappings)
    let enumCases: [EnumCaseInfo]  // Enum cases (only for enums)
    
    // Graph relationships
    var children: [ModelNode]      // Child custom type nodes
    var isCyclic: Bool             // Cycle detection flag
    var parentPropertyName: String? // Parent's property name referencing this node
    
    // Polymorphic support
    var isPolymorphic: Bool        // Is this a polymorphic variant
    var polymorphism: PolymorphicInfo? // Discriminator + variants (if polymorphic property)
}
```

**4. PropertyInfo** - Property Metadata
```swift
struct PropertyInfo: Codable {
    // Basic type information
    let name: String               // "email", "userId"
    let typeName: String           // "String" (base type, unwrapped)
    let isOptional: Bool           // true for String?
    let isArray: Bool              // true for [String]
    let isSet: Bool                // true for Set<String>
    let isDictionary: Bool         // true for [Key: Value]
    
    // JSON serialization support
    var codingKey: String?         // JSON key from CodingKeys enum (null if 1:1 mapping)
    
    // Polymorphic support
    var isPolymorphic: Bool        // Can hold multiple types
    var polymorphism: PolymorphicInfo? // Discriminator + type variants
    
    var typeDescription: String    // Computed: "String?", "[Int]", "Set<User>"
}
```

**5. InheritedPropertyInfo** - Inherited Property Details
```swift
struct InheritedPropertyInfo: Codable {
    // Property metadata (same as PropertyInfo)
    let name: String
    let typeName: String
    let isOptional: Bool
    let isArray: Bool
    let isSet: Bool
    let isDictionary: Bool
    var codingKey: String?
    
    // Inheritance tracking
    let declaredIn: String         // Immediate parent declaring this property
    let originallyDeclaredIn: String // Original ancestor with this property
    let filePath: String           // Source file of original declaration
    let line: Int                  // Line number in source file
}
```

**6. PolymorphicInfo** - Polymorphic Type Mapping
```swift
struct PolymorphicInfo: Codable {
    let discriminatorKey: String   // "type", "kind", "action"
    let variants: [PolymorphicVariant] // All possible type variants
    let isProtocol: Bool           // true if from protocol, false if from @PolymorphicMapping
}

struct PolymorphicVariant: Codable {
    let discriminatorValue: String // "OPEN_ERROR_SCREEN", "success"
    let typeName: String           // "ErrorModels", "SuccessResult"
    let schema: ModelNode          // Complete schema for this variant
}
```

**7. EnumCaseInfo** - Enum Case Details
```swift
struct EnumCaseInfo: Codable {
    let name: String               // "pending", "completed"
    let associatedValues: [String] // ["String", "Int"] for case pending(String, Int)
    let rawValue: String?          // "pending" for enum OrderStatus: String
}
```

#### Pretty Printing

Human-readable tree representation:

```swift
extension ModelNode {
    func prettyPrint(indent: Int) -> String {
        // 📦 User (struct)
        //   Properties:
        //     📝 id: String
        //     📝 name: String
        //     🔗 orders: [Order]
        //   Children:
        //     📦 Order (struct) (via: orders) ⚠️ [CYCLIC]
    }
}
```

Symbols:
- 📦 Type declaration
- 📝 Primitive property
- 🔗 Reference to custom type
- ⚠️ Cycle detected

#### Graph Statistics

Analyze the generated graph:

```swift
extension ModelGraph {
    var statistics: GraphStatistics {
        // Traverses entire graph and computes:
        // - Total nodes
        // - Total properties
        // - Cyclic references count
        // - Maximum depth
        // - Type occurrence frequency
    }
}
```

---

## How It Works: Step-by-Step

Let's trace through a complete example:

### Example Setup

**Models.swift**:
```swift
protocol RootModel {}

struct User: RootModel {
    let id: String
    let name: String
    let address: Address
    let orders: [Order]
}

struct Address {
    let street: String
    let city: String
}

struct Order {
    let id: String
    let items: [Item]
    let buyer: User  // Circular reference!
}

struct Item {
    let name: String
    let price: Double
}
```

### Execution Trace

#### Phase 1: Initialization

**Command**:
```bash
./ModelGraphGenerator \
    --source-path /path/to/project/Sources \
    --marker-name RootModel \
    --verbose
```

**Step 1.1**: Parse arguments
```
✓ sourcePath: /path/to/project/Sources
✓ markerName: RootModel
✓ useMacro: false
✓ verbose: true
```

**Step 1.2**: Find IndexStore
```
🔍 Searching ~/Library/Developer/Xcode/DerivedData/
✓ Found: MyApp-abc123/Index.noindex/DataStore
✓ Last modified: 2025-12-21 10:30:45
```

**Step 1.3**: Initialize IndexStoreDB
```
🔍 IndexStore library: /Applications/Xcode.app/.../libIndexStore.dylib
✓ IndexStoreDB initialized successfully
```

#### Phase 2: Symbol Discovery

**Step 2.1**: Find protocol USR
```
🔍 Searching for protocol: RootModel
✓ Found protocol USR: s:6Models9RootModelP
```

**Step 2.2**: Find conforming types
```
🔍 Searching for types conforming to RootModel
✓ Found conformance at Models.swift:3
  → Conforming type: User
✓ Total symbols found: 1
```

**Result**:
```swift
[
    IndexedSymbol(
        name: "User",
        usr: "s:6Models4UserV",
        kind: .struct,
        filePath: "/path/to/Models.swift",
        line: 3
    )
]
```

#### Phase 3: Graph Building

**Step 3.1**: Process root symbol "User"

```
ℹ️ Processing root symbol: User
🔍   Processing: User (USR: s:6Models4UserV...)
```

**Step 3.2**: Extract properties from User
```
🔍 Parsing /path/to/Models.swift
🔍 Looking for type: User
✓ Found struct User
✓ Extracted 4 properties
```

**Properties**:
```
1. id: String (primitive)
2. name: String (primitive)
3. address: Address (custom type)
4. orders: [Order] (custom type, array)
```

**Step 3.3**: Process property "address"
```
🔍   Property address: Address - exploring...
🔍 Finding symbol: Address
✓ Found in index: Address at Models.swift:9
🔍     Processing: Address (USR: s:6Models7AddressV...)
```

**Step 3.3.1**: Extract Address properties
```
✓ Found struct Address
✓ Extracted 2 properties
```

**Properties**:
```
1. street: String (primitive - skip)
2. city: String (primitive - skip)
```

**Step 3.3.2**: Build Address node
```
✓ Address node created (0 children)
```

**Step 3.4**: Process property "orders"
```
🔍   Property orders: Order - exploring...
🔍 Type is array: [Order] → base type: Order
🔍 Finding symbol: Order
✓ Found in index: Order at Models.swift:14
🔍     Processing: Order (USR: s:6Models5OrderV...)
```

**Step 3.4.1**: Extract Order properties
```
✓ Found struct Order
✓ Extracted 3 properties
```

**Properties**:
```
1. id: String (primitive - skip)
2. items: [Item] (custom type, array)
3. buyer: User (custom type)
```

**Step 3.4.2**: Process Order's property "items"
```
🔍     Property items: Item - exploring...
🔍 Finding symbol: Item
✓ Found in index: Item at Models.swift:20
🔍       Processing: Item (USR: s:6Models4ItemV...)
✓ Extracted 2 properties (both primitive)
✓ Item node created (0 children)
```

**Step 3.4.3**: Process Order's property "buyer" (CYCLE!)
```
🔍     Property buyer: User - exploring...
🔍 Finding symbol: User
✓ Found in index: User at Models.swift:3
🔍       Processing: User (USR: s:6Models4UserV...)
⚠️ Cycle detected for User - skipping
✓ Created cyclic marker node
```

**Step 3.4.4**: Build Order node
```
✓ Order node created (2 children: Item, User[cyclic])
```

**Step 3.5**: Build User node
```
✓ User node created (2 children: Address, Order)
```

#### Phase 4: JSON Generation

**Step 4.1**: Encode to JSON
```
✓ Graph serialization complete
```

**Step 4.2**: Write output
```
✓ Graph written to: /path/to/Sources/model-graph-2025-12-21.json
```

### Final Output Structure

```json
{
  "generatedAt": "2025-12-21T10:35:22Z",
  "roots": [
    {
      "name": "User",
      "kind": "struct",
      "filePath": "/path/to/Models.swift",
      "line": 3,
      "properties": [
        {
          "name": "id",
          "typeName": "String",
          "isOptional": false,
          "isArray": false,
          "isSet": false,
          "isDictionary": false
        },
        {
          "name": "name",
          "typeName": "String",
          "isOptional": false,
          "isArray": false,
          "isSet": false,
          "isDictionary": false
        },
        {
          "name": "address",
          "typeName": "Address",
          "isOptional": false,
          "isArray": false,
          "isSet": false,
          "isDictionary": false
        },
        {
          "name": "orders",
          "typeName": "Order",
          "isOptional": false,
          "isArray": true,
          "isSet": false,
          "isDictionary": false
        }
      ],
      "children": [
        {
          "name": "Address",
          "kind": "struct",
          "filePath": "/path/to/Models.swift",
          "line": 9,
          "parentPropertyName": "address",
          "properties": [
            {
              "name": "street",
              "typeName": "String",
              "isOptional": false,
              "isArray": false,
              "isSet": false,
              "isDictionary": false
            },
            {
              "name": "city",
              "typeName": "String",
              "isOptional": false,
              "isArray": false,
              "isSet": false,
              "isDictionary": false
            }
          ],
          "children": [],
          "isCyclic": false
        },
        {
          "name": "Order",
          "kind": "struct",
          "filePath": "/path/to/Models.swift",
          "line": 14,
          "parentPropertyName": "orders",
          "properties": [
            {
              "name": "id",
              "typeName": "String",
              "isOptional": false,
              "isArray": false,
              "isSet": false,
              "isDictionary": false
            },
            {
              "name": "items",
              "typeName": "Item",
              "isOptional": false,
              "isArray": true,
              "isSet": false,
              "isDictionary": false
            },
            {
              "name": "buyer",
              "typeName": "User",
              "isOptional": false,
              "isArray": false,
              "isSet": false,
              "isDictionary": false
            }
          ],
          "children": [
            {
              "name": "Item",
              "kind": "struct",
              "filePath": "/path/to/Models.swift",
              "line": 20,
              "parentPropertyName": "items",
              "properties": [
                {
                  "name": "name",
                  "typeName": "String",
                  "isOptional": false,
                  "isArray": false,
                  "isSet": false,
                  "isDictionary": false
                },
                {
                  "name": "price",
                  "typeName": "Double",
                  "isOptional": false,
                  "isArray": false,
                  "isSet": false,
                  "isDictionary": false
                }
              ],
              "children": [],
              "isCyclic": false
            },
            {
              "name": "User",
              "kind": "struct",
              "filePath": "/path/to/Models.swift",
              "line": 3,
              "parentPropertyName": "buyer",
              "properties": [],
              "children": [],
              "isCyclic": true
            }
          ],
          "isCyclic": false
        }
      ],
      "isCyclic": false
    }
  ]
}
```

---

## Complete System Data Flow

### End-to-End Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         INPUT SOURCES                                    │
└─────────────────────────────────────────────────────────────────────────┘
         │                                │                    │
         │                                │                    │
    CLI Arguments                  Source Files          Xcode Index
  ┌─────────────┐             ┌──────────────────┐   ┌──────────────┐
  │ --source-path│            │  User.swift      │   │ IndexStoreDB │
  │ --marker-name│            │  Address.swift   │   │ Index.noindex│
  │ --use-macro  │            │  Order.swift     │   │ /DataStore   │
  │ --verbose    │            │  ...             │   │              │
  └──────┬──────┘             └────────┬─────────┘   └──────┬───────┘
         │                              │                    │
         └──────────────────────────────┴────────────────────┘
                                        │
                                        ▼
         ┌──────────────────────────────────────────────────────┐
         │              PHASE 1: INITIALIZATION                  │
         │                  (Main.swift)                         │
         ├──────────────────────────────────────────────────────┤
         │  • Parse CLI arguments                               │
         │  • Resolve index store path                          │
         │  • Load libIndexStore.dylib                          │
         │  • Initialize IndexStoreDB connection                │
         └────────┬─────────────────────────────────────────────┘
                  │
                  ▼
         ┌──────────────────────────────────────────────────────┐
         │       PHASE 2: SYMBOL DISCOVERY                      │
         │         (IndexStoreManager)                          │
         ├──────────────────────────────────────────────────────┤
         │  Input: markerName = "RootModel"                     │
         │  Process:                                            │
         │   ├─ Query IndexStoreDB for protocol/macro          │
         │   ├─ Find conforming/annotated types                │
         │   └─ Fallback to file system scan                   │
         │  Output: [IndexedSymbol]                             │
         │    - name, USR, kind, filePath, line                 │
         └────────┬─────────────────────────────────────────────┘
                  │
                  │ rootSymbols = [User, Organization]
                  │
                  ▼
         ┌──────────────────────────────────────────────────────┐
         │      PHASE 3a: PROPERTY EXTRACTION                   │
         │         (PropertyExtractor)                          │
         ├──────────────────────────────────────────────────────┤
         │  For each symbol:                                    │
         │   Input: filePath, typeName                          │
         │   Process:                                           │
         │    ├─ Read source file                              │
         │    ├─ Parse to AST (SwiftSyntax)                    │
         │    ├─ Walk AST tree                                 │
         │    ├─ Extract property declarations                 │
         │    ├─ Analyze type annotations                      │
         │    └─ Handle Optional/Array/Set/Dictionary          │
         │   Output: [ExtractedProperty], [EnumCaseInfo]       │
         │    - name, typeName, isOptional, isArray, ...       │
         └────────┬─────────────────────────────────────────────┘
                  │
                  │ properties per symbol
                  │
                  ▼
         ┌──────────────────────────────────────────────────────┐
         │      PHASE 3b: GRAPH BUILDING                        │
         │         (GraphBuilder)                               │
         ├──────────────────────────────────────────────────────┤
         │  Input: rootSymbols, properties                      │
         │  Process:                                            │
         │   For each root:                                     │
         │    ├─ processSymbol(root) ────────┐                 │
         │    │   ├─ Check if visited         │                 │
         │    │   ├─ Extract properties       │                 │
         │    │   ├─ For each property:       │                 │
         │    │   │   ├─ Is custom type? ─────┼─Yes─▶ Find in  │
         │    │   │   │                       │       index     │
         │    │   │   │                       │         │       │
         │    │   │   │                       │         ▼       │
         │    │   │   │                       │   processSymbol │
         │    │   │   │                       │   (RECURSIVE)   │
         │    │   │   │                       │         │       │
         │    │   │   │                       │  ◀──────┘       │
         │    │   │   │                       │                 │
         │    │   │   └─ Is primitive? ───────┼─Yes─▶ Skip     │
         │    │   │                           │                 │
         │    │   └─ Build ModelNode          │                 │
         │    │       with children           │                 │
         │    └───────────────────────────────┘                 │
         │                                                       │
         │  Cycle Detection:                                    │
         │   ├─ Track visited USRs                              │
         │   └─ Mark cyclic references                          │
         │                                                       │
         │  Output: ModelGraph                                  │
         │    - generatedAt                                     │
         │    - roots: [ModelNode (recursive tree)]             │
         └────────┬─────────────────────────────────────────────┘
                  │
                  │ Complete graph structure
                  │
                  ▼
         ┌──────────────────────────────────────────────────────┐
         │         PHASE 4: SERIALIZATION                       │
         │            (Main.swift)                              │
         ├──────────────────────────────────────────────────────┤
         │  Input: ModelGraph object                            │
         │  Process:                                            │
         │   ├─ JSONEncoder with pretty printing               │
         │   ├─ Encode recursively (Codable)                   │
         │   └─ Convert to String                              │
         │  Output: JSON string                                 │
         └────────┬─────────────────────────────────────────────┘
                  │
                  │ JSON representation
                  │
                  ▼
         ┌──────────────────────────────────────────────────────┐
         │            PHASE 5: OUTPUT                           │
         │            (Main.swift)                              │
         ├──────────────────────────────────────────────────────┤
         │  ├─ Determine output path                           │
         │  ├─ Write to file                                   │
         │  └─ Log success message                             │
         └────────┬─────────────────────────────────────────────┘
                  │
                  ▼
         ┌──────────────────────────────────────────────────────┐
         │                   OUTPUT FILE                         │
         │              model-graph.json                         │
         └──────────────────────────────────────────────────────┘

Data at each phase:
═══════════════════════════════════════════════════════════════════

Phase 1 → IndexStoreDB handle + Configuration
Phase 2 → [IndexedSymbol(name: "User", usr: "...", ...)]
Phase 3a → [ExtractedProperty(name: "id", typeName: "String", ...)]
Phase 3b → ModelGraph(roots: [ModelNode(...)])
Phase 4 → "{\"generatedAt\":\"...\",\"roots\":[...]}"
Phase 5 → File written to disk
```

### Cross-Component Interaction Diagram

```
┌──────────┐     ┌──────────────────┐     ┌──────────────┐     ┌────────────┐
│   Main   │     │ IndexStoreManager│     │PropertyExtr. │     │GraphBuilder│
└────┬─────┘     └────────┬─────────┘     └──────┬───────┘     └─────┬──────┘
     │                    │                       │                   │
     │ init(indexPath)    │                       │                   │
     ├───────────────────▶│                       │                   │
     │                    │ Load libIndexStore    │                   │
     │                    │ Open IndexStoreDB     │                   │
     │                    │◀─────────             │                   │
     │                    │                       │                   │
     │ findSymbolsConforming│                     │                   │
     │    ToProtocol()    │                       │                   │
     ├───────────────────▶│                       │                   │
     │                    │ Query index           │                   │
     │                    │ Search files          │                   │
     │                    │◀─────────             │                   │
     │◀───[IndexedSymbol] │                       │                   │
     │                    │                       │                   │
     │             init(indexManager, sourceRoot) │                   │
     ├───────────────────────────────────────────────────────────────▶│
     │                    │                       │                   │
     │ buildGraph([symbols])                      │                   │
     ├───────────────────────────────────────────────────────────────▶│
     │                    │                       │                   │
     │                    │                       │  For each symbol: │
     │                    │                       │    extractProps() │
     │                    │                       │◀──────────────────┤
     │                    │                       │                   │
     │                    │                       │ Parse file        │
     │                    │                       │ Walk AST          │
     │                    │                       │ Extract types     │
     │                    │                       │                   │
     │                    │                       │──[ExtractedProp]─▶│
     │                    │                       │                   │
     │                    │                       │  For each property│
     │                    │                       │   if custom type: │
     │                    │  findSymbolByName()   │                   │
     │                    │◀──────────────────────────────────────────┤
     │                    │                       │                   │
     │                    │  Query index          │                   │
     │                    │  Return symbol        │                   │
     │                    │                       │                   │
     │                    │───IndexedSymbol──────────────────────────▶│
     │                    │                       │                   │
     │                    │                       │  Recurse:         │
     │                    │                       │   processSymbol() │
     │                    │                       │   (with cycle     │
     │                    │                       │    detection)     │
     │                    │                       │                   │
     │                    │                       │◀──────────────────┤
     │                    │                       │                   │
     │                    │                       │  [more queries]   │
     │                    │◀───────────────────────────────────────...│
     │                    │───────────────────────────────────────...▶│
     │                    │                       │                   │
     │◀─────────────────────────────────────────────────[ModelGraph]─┤
     │                    │                       │                   │
     │ JSONEncoder.encode(graph)                  │                   │
     ├─────────                                   │                   │
     │◀────                                       │                   │
     │                    │                       │                   │
     │ Write to file      │                       │                   │
     ├─────────           │                       │                   │
     │                    │                       │                   │
     ▼                    ▼                       ▼                   ▼

Interaction Pattern:
  1. Main orchestrates the pipeline
  2. IndexStoreManager provides symbol lookup services
  3. PropertyExtractor does deep AST analysis
  4. GraphBuilder coordinates between components
  5. Main handles final serialization
```

---

## Technical Deep Dive

### IndexStoreDB Integration

#### What Gets Indexed?

Xcode's index stores:
- All symbols (classes, structs, enums, functions, properties, etc.)
- Their locations (file, line, column)
- Relationships (inheritance, protocol conformance, references)
- Documentation comments

#### Index Update Timing

The index updates when:
- You build your project
- Xcode's background indexer runs
- You explicitly trigger "Build Index" (Editor menu)

**Important**: If the tool can't find your symbols, rebuild your project to update the index.

#### IndexStoreDB Limitations

**1. Macro Indexing**: Macros are a newer feature, indexing may be incomplete
- Solution: Fallback to file scanning

**2. Generated Code**: Code generated at build time may not be fully indexed
- Solution: Run after a successful build

**3. Cross-Module References**: Symbols from other modules may not have complete relationship data
- Solution: Ensure dependencies are built first

### SwiftSyntax AST Structure

#### Understanding the Syntax Tree

For this Swift code:
```swift
struct User {
    let name: String?
}
```

The AST looks like:
```
SourceFileSyntax
└── CodeBlockItemListSyntax
    └── CodeBlockItemSyntax
        └── StructDeclSyntax
            ├── name: "User"
            └── memberBlock
                └── MemberBlockItemListSyntax
                    └── MemberBlockItemSyntax
                        └── VariableDeclSyntax
                            ├── letOrVarKeyword: "let"
                            └── bindings
                                └── PatternBindingSyntax
                                    ├── pattern: IdentifierPatternSyntax("name")
                                    └── typeAnnotation
                                        └── OptionalTypeSyntax
                                            └── wrappedType: IdentifierTypeSyntax("String")
```

#### Visitor Pattern

The `SyntaxVisitor` base class implements a depth-first traversal:

```swift
class SyntaxVisitor {
    // Called before visiting children
    func visit(_ node: SomeSyntax) -> SyntaxVisitorContinueKind
    
    // Called after visiting children
    func visitPost(_ node: SomeSyntax)
}

enum SyntaxVisitorContinueKind {
    case visitChildren  // Continue traversal
    case skipChildren   // Don't visit children
}
```

### Cycle Detection Deep Dive

#### Why Cycles Occur

Bidirectional relationships:
```swift
struct Author {
    let books: [Book]
}

struct Book {
    let author: Author
}
```

Self-referential structures:
```swift
struct TreeNode {
    let children: [TreeNode]
}
```

#### Detection Mechanism

**Using a Visit Set**:
```swift
var visitedUSRs: Set<String> = []

func process(_ symbol: IndexedSymbol) {
    if visitedUSRs.contains(symbol.usr) {
        // Cycle detected!
        return cyclicMarker
    }
    
    visitedUSRs.insert(symbol.usr)
    // Process children...
}
```

**Key Insight**: We insert into the set BEFORE processing children, not after. This ensures we detect cycles during recursive descent.

#### Representing Cycles in Output

Cyclic nodes have:
- `isCyclic: true`
- Empty `children` array
- All other metadata preserved

This allows consumers to:
1. Identify the cycle
2. Know which type is involved
3. See where it's referenced from (`parentPropertyName`)

### Performance Considerations

#### Optimization Strategies

**1. Node Caching**
```swift
private var nodeCache: [String: ModelNode] = [:]
```
Prevents re-parsing the same type multiple times.

**2. Early Exit for Primitives**
```swift
if isPrimitiveType(typeName) {
    return  // Don't query index
}
```
Avoids expensive index queries for known types.

**3. Batch File Reading**
SwiftSyntax parses files once, all properties extracted in one pass.

**4. Index Query Optimization**
```swift
// ❌ Slow: Full scan
indexStore.forEachCanonicalSymbolOccurrence { ... }

// ✅ Fast: Filtered search
indexStore.forEachCanonicalSymbolOccurrence(
    containing: "User",
    anchorStart: true,
    anchorEnd: true
) { ... }
```

#### Complexity Analysis

- **Symbol Discovery**: O(S) where S = symbols in index
- **Property Extraction**: O(F × L) where F = files, L = lines per file
- **Graph Building**: O(N × P) where N = nodes, P = properties per node
- **Overall**: O(N × P) for typical cases

For a project with 100 models × 10 properties each:
- ~1000 index queries
- ~100 file parses
- Total time: < 5 seconds

---

## Usage Guide

### Installation

```bash
# Clone the repository
cd ModelGraphGenerator

# Build release binary
swift build -c release

# Copy to PATH (optional)
cp .build/release/ModelGraphGenerator /usr/local/bin/
```

### Basic Usage

**1. Protocol-based (recommended)**:
```bash
./ModelGraphGenerator \
    --source-path /path/to/YourProject/Sources \
    --marker-name ChimeraSchema
```

**2. Macro-based**:
```bash
./ModelGraphGenerator \
    --source-path /path/to/YourProject/Sources \
    --marker-name ChimeraSchema \
    --use-macro
```

**3. With explicit index path**:
```bash
./ModelGraphGenerator \
    --index-path ~/Library/Developer/Xcode/DerivedData/YourProject-xyz/Index.noindex/DataStore \
    --source-path /path/to/YourProject/Sources
```

**4. Custom output location**:
```bash
./ModelGraphGenerator \
    --source-path /path/to/YourProject/Sources \
    --output /path/to/model-graph.json
```

**5. JSON Schema format output**:
```bash
./ModelGraphGenerator \
    --source-path /path/to/YourProject/Sources \
    --json-schema \
    --output schema.json
```

**6. Verbose logging**:
```bash
./ModelGraphGenerator \
    --source-path /path/to/YourProject/Sources \
    --verbose
```

**7. All options combined**:
```bash
./ModelGraphGenerator \
    --index-path ~/Library/Developer/Xcode/DerivedData/MyApp-xyz/Index.noindex/DataStore \
    --source-path /path/to/MyApp/Sources \
    --marker-name RootModel \
    --use-macro \
    --json-schema \
    --output model-graph-schema.json \
    --verbose
```

### Command-Line Options

```
OPTIONS:
  -i, --index-path <path>      Path to IndexStore (default: auto-detect from DerivedData)
  -s, --source-path <path>     Path to source files directory (REQUIRED)
  -m, --marker-name <name>     Protocol or macro name to search for (default: "ChimeraSchema")
  --use-macro                  Use macro detection (@Macro) instead of protocol conformance
  -o, --output <file>          Output file path (default: write to stdout)
  -v, --verbose                Enable verbose logging
  --json-schema                Output in JSON Schema Draft 2020-12 format
  -h, --help                   Show help information
  --version                    Show version information
```

### Integration with Your Project

**Step 1**: Mark your root models

**Option A - Protocol** (Recommended):
```swift
// Define the protocol in your project
protocol ChimeraSchema {}

// Mark your root models
struct User: ChimeraSchema, Codable {
    let id: String
    let name: String
    let email: String
}

struct Organization: ChimeraSchema, Codable {
    let id: String
    let name: String
    let members: [User]
}
```

**Option B - Macro** (if you have Swift macros set up):
```swift
// Define the macro in your project
@attached(member)
macro ChimeraSchema(key: String? = nil)

// Mark your root models
@ChimeraSchema(key: "user_v1")
struct User: Codable {
    let id: String
    let name: String
    let email: String
}

@ChimeraSchema
struct Organization: Codable {
    let id: String
    let name: String
    let members: [User]
}
```

**Option C - Custom Marker Name**:
```swift
// Use any protocol/macro name you prefer
protocol RootModel {}

struct User: RootModel, Codable {
    let id: String
    let name: String
}

// Then run with: --marker-name RootModel
```

**Step 2**: Build your project
```bash
xcodebuild -scheme YourScheme build
```

This updates the index.

**Step 3**: Run the generator
```bash
./ModelGraphGenerator --source-path ./Sources
```

### Xcode Integration

**Add as Build Phase**:

1. Open your Xcode project
2. Select your target → Build Phases
3. Add "Run Script Phase"
4. Script:
```bash
if [ "${CONFIGURATION}" = "Debug" ]; then
    ${PROJECT_DIR}/ModelGraphGenerator \
        --source-path ${PROJECT_DIR}/Sources \
        --output ${PROJECT_DIR}/Docs/model-graph.json \
        --verbose
fi
```

This regenerates the graph on every debug build.

### CI/CD Integration

**GitHub Actions Example**:
```yaml
name: Generate Model Graph

on: [push, pull_request]

jobs:
  generate-graph:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Build Project
      run: xcodebuild -scheme MyScheme build
    
    - name: Build Graph Generator
      run: |
        cd ModelGraphGenerator
        swift build -c release
    
    - name: Generate Graph
      run: |
        ./ModelGraphGenerator/.build/release/ModelGraphGenerator \
          --source-path ./MyProject/Sources \
          --output ./model-graph.json
    
    - name: Upload Artifact
      uses: actions/upload-artifact@v3
      with:
        name: model-graph
        path: model-graph.json
```

---

## Output Format

### Default JSON Format

The tool generates a complete graph structure with rich metadata:

```json
{
  "generatedAt": "2024-01-15T10:30:00Z",
  "roots": [
    {
      "name": "User",
      "kind": "struct",
      "filePath": "/path/to/User.swift",
      "line": 5,
      "schemaId": "user_schema_v1",
      "inheritsFrom": "BaseModel",
      "inheritedProperties": [
        {
          "name": "id",
          "typeName": "String",
          "isOptional": false,
          "isArray": false,
          "isSet": false,
          "isDictionary": false,
          "codingKey": "identifier",
          "declaredIn": "BaseModel",
          "originallyDeclaredIn": "BaseModel",
          "filePath": "/path/to/BaseModel.swift",
          "line": 3
        }
      ],
      "properties": [
        {
          "name": "email",
          "typeName": "String",
          "isOptional": false,
          "isArray": false,
          "isSet": false,
          "isDictionary": false,
          "codingKey": "email_address",
          "isPolymorphic": false,
          "polymorphism": null
        },
        {
          "name": "orders",
          "typeName": "Order",
          "isOptional": false,
          "isArray": true,
          "isSet": false,
          "isDictionary": false,
          "codingKey": null,
          "isPolymorphic": false,
          "polymorphism": null
        },
        {
          "name": "action",
          "typeName": "Action",
          "isOptional": false,
          "isArray": false,
          "isSet": false,
          "isDictionary": false,
          "codingKey": null,
          "isPolymorphic": true,
          "polymorphism": {
            "discriminatorKey": "type",
            "isProtocol": true,
            "variants": [
              {
                "discriminatorValue": "NAVIGATION",
                "typeName": "NavigationAction",
                "schema": { /* complete NavigationAction schema */ }
              },
              {
                "discriminatorValue": "ALERT",
                "typeName": "AlertAction",
                "schema": { /* complete AlertAction schema */ }
              }
            ]
          }
        }
      ],
      "enumCases": [],
      "children": [
        {
          "name": "Order",
          "kind": "struct",
          "filePath": "/path/to/Order.swift",
          "line": 10,
          "schemaId": null,
          "inheritsFrom": null,
          "inheritedProperties": [],
          "properties": [
            {
              "name": "orderId",
              "typeName": "String",
              "isOptional": false,
              "isArray": false,
              "isSet": false,
              "isDictionary": false,
              "codingKey": "order_id",
              "isPolymorphic": false,
              "polymorphism": null
            }
          ],
          "enumCases": [],
          "children": [],
          "isCyclic": false,
          "parentPropertyName": "orders",
          "isPolymorphic": false,
          "polymorphism": null
        }
      ],
      "isCyclic": false,
      "parentPropertyName": null,
      "isPolymorphic": false,
      "polymorphism": null
    }
  ]
}
```

### JSON Schema Format (--json-schema flag)

When using the `--json-schema` flag, output conforms to JSON Schema Draft 2020-12:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://example.com/schemas/user",
  "title": "User",
  "type": "object",
  "properties": {
    "email_address": {
      "type": "string",
      "description": "email: String (from CodingKeys mapping)"
    },
    "orders": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/Order"
      }
    },
    "action": {
      "oneOf": [
        { "$ref": "#/$defs/NavigationAction" },
        { "$ref": "#/$defs/AlertAction" }
      ],
      "discriminator": {
        "propertyName": "type",
        "mapping": {
          "NAVIGATION": "#/$defs/NavigationAction",
          "ALERT": "#/$defs/AlertAction"
        }
      }
    }
  },
  "required": ["email_address", "orders", "action"],
  "allOf": [
    { "$ref": "#/$defs/BaseModel" }
  ],
  "$defs": {
    "BaseModel": {
      "type": "object",
      "properties": {
        "identifier": { "type": "string" }
      },
      "required": ["identifier"]
    },
    "Order": {
      "type": "object",
      "properties": {
        "order_id": { "type": "string" }
      },
      "required": ["order_id"]
    },
    "NavigationAction": { /* ... */ },
    "AlertAction": { /* ... */ }
  }
}
```

### Field Descriptions

#### ModelGraph
- `generatedAt`: ISO 8601 timestamp of generation
- `roots`: Array of root ModelNode objects (marked with `@ChimeraSchema` or specified via CLI)

#### ModelNode
- `name`: Swift type name
- `kind`: `"struct"`, `"class"`, or `"enum"`
- `filePath`: Absolute path to source file
- `line`: Line number where type is defined
- `schemaId`: Optional schema identifier from `@ChimeraSchema(key: "...")`
- `inheritsFrom`: Optional parent class name (for class inheritance)
- `inheritedProperties`: Array of properties inherited from ancestors
- `properties`: Array of declared properties in this type
- `enumCases`: Array of enum cases (only for enums)
- `children`: Nested custom types found in properties
- `isCyclic`: True if this is a cyclic reference (to avoid infinite recursion)
- `parentPropertyName`: Name of parent's property that references this node
- `isPolymorphic`: True if this is a polymorphic variant
- `polymorphism`: Polymorphic type information (if property can hold multiple types)

#### PropertyInfo
- `name`: Swift property name
- `typeName`: Base type (unwrapped from Optional/Array/Set/Dictionary)
- `isOptional`: True for `Type?`
- `isArray`: True for `[Type]` or `Array<Type>`
- `isSet`: True for `Set<Type>`
- `isDictionary`: True for `[Key: Value]` or `Dictionary<Key, Value>`
- `codingKey`: JSON key from CodingKeys enum (null if property name == JSON key)
- `isPolymorphic`: True if property can hold multiple types
- `polymorphism`: Contains discriminator and type variants

#### InheritedPropertyInfo
All fields from PropertyInfo, plus:
- `declaredIn`: Immediate parent class that declares this property
- `originallyDeclaredIn`: Original ancestor where property was first declared
- `filePath`: Source file of original declaration
- `line`: Line number in source file

#### PolymorphicInfo
- `discriminatorKey`: Property name used to identify type ("type", "kind", "action")
- `variants`: Array of possible type variants with their schemas
- `isProtocol`: True if from protocol conformance, false if from `@PolymorphicMapping`

#### PolymorphicVariant
- `discriminatorValue`: Value identifying this variant ("NAVIGATION", "success")
- `typeName`: Swift type name for this variant
- `schema`: Complete ModelNode schema for this variant

#### EnumCaseInfo
- `name`: Enum case name
- `associatedValues`: Array of associated value type names
- `rawValue`: Raw value for RawRepresentable enums

### Processing the Output

**Python Example**:
```python
import json

with open('model-graph.json') as f:
    graph = json.load(f)

def print_tree(node, indent=0):
    prefix = "  " * indent
    marker = " [CYCLIC]" if node['isCyclic'] else ""
    print(f"{prefix}- {node['name']}{marker}")
    
    if not node['isCyclic']:
        for child in node['children']:
            print_tree(child, indent + 1)

for root in graph['roots']:
    print_tree(root)
```

**JavaScript/TypeScript**:
```typescript
interface ModelGraph {
    generatedAt: string;
    roots: ModelNode[];
}

interface ModelNode {
    name: string;
    kind: string;
    filePath: string;
    line: number;
    properties: PropertyInfo[];
    enumCases: EnumCaseInfo[];
    children: ModelNode[];
    isCyclic: boolean;
    parentPropertyName?: string;
}

// Load and process
const graph: ModelGraph = JSON.parse(fs.readFileSync('model-graph.json', 'utf8'));

// Find all cyclic references
function findCycles(node: ModelNode, path: string[] = []): string[] {
    const cycles: string[] = [];
    const currentPath = [...path, node.name];
    
    if (node.isCyclic) {
        cycles.push(currentPath.join(' → '));
    }
    
    for (const child of node.children) {
        cycles.push(...findCycles(child, currentPath));
    }
    
    return cycles;
}
```

### Visualization Ideas

**1. Generate Mermaid Diagram**:
```python
def to_mermaid(graph):
    lines = ["graph TD"]
    
    def traverse(node, parent_id=None):
        node_id = node['name'].replace(' ', '_')
        lines.append(f"    {node_id}[{node['name']}]")
        
        if parent_id:
            lines.append(f"    {parent_id} --> {node_id}")
        
        if not node['isCyclic']:
            for child in node['children']:
                traverse(child, node_id)
    
    for root in graph['roots']:
        traverse(root)
    
    return "\n".join(lines)
```

**2. Generate GraphViz DOT**:
```python
def to_dot(graph):
    lines = ["digraph ModelGraph {"]
    
    def traverse(node, parent=None):
        node_id = f"\"{node['name']}\""
        shape = "ellipse" if node['isCyclic'] else "box"
        lines.append(f"    {node_id} [shape={shape}];")
        
        if parent:
            label = node.get('parentPropertyName', '')
            lines.append(f"    \"{parent}\" -> {node_id} [label=\"{label}\"];")
        
        if not node['isCyclic']:
            for child in node['children']:
                traverse(child, node['name'])
    
    for root in graph['roots']:
        traverse(root)
    
    lines.append("}")
    return "\n".join(lines)
```

---

## Troubleshooting

### Common Issues

#### 1. "Index store not found"

**Symptom**:
```
❌ Index store not found: Could not find Index.noindex/DataStore...
```

**Causes**:
- Project hasn't been built yet
- Using a different Xcode version
- DerivedData was cleaned

**Solutions**:
```bash
# Build your project first
xcodebuild -scheme YourScheme build

# Or specify index path explicitly
./ModelGraphGenerator \
    --index-path ~/Library/Developer/Xcode/DerivedData/YourProject-xyz/Index.noindex/DataStore \
    --source-path ./Sources

# Find your index path
find ~/Library/Developer/Xcode/DerivedData -name "DataStore" -type d
```

#### 2. "No symbols found"

**Symptom**:
```
⚠️ No symbols found conforming to RootModel protocol
{"roots": []}
```

**Causes**:
- Marker name doesn't match (case-sensitive)
- Protocol/macro not defined in indexed code
- Stale index

**Solutions**:
```bash
# Check marker name (case-sensitive!)
# ❌ --marker-name rootmodel
# ✅ --marker-name RootModel

# Rebuild index
xcodebuild -scheme YourScheme clean build

# Enable verbose logging to debug
./ModelGraphGenerator \
    --source-path ./Sources \
    --marker-name RootModel \
    --verbose
```

#### 3. "Failed to open index"

**Symptom**:
```
❌ Failed to open index: Could not load indexstore library
```

**Cause**: Xcode not installed or wrong path

**Solution**:
```bash
# Install Xcode from App Store
# Or download from developer.apple.com

# Verify Xcode installation
xcode-select -p
# Should output: /Applications/Xcode.app/Contents/Developer

# If wrong path, set it
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

#### 4. "Could not find libIndexStore.dylib"

**Symptom**:
```
❌ Could not find libIndexStore.dylib. Make sure Xcode is installed.
```

**Cause**: Non-standard Xcode installation

**Solution**:
```bash
# Find the library
find /Applications -name "libIndexStore.dylib" 2>/dev/null

# Common locations:
# /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib
# /Applications/Xcode-beta.app/.../libIndexStore.dylib
```

#### 5. "Parsing failed"

**Symptom**:
```
⚠️ Failed to parse User: Source file not found
```

**Causes**:
- File path in index is stale
- File was moved/deleted
- Relative path issue

**Solutions**:
```bash
# Ensure source path is correct
ls -la /path/to/Sources

# Use absolute paths
./ModelGraphGenerator \
    --source-path "$(pwd)/Sources"

# Rebuild project to update file paths in index
xcodebuild -scheme YourScheme clean build
```

#### 6. Missing child types

**Symptom**: Some custom types aren't explored

**Causes**:
- Type is in a different module
- Type is not indexed (build dependency)
- Type name classified as primitive

**Solutions**:
```bash
# Ensure dependencies are built
xcodebuild -scheme YourScheme build

# Check if type is in index
# Enable verbose logging to see which types are skipped
./ModelGraphGenerator --source-path ./Sources --verbose

# Look for messages like:
# "Could not find TypeName in index"
```

#### 7. Incomplete type information

**Symptom**: Properties missing or wrong types

**Cause**: SwiftSyntax parsing edge case

**Debug**:
```bash
# Enable verbose logging
./ModelGraphGenerator --source-path ./Sources --verbose

# Look for parsing details:
# "Extracted N properties from TypeName"

# Check the source file syntax
# Computed properties are intentionally skipped
```

### Debug Tips

**1. Check Index Contents**:
```bash
# Find your index
DERIVED_DATA=~/Library/Developer/Xcode/DerivedData
INDEX_PATH=$(find "$DERIVED_DATA" -name "DataStore" -type d | head -n 1)

# Index is an SQLite database, you can query it
echo "Index path: $INDEX_PATH"
```

**2. Verify Symbol Indexing**:
```bash
# Rebuild with verbose output
xcodebuild -scheme YourScheme clean build | grep "Indexing"

# Force index rebuild
rm -rf ~/Library/Developer/Xcode/DerivedData
xcodebuild -scheme YourScheme build
```

**3. Test with Simple Model**:
```swift
// Create test file: TestModel.swift
protocol RootModel {}

struct SimpleTest: RootModel {
    let name: String
}
```

```bash
# Build and run generator
xcodebuild -scheme YourScheme build
./ModelGraphGenerator --source-path ./Sources --verbose
```

If this works, gradually add complexity.

---

## Advanced Topics

### Extending the Tool

#### Adding Custom Type Detection

Edit [GraphBuilder.swift](GraphBuilder.swift#L175-L200):

```swift
private func shouldExploreType(_ typeName: String) -> Bool {
    // Add your custom types to skip
    let customFrameworkTypes: Set<String> = [
        "MyFrameworkType",
        "CustomView"
    ]
    
    if customFrameworkTypes.contains(typeName) {
        return false
    }
    
    // Existing logic...
}
```

#### Custom Output Formats

Add new encoders in [Main.swift](Main.swift#L90-L100):

```swift
// YAML output
import Yams
let yamlString = try Yams.dump(object: graph)

// XML output
let xmlEncoder = PropertyListEncoder()
xmlEncoder.outputFormat = .xml
let xmlData = try xmlEncoder.encode(graph)

// Pretty print to console
print(graph.prettyPrint())
```

#### Additional Metadata

Extend [Models.swift](Models.swift) to capture more info:

```swift
struct PropertyInfo: Codable {
    // Existing properties...
    
    // New properties
    let isComputed: Bool
    let accessLevel: String  // "public", "private", etc.
    let documentation: String?
}
```

Update [PropertyExtractor.swift](PropertyExtractor.swift) to extract:

```swift
// Check access level modifiers
var accessLevel = "internal"
for modifier in node.modifiers {
    if ["public", "private", "fileprivate", "open"].contains(modifier.name.text) {
        accessLevel = modifier.name.text
    }
}
```

### Performance Tuning

For very large codebases:

**1. Parallel Processing**:
```swift
let queue = DispatchQueue(label: "graph-builder", attributes: .concurrent)
let group = DispatchGroup()

for symbol in rootSymbols {
    group.enter()
    queue.async {
        let node = try? self.processSymbol(symbol)
        // Handle result...
        group.leave()
    }
}

group.wait()
```

**2. Incremental Updates**:
```swift
// Cache previous graph
// Only rebuild changed subtrees
let previousGraph = try? loadPreviousGraph()
if let previous = previousGraph {
    // Compare and update only differences
}
```

**3. Lazy Loading**:
```swift
// Don't load all properties upfront
// Load on-demand as graph is traversed
struct LazyModelNode {
    let symbol: IndexedSymbol
    var children: [LazyModelNode]? = nil  // Load when accessed
}
```

---

## Conclusion

ModelGraphGenerator is a powerful tool for understanding and documenting Swift model relationships. By leveraging Xcode's IndexStoreDB and SwiftSyntax, it provides accurate, automated analysis of your data structures.

### Key Takeaways

1. **IndexStoreDB** provides efficient symbol discovery without parsing every file
2. **SwiftSyntax** ensures accurate type information including generics
3. **Cycle detection** prevents infinite recursion in bidirectional relationships
4. **Flexible markers** support both protocols and macros
5. **Structured output** enables integration with documentation and visualization tools

### Next Steps

- Run the tool on your project
- Visualize the output with Mermaid or GraphViz
- Integrate into your CI/CD pipeline
- Extend with custom metadata for your use case

### Contributing

The codebase is well-structured for contributions:
- Add new output formats
- Improve type detection
- Add Swift language features support
- Enhance performance for large codebases

---

## How Macro Annotation Discovery Works

This section explains the unique approach used in this tool to find and process Swift macro annotations like `@RootModel`.

### The Challenge with Macro Annotations

Unlike protocol conformance, which is well-indexed by Xcode's IndexStoreDB, macro annotations are relatively new to Swift. The challenge is that IndexStoreDB doesn't reliably index macro usages. Traditional approaches that query the index directly for macro references often fail to return any results, even when macros are present in the code.

The fundamental problem is that while IndexStoreDB excels at tracking type definitions, inheritance relationships, and protocol conformances, it wasn't designed with macro annotations in mind. This means we can't simply ask the index "show me all types annotated with @RootModel" and get reliable results.

### Our Hybrid Approach: SourceKit + IndexStore

To solve this reliability issue, we developed a two-phase hybrid approach that combines the best of both worlds:

**Phase 1: SourceKit-style File Scanning** - This phase answers the question "WHERE are the macros used?" by directly scanning source files.

**Phase 2: IndexStore Symbol Resolution** - This phase answers the question "WHAT symbols do those macros annotate?" by using IndexStoreDB to get proper symbol information.

This separation of concerns ensures we never miss a macro (because we're directly reading files) while still getting accurate symbol metadata with proper USRs (because we're using the index).

---

### Phase 1: Finding Macro Locations with Direct File Scanning

The first phase uses a direct file system approach (we call it "SourceKit-style" in the code, though it doesn't use SourceKit API - it's named that way because the approach is inspired by how SourceKit would work). This phase is conceptually straightforward but crucial for reliability.

**The Process:**

The tool walks through your source directory and finds every Swift file. For each file, it reads the content and searches for the macro annotation pattern using regular expressions - looking for things like `@RootModel`, `@RootModel()`, or `@RootModel(parameters)`.

**Important Note:** This is NOT using SourceKit API. We're doing literal file system traversal and text pattern matching. The `SourceKitManager` class name can be misleading - it's called that because the approach mimics what SourceKit does conceptually, but we're implementing it ourselves with file reading and regex matching. This gives us complete control and reliability regardless of SourceKit's state.

When a match is found, the tool records three pieces of information: the file path where the macro appears, the line number, and the column position. This creates a complete map of every location where your macro annotation is used.

For example, if you have three files with `@RootModel` annotations, Phase 1 might discover:
- Models.swift at line 15
- User.swift at line 10  
- Order.swift at line 25

The key insight here is that this approach is **completely independent of IndexStoreDB**. Whether Xcode has indexed your code or not, whether the index is fresh or stale, this phase will always find the macros because it's reading the source files directly. This guarantees we never miss a macro due to indexing issues.

---

### Phase 2: Resolving Symbols with IndexStore

Once we know WHERE macros appear, we need to figure out WHAT they're annotating. A macro like `@RootModel` typically appears just before a type declaration (struct, class, or enum), but we need to get the full details of that type - its name, its unique identifier (USR), and other metadata.

This is where IndexStoreDB becomes valuable. Instead of trying to find the macro itself in the index (which doesn't work reliably), we use the location information from Phase 1 to query for symbols that are defined near those locations.

**The Process:**

For each macro location discovered in Phase 1, we perform symbol resolution using two strategies:

**Strategy 1: Query IndexStore for Nearby Symbols**

The tool queries IndexStoreDB asking "what struct, class, or enum definitions exist in this file near this line number?" Since macros appear just before type declarations, we search for symbols defined within a few lines after the macro (typically within 5 lines).

When we find a matching symbol, IndexStoreDB gives us the complete information - the symbol's proper name, its Unified Symbol Resolution identifier (USR), its kind (struct/class/enum), and its exact location. The USR is particularly important because it's a globally unique identifier that works across the entire codebase, handling edge cases like multiple types with the same name in different modules.

**Strategy 2: Parse File Directly (Fallback)**

If IndexStore doesn't have the symbol (perhaps because the code is very fresh and hasn't been indexed yet), we fall back to parsing the file ourselves. We read the lines after the macro location and use pattern matching to identify type declarations - looking for keywords like "struct User" or "class Organization".

If we find the type name, we try one more time to get its USR from IndexStore by name. If that still fails (meaning the symbol truly isn't indexed yet), we create what we call a "synthetic USR" - a temporary identifier based on the file path and type name. This allows the tool to continue working even with completely unindexed code.

**The Linking Magic:**

The beauty of this phase is that it takes the "dumb" location information from Phase 1 (just file paths and line numbers) and enriches it with "smart" symbol metadata from IndexStore. We start with "there's an @RootModel at line 15" and end with "the @RootModel at line 15 annotates the User struct with USR s:6Models4UserV defined at line 16".

---

### Why This Approach Works

The hybrid approach solves the fundamental tension between reliability and quality:

**File Scanning (Phase 1)** provides reliability. It will always find macros, regardless of:
- Whether the project has been built recently
- Whether Xcode's index is up to date
- What version of Xcode you're using
- Whether macro indexing is working correctly

**IndexStore Queries (Phase 2)** provide quality. When available, they give us:
- Proper USRs that are globally unique
- Accurate symbol kinds and metadata
- Consistent identifiers for cross-referencing
- Integration with the rest of the symbol graph

By separating these concerns, we get the best of both worlds. We never miss macros (because we're reading files), but we get high-quality symbol information whenever possible (because we're using the index).

---

### Real-World Example Walkthrough

Let's walk through how the tool would process a real project. Imagine you have a file called Models.swift with this structure:

The file imports Foundation, then has an `@RootModel` annotation on line 5, followed by a User struct definition on line 6. Further down, there's another `@RootModel` annotation on line 12, followed by an Organization class on line 13.

**Phase 1 Execution:**

The tool's file scanner walks through your project directory and finds Models.swift. It reads the file content and processes each line. When it reaches line 5, the pattern matcher identifies `@RootModel` and records the location. It continues scanning and finds another `@RootModel` on line 12.

The output of Phase 1 is a list of locations: two macro usages in Models.swift, one at line 5 and one at line 12.

**Phase 2 Execution:**

Now the tool processes each location:

For the macro at line 5, it queries IndexStoreDB asking "what symbols are defined in Models.swift near line 5?" The index responds with information about a struct named User at line 6. Since line 6 is just one line after the macro (well within our search range), this is clearly the symbol being annotated. The index provides the full USR for the User struct, which looks something like "s:7project4UserV". The tool records this as a complete symbol.

For the macro at line 12, the same process happens. The query finds the Organization class at line 13, gets its USR "s:7project12OrganizationC", and records it.

**Final Result:**

The tool now has two complete IndexedSymbol objects:
- User struct with full USR and metadata
- Organization class with full USR and metadata

These symbols are then passed to the graph building phase, where their properties are extracted and relationships are mapped out.

---

### Fallback Mechanism

If both strategies in Phase 2 fail to find any symbols (perhaps due to unusual code formatting or comments interfering with the search), there's a third fallback phase. This performs a more exhaustive but slower search through the entire index, checking each symbol definition to see if its source code contains the macro annotation nearby. This ensures absolute completeness, even in edge cases.

---

### The Complete Pipeline Flow

The overall flow can be visualized as a funnel:

At the top, the user runs the command specifying they want to use macro-based discovery. The tool receives the macro name (like "RootModel") and the source path.

This flows into Phase 1, the SourceKit scanning stage. Here, the file system is traversed, every Swift file is read, and regex patterns are applied. The output is a collection of file paths, line numbers, and column positions.

These locations flow into Phase 2, the IndexStore linking stage. For each location, queries are made to the index, symbols are resolved, and metadata is enriched. The output is a collection of IndexedSymbol objects with complete USR information.

Finally, there's a deduplication step where any duplicate symbols (same USR) are filtered out, ensuring each unique symbol appears only once.

The resulting clean list of symbols is then passed to the GraphBuilder component, which extracts properties, builds relationships, and generates the final JSON output.

---

### Why This Matters

This innovative approach makes the tool robust and reliable across different scenarios:

- **Fresh Code**: Works even if you just wrote the code and haven't built yet
- **Old Projects**: Works with legacy codebases that have stale indexes
- **Different Xcode Versions**: Not dependent on specific indexing behavior
- **Partial Builds**: Functions even if only part of your project has been built
- **Development Workflow**: Doesn't require a clean build before running

The separation of "finding" (Phase 1) from "resolving" (Phase 2) is the key innovation that makes macro-based model discovery practical and reliable in real-world development scenarios.

---

**Generated**: December 21, 2025  
**Version**: 1.0.0  
**Last Updated**: January 14, 2026

```swift
func findAllMacroUsages(macroName: String, sourcePath: String) 
    -> [(filePath: String, line: Int, column: Int)]
```

**How it works**:

1. **Enumerate all Swift files** in the source directory:
   ```swift
   let enumerator = FileManager.default.enumerator(
       at: URL(fileURLWithPath: sourcePath),
       includingPropertiesForKeys: [.isRegularFileKey],
       options: [.skipsHiddenFiles, .skipsPackageDescendants]
   )
   ```

2. **For each `.swift` file**, read its contents:
   ```swift
   let content = try String(contentsOfFile: filePath, encoding: .utf8)
   let lines = content.components(separatedBy: .newlines)
   ```

3. **Apply regex pattern** to find `@MacroName`:
   ```swift
   let pattern = "@\(macroName)(?:\\([^)]*\\))?"
   // Matches:
   //   @RootModel
   //   @RootModel()
   //   @RootModel(someParam: "value")
   ```

4. **Record the location** of each match:
   ```swift
   usages.append((filePath: "/path/to/User.swift", line: 10, column: 5))
   ```

**Result**: An array of locations where the macro annotation appears:
```swift
[
    (filePath: "/path/to/Models.swift", line: 15, column: 1),
    (filePath: "/path/to/User.swift", line: 10, column: 1),
    (filePath: "/path/to/Order.swift", line: 25, column: 1)
]
```

---

### Phase 2: Resolving Symbols with IndexStore

**Goal**: For each macro location, find the actual Swift symbol (struct/class/enum) that it annotates

**Implementation** (`IndexStoreManager` extension in `SourceKitManager.swift`):

```swift
func findSymbolsWithMacroUsingSourceKit(macroName: String, sourcePath: String) 
    -> [IndexedSymbol]
```

**How it works**:

For each location found in Phase 1, we call:
```swift
findSymbolAnnotatedByMacro(atFile: filePath, line: line) -> IndexedSymbol?
```

This function uses **two strategies** to find the symbol:

#### Strategy 1: Query IndexStore for nearby symbols

**Rationale**: Macros appear just before the type declaration, so we search for struct/class/enum definitions within a few lines after the macro.

```swift
indexStore.forEachCanonicalSymbolOccurrence { occurrence in
    // Only look at definitions in the same file
    guard occurrence.location.path == filePath,
          occurrence.roles.contains(.definition),
          (occurrence.symbol.kind == .struct ||
           occurrence.symbol.kind == .class ||
           occurrence.symbol.kind == .enum) else {
        return true  // Continue searching
    }
    
    // Calculate distance from macro line
    let distance = occurrence.location.line - line
    
    // Type should be within 5 lines after the macro
    if distance >= 0 && distance <= 5 {
        // Found it! Create IndexedSymbol with USR
        return IndexedSymbol(
            name: occurrence.symbol.name,
            usr: occurrence.symbol.usr,  // ← Full USR from IndexStore!
            kind: occurrence.symbol.kind,
            filePath: occurrence.location.path,
            line: occurrence.location.line
        )
    }
}
```

**Example**:
```swift
// File: Models.swift
// Line 10: @RootModel
// Line 11: struct User {
//             ↑
//    IndexStore has this symbol with USR: s:6Models4UserV

// Search finds: occurrence at line 11, kind = .struct, name = "User"
// Distance = 11 - 10 = 1 ✓ (within 5 lines)
// Return: IndexedSymbol with full USR
```

#### Strategy 2: Parse file directly (fallback)

**Rationale**: If IndexStore doesn't have the symbol yet (e.g., very fresh code, not built yet), we parse the file ourselves.

```swift
// Read lines from the file
let lines = content.components(separatedBy: .newlines)

// Search next few lines after macro for type declaration
for i in (afterLine - 1)..<min(afterLine + 5, lines.count) {
    let line = lines[i]
    
    // Regex: (struct|class|enum)\s+(\w+)
    let pattern = #"(?:public\s+|private\s+)?(struct|class|enum)\s+(\w+)"#
    
    if let match = regex.firstMatch(in: line) {
        let kind = extractKind(from: match)      // "struct"
        let name = extractName(from: match)      // "User"
        
        // Try to get USR from IndexStore by name
        if let indexed = findSymbolByName(name, inFile: filePath) {
            return indexed  // Has USR from IndexStore
        }
        
        // Still not in index? Create synthetic symbol
        return IndexedSymbol(
            name: name,
            usr: "file://\(filePath)#\(name)",  // Synthetic USR
            kind: kind,
            filePath: filePath,
            line: i + 1
        )
    }
}
```

**Example**:
```swift
// File: Models.swift (not yet in IndexStore)
// Line 10: @RootModel
// Line 11: struct User {

// Parse line 11: matches "struct User"
// Try findSymbolByName("User") → nil (not indexed yet)
// Create synthetic: IndexedSymbol(name: "User", usr: "file://Models.swift#User", ...)
```

---

### Linking It All Together

The complete flow in `IndexStoreManager.findSymbolsWithMacroUsingSourceKit()`:

```swift
func findSymbolsWithMacroUsingSourceKit(macroName: String, sourcePath: String) 
    -> [IndexedSymbol] {
    
    var foundSymbols: [IndexedSymbol] = []
    
    // PHASE 1: Find macro locations
    let sourceKitManager = try SourceKitManager(logger: logger)
    let usages = sourceKitManager.findAllMacroUsages(
        macroName: macroName, 
        sourcePath: sourcePath
    )
    // Returns: [(filePath, line, column), ...]
    
    logger.info("Found \(usages.count) @\(macroName) annotations")
    
    // PHASE 2: Resolve each location to a symbol
    for (filePath, line, column) in usages {
        logger.debug("Processing @\(macroName) at \(filePath):\(line)")
        
        // Use IndexStore to find the symbol
        if let symbol = findSymbolAnnotatedByMacro(atFile: filePath, line: line) {
            foundSymbols.append(symbol)
            logger.info("  ✓ Resolved: \(symbol.kind) \(symbol.name)")
            logger.debug("    USR: \(symbol.usr)")
        } else {
            logger.warning("  ✗ Could not resolve symbol")
        }
    }
    
    // Remove duplicates by USR
    var seenUSRs = Set<String>()
    return foundSymbols.filter { symbol in
        guard !seenUSRs.contains(symbol.usr) else { return false }
        seenUSRs.insert(symbol.usr)
        return true
    }
}
```

---

### Why This Approach Works

**✅ Advantages**:

1. **Reliability**: File scanning always finds macros, regardless of index state
2. **Accuracy**: IndexStore provides proper USRs and metadata when available
3. **Graceful degradation**: Falls back to synthetic USRs when symbols aren't indexed
4. **No false negatives**: Won't miss macros due to incomplete indexing
5. **Fast**: File scanning is parallelizable; index queries are quick

**🔍 Key Insight**: 

We separate the concerns:
- **SourceKit approach** = WHERE (file locations) - always reliable
- **IndexStore approach** = WHAT (symbol metadata) - best quality when available

By combining both, we get the best of both worlds!

---

### Real-World Example

**Given this code**:
```swift
// File: /project/Sources/Models.swift

import Foundation

@RootModel
struct User: Codable {
    let id: String
    let name: String
    let email: String
}

@RootModel
class Organization {
    let id: String
    let name: String
}
```

**Execution trace**:

```
🔍 Phase 1: SourceKit File Scanning
  → Scanning /project/Sources/Models.swift
  → Found @RootModel at line 5, column 1
  → Found @RootModel at line 12, column 1
  → Total: 2 macro usages

🔗 Phase 2: IndexStore Symbol Resolution
  
  Processing @RootModel at Models.swift:5
    → Query IndexStore for symbols near line 5
    → Found: struct User at line 6
    → Distance: 6 - 5 = 1 ✓
    → USR: s:7project4UserV
    ✓ Resolved: struct User
  
  Processing @RootModel at Models.swift:12
    → Query IndexStore for symbols near line 12
    → Found: class Organization at line 13
    → Distance: 13 - 12 = 1 ✓
    → USR: s:7project12OrganizationC
    ✓ Resolved: class Organization

📊 Result: 2 symbols resolved
[
    IndexedSymbol(
        name: "User",
        usr: "s:7project4UserV",
        kind: .struct,
        filePath: "/project/Sources/Models.swift",
        line: 6
    ),
    IndexedSymbol(
        name: "Organization",
        usr: "s:7project12OrganizationC",
        kind: .class,
        filePath: "/project/Sources/Models.swift",
        line: 13
    )
]
```

These symbols are then passed to `GraphBuilder` for property extraction and relationship building!

---

### Fallback: IndexStore-Only Scan

If Phase 1 + Phase 2 find nothing (e.g., macros in comments, unusual formatting), there's a **Phase 3 fallback**:

```swift
if foundSymbols.isEmpty {
    logger.info("=== Phase 3: Falling back to IndexStore-only scan ===")
    foundSymbols = try findSymbolsWithMacro(macroName: macroName)
}
```

This performs a more exhaustive (but slower) search through the entire index, checking source content for each symbol definition.

---

### Summary: The Complete Macro Discovery Pipeline

```
┌─────────────────────────────────────────────────────────┐
│                  User runs command:                      │
│  ./ModelGraphGenerator --source-path ./Sources           │
│                       --use-macro                        │
│                       --marker-name RootModel            │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
         ┌───────────────────────────────────┐
         │   Phase 1: SourceKit Scanning     │
         ├───────────────────────────────────┤
         │ • Enumerate all .swift files      │
         │ • Read each file content          │
         │ • Regex match @RootModel          │
         │ • Collect (file, line, column)    │
         └────────────┬──────────────────────┘
                      │
                      │ usages = [(file, line, col), ...]
                      ▼
         ┌───────────────────────────────────┐
         │   Phase 2: IndexStore Linking     │
         ├───────────────────────────────────┤
         │ For each usage location:          │
         │   ├─ Query IndexStore             │
         │   │  for symbol near line         │
         │   │                               │
         │   ├─ If found:                    │
         │   │  Get USR, kind, name          │
         │   │                               │
         │   └─ If not found:                │
         │      Parse file directly          │
         │      Create synthetic USR         │
         └────────────┬──────────────────────┘
                      │
                      │ symbols = [IndexedSymbol, ...]
                      ▼
         ┌───────────────────────────────────┐
         │  Deduplication by USR             │
         └────────────┬──────────────────────┘
                      │
                      │ unique symbols
                      ▼
         ┌───────────────────────────────────┐
         │  Pass to GraphBuilder             │
         │  • Extract properties             │
         │  • Build relationships            │
         │  • Generate JSON                  │
         └───────────────────────────────────┘
```

This innovative approach ensures **robust macro discovery** even when IndexStoreDB's macro indexing is incomplete, making the tool reliable across different Xcode versions and build states!

---

**Generated**: December 21, 2025  
**Version**: 1.0.0  
**Last Updated**: January 14, 2026
