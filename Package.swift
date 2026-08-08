// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "vmd",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VMD", targets: ["VMDApp"]),
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
            dependencies: ["VMDCore"]
        ),
        .executableTarget(
            name: "vmd"
        ),
        .testTarget(
            name: "VMDCoreTests",
            dependencies: ["VMDCore"]
        ),
    ]
)
