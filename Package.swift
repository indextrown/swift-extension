// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SwiftExtension",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        .library(
            name: "Algorithm",
            targets: ["Algorithm"]
        ),
        .library(
            name: "Labs",
            targets: ["Labs"]
        ),
        .library(
            name: "SwiftExtension",
            targets: ["SwiftExtension"]
        ),
    ],
    targets: [
        .target(name: "Algorithm"),
        .target(
            name: "Labs",
            exclude: ["Stack"]
        ),
        .target(name: "SwiftExtension"),
        .testTarget(
            name: "AlgorithmTests",
            dependencies: ["Algorithm"]
        ),
        .testTarget(
            name: "LabsTests",
            dependencies: ["Labs"]
        ),
        .testTarget(
            name: "SwiftExtensionTests",
            dependencies: ["SwiftExtension"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
