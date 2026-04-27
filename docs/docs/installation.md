---
id: installation
title: Installation
sidebar_label: Installation
sidebar_position: 2
---

# Installation

ModelGraphGenerator is distributed as a Swift package and is built using Swift Package Manager.

## Requirements

| Requirement | Version |
|-------------|---------|
| Swift | 5.9+ |
| macOS | 13.0 (Ventura)+ |
| Xcode | 15.0+ |
| Xcode Command Line Tools | Latest |

## Step 1: Install Xcode Command Line Tools

If you haven't already, install the command line tools:

```bash
xcode-select --install
```

Verify the installation:

```bash
xcode-select -p
# Expected output: /Applications/Xcode.app/Contents/Developer
```

## Step 2: Clone the Repository

```bash
git clone https://github.com/PhonePe/ModelGraphGenerator.git
cd ModelGraphGenerator
```

## Step 3: Build the CLI

```bash
swift build -c release
```

This produces the `model-graph-generator` binary in `.build/release/`:

```bash
ls -la .build/release/model-graph-generator
# -rwxr-xr-x  ...  .build/release/model-graph-generator
```

## Step 4: Install Globally (Optional)

To use `model-graph-generator` from anywhere, copy it to a directory on your `$PATH`:

```bash
# Option A: /usr/local/bin
sudo cp .build/release/model-graph-generator /usr/local/bin/

# Option B: ~/bin (user-only, no sudo required)
mkdir -p ~/bin
cp .build/release/model-graph-generator ~/bin/
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Step 5: Verify Installation

```bash
model-graph-generator --help
```

Expected output:

```
USAGE: model-graph-generator [<options>]

OPTIONS:
  --source-path <source-path>
                          Path to the Swift source directory
  --symbol-name <symbol-name>
                          Optional: name of a specific symbol to generate schema for
  --macro-only            Only process files with @ChimeraSchema annotations
  --output <output>       Output file path for the generated schema
  --json-schema           Generate JSON Schema format
  --verbose               Enable verbose logging
  -h, --help              Show help information.
```

## Use as a Package Dependency

You can also add ModelGraphGenerator to your `Package.swift` as a dependency:

```swift
// Package.swift
dependencies: [
    .package(
        url: "https://github.com/PhonePe/ModelGraphGenerator.git",
        from: "1.0.0"
    )
],
```

## Updating

To update to the latest version:

```bash
cd ModelGraphGenerator
git pull origin main
swift build -c release
# Optionally reinstall the binary
sudo cp .build/release/model-graph-generator /usr/local/bin/
```

## Troubleshooting

### Build fails with "cannot find type"

Ensure you have Swift 5.9 or later:

```bash
swift --version
# Swift version 5.9.x (swift-5.9.x-RELEASE)
```

### IndexStoreDB errors on older macOS

ModelGraphGenerator requires macOS 13.0+. Check your macOS version:

```bash
sw_vers -productVersion
```

### Permission denied when copying binary

Use `sudo` when copying to system directories:

```bash
sudo cp .build/release/model-graph-generator /usr/local/bin/
```

### Build succeeds but binary not found

Ensure the install directory is in your `$PATH`:

```bash
echo $PATH
which model-graph-generator
```
