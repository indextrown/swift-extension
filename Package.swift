// swift-tools-version: 5.9

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
        .library(
            name: "UIComponentsCore",
            targets: ["UIComponentsCore"]
        ),
        .library(
            name: "UIKitExtension",
            targets: ["UIKitExtension"]
        ),
        .library(
            name: "SwiftUIExtension",
            targets: ["SwiftUIExtension"]
        ),
    ],
    targets: [
        .target(name: "Algorithm"),
        .target(
            name: "Labs",
            exclude: ["Stack"]
        ),
        .target(name: "SwiftExtension"),
        .target(name: "UIComponentsCore"),
        .target(
            name: "UIKitExtension",
            dependencies: ["UIComponentsCore"]
        ),
        .target(
            name: "SwiftUIExtension",
            dependencies: ["UIComponentsCore"]
        ),
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
        .testTarget(
            name: "UIComponentsCoreTests",
            dependencies: ["UIComponentsCore"]
        ),
        .testTarget(
            name: "UIKitExtensionTests",
            dependencies: ["UIKitExtension"]
        ),
        .testTarget(
            name: "SwiftUIExtensionTests",
            dependencies: ["SwiftUIExtension"]
        ),
    ]
)
