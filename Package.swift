// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "vmd",
    platforms: [.macOS(.v14)],
    products: [
        // Note: must not collide case-insensitively with the "vmd" CLI product,
        // or both executables land on the same file in .build.
        .executable(name: "VMDApp", targets: ["VMDApp"]),
        .executable(name: "vmd", targets: ["vmd"]),
        .library(name: "VMDCore", targets: ["VMDCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-cmark.git", branch: "gfm"),
    ],
    targets: [
        .target(
            name: "VMDCore",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
            ]
        ),
        .executableTarget(
            name: "VMDApp",
            dependencies: ["VMDCore"],
            resources: [
                .copy("Resources/mermaid.min.js"),
                .copy("Resources/highlight.min.js"),
                .copy("Resources/highlight.css"),
                .copy("Resources/katex"),
            ]
        ),
        .executableTarget(
            name: "vmd",
            dependencies: ["VMDCore"]
        ),
        .testTarget(
            name: "VMDCoreTests",
            dependencies: ["VMDCore"]
        ),
    ]
)
