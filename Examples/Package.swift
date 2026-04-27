// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Examples",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Examples",
            targets: ["Examples"]
        )
    ],
    targets: [
        .target(
            name: "Examples",
            path: "."
        )
    ]
)
