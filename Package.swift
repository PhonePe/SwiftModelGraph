// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ModelGraphGenerator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ModelGraphGenerator",
            targets: ["ModelGraphGenerator"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"), // Recommended for Swift 6.2
        // Change branch from release/6.0 to release/6.2
        .package(url: "https://github.com/apple/indexstore-db.git", branch: "release/6.2.2"), 
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "ModelGraphGenerator",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "IndexStoreDB", package: "indexstore-db"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "ModelGraphGeneratorTests",
            dependencies: [
                "ModelGraphGenerator",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            path: "Tests"
        )
    ]
)
