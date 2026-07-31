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
            name: "SwiftExtension",
            targets: ["SwiftExtension"]
        ),
    ],
    targets: [
        .target(name: "SwiftExtension"),
        .testTarget(
            name: "SwiftExtensionTests",
            dependencies: ["SwiftExtension"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
